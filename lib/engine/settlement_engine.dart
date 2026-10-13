import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';

import '../models/round_models.dart';
import '../models/tariff_config.dart';

/// Excepción lanzada cuando los datos de entrada de una partida violan las reglas configuradas.
class RoundValidationException implements Exception {
  final List<String> errors;

  const RoundValidationException(this.errors);

  @override
  String toString() => errors.join('\n');
}

/// Motor determinista de cálculo contable, compensación bilateral y liquidación global para «Me Voy».
///
/// Cumple estrictamente:
/// 1. Cálculos 100% deterministas en centavos enteros (sin punto flotante ni IA).
/// 2. Cálculo de premios brutos (cartas a cada rival + mesa ganada a cada perdedor).
/// 3. Cálculo de obligaciones entre todas las parejas ordenadas.
/// 4. Compensación bilateral de deudas opuestas entre cada par de jugadores.
/// 5. Obtención del saldo neto de cada participante con verificación de suma cero ($\sum = 0$).
/// 6. Plan de liquidación global optimizado que minimiza el número de transferencias sin alterar el resultado económico.
class SettlementEngine {
  const SettlementEngine._();

  /// Valida que los premios declarados cumplan las reglas de la partida y de la mesa.
  static List<String> validateRoundInputs({
    required List<PlayerRoundInput> inputs,
    required TariffConfig tariffs,
  }) {
    final errors = <String>[];

    // 1. Validar tarifas
    errors.addAll(tariffs.validate());

    // 2. Cantidad de participantes (entre 2 y 4)
    if (inputs.length < 2 || inputs.length > 4) {
      errors.add(
        'La partida debe tener entre 2 y 4 participantes activos (recibidos: ${inputs.length}).',
      );
      return errors;
    }

    // 3. Identificadores únicos
    final seenIds = <String>{};
    for (final input in inputs) {
      if (input.playerId.trim().isEmpty) {
        errors.add('Todos los participantes deben tener un identificador válido.');
      } else if (!seenIds.add(input.playerId)) {
        errors.add('Jugador duplicado en la partida: ${input.displayName}.');
      }
    }

    // 4. Exactamente un ganador de la mesa
    final winners = inputs.where((p) => p.isWinner).toList();
    if (winners.isEmpty) {
      errors.add('Debe seleccionarse exactamente 1 ganador de la mesa.');
    } else if (winners.length > 1) {
      errors.add(
        'Solo puede haber 1 ganador de la mesa por partida (seleccionados: ${winners.length}).',
      );
    }

    // 5. Validar conteos por jugador y totales del mazo
    int totalAces = 0;
    int totalKings = 0;

    for (final p in inputs) {
      if (p.acesCount < 0) {
        errors.add('${p.displayName}: la cantidad de Ases no puede ser negativa.');
      }
      if (p.kingsCount < 0) {
        errors.add('${p.displayName}: la cantidad de K no puede ser negativa.');
      }
      if (p.rusosCount < 0) {
        errors.add('${p.displayName}: la cantidad de Rusos no puede ser negativa.');
      }
      if (p.patasCount < 0) {
        errors.add('${p.displayName}: la cantidad de Patas no puede ser negativa.');
      }

      if (p.rusosCount > tariffs.maxRusosPerPlayer) {
        errors.add(
          '${p.displayName}: excede el máximo de Rusos permitidos (${tariffs.maxRusosPerPlayer}).',
        );
      }
      if (p.patasCount > tariffs.maxPatasPerPlayer) {
        errors.add(
          '${p.displayName}: excede el máximo de Patas permitidas (${tariffs.maxPatasPerPlayer}).',
        );
      }

      totalAces += p.acesCount;
      totalKings += p.kingsCount;
    }

    if (totalAces > tariffs.maxAcesPerRound) {
      errors.add(
        'El total de Ases en la mesa ($totalAces) supera el máximo permitido por partida (${tariffs.maxAcesPerRound}).',
      );
    }
    if (totalKings > tariffs.maxKingsPerRound) {
      errors.add(
        'El total de K en la mesa ($totalKings) supera el máximo permitido por partida (${tariffs.maxKingsPerRound}).',
      );
    }

    return errors;
  }

  /// Ejecuta el cálculo completo de cierre de ronda y devuelve el registro auditable.
  static RoundCalculationResult calculateRound({
    required String roundId,
    required int roundNumber,
    required TariffConfig tariffs,
    required List<PlayerRoundInput> inputs,
    DateTime? timestamp,
  }) {
    final validationErrors = validateRoundInputs(
      inputs: inputs,
      tariffs: tariffs,
    );
    if (validationErrors.isNotEmpty) {
      throw RoundValidationException(validationErrors);
    }

    final now = (timestamp ?? DateTime.now()).toUtc();
    final frozenTariffs = tariffs.freezeCopy();
    final n = inputs.length;
    final rivalsCount = n - 1;

    // 1. Calcular premios brutos por cada jugador
    final grossBreakdowns = <PlayerGrossPrizeBreakdown>[];
    final grossByPlayerId = <String, PlayerGrossPrizeBreakdown>{};

    for (final input in inputs) {
      final cardPrizePerRival = (input.acesCount * frozenTariffs.aceCents) +
          (input.kingsCount * frozenTariffs.kingCents) +
          (input.rusosCount * frozenTariffs.rusoCents) +
          (input.patasCount * frozenTariffs.patasCents);

      final tablePrizePerRival =
          input.isWinner ? frozenTariffs.tableWinCents : 0;

      final breakdown = PlayerGrossPrizeBreakdown(
        playerId: input.playerId,
        displayName: input.displayName,
        rivalsCount: rivalsCount,
        cardPrizePerRivalCents: cardPrizePerRival,
        tablePrizePerRivalCents: tablePrizePerRival,
      );
      grossBreakdowns.add(breakdown);
      grossByPlayerId[input.playerId] = breakdown;
    }

    // 2. Calcular todas las obligaciones brutas dirigidas entre parejas (deudor -> acreedor)
    final rawPairwiseObligations = <PairwiseObligation>[];
    for (int i = 0; i < n; i++) {
      final debtor = inputs[i];
      for (int j = 0; j < n; j++) {
        if (i == j) continue;
        final creditor = inputs[j];
        final creditorGross = grossByPlayerId[creditor.playerId]!;

        rawPairwiseObligations.add(
          PairwiseObligation(
            debtorId: debtor.playerId,
            debtorName: debtor.displayName,
            creditorId: creditor.playerId,
            creditorName: creditor.displayName,
            cardAmountCents: creditorGross.cardPrizePerRivalCents,
            tableWinAmountCents: creditorGross.tablePrizePerRivalCents,
          ),
        );
      }
    }

    // 3. Compensar deudas opuestas entre cada par de jugadores (i < j)
    final bilateralCompensations = <BilateralCompensation>[];
    final netFromBilateralByPlayer = <String, int>{
      for (final p in inputs) p.playerId: 0,
    };

    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        final playerA = inputs[i];
        final playerB = inputs[j];

        // Lo que A debe a B es lo que B cobra por rival
        final aOwesB = grossByPlayerId[playerB.playerId]!.totalClaimPerRivalCents;
        // Lo que B debe a A es lo que A cobra por rival
        final bOwesA = grossByPlayerId[playerA.playerId]!.totalClaimPerRivalCents;

        final compensated = math.min(aOwesB, bOwesA);
        final diff = aOwesB - bOwesA; // Si > 0, A debe a B; si < 0, B debe a A

        String? netDebtorId;
        String? netDebtorName;
        String? netCreditorId;
        String? netCreditorName;
        final netAmount = diff.abs();

        if (diff > 0) {
          netDebtorId = playerA.playerId;
          netDebtorName = playerA.displayName;
          netCreditorId = playerB.playerId;
          netCreditorName = playerB.displayName;

          netFromBilateralByPlayer[playerA.playerId] =
              netFromBilateralByPlayer[playerA.playerId]! - netAmount;
          netFromBilateralByPlayer[playerB.playerId] =
              netFromBilateralByPlayer[playerB.playerId]! + netAmount;
        } else if (diff < 0) {
          netDebtorId = playerB.playerId;
          netDebtorName = playerB.displayName;
          netCreditorId = playerA.playerId;
          netCreditorName = playerA.displayName;

          netFromBilateralByPlayer[playerB.playerId] =
              netFromBilateralByPlayer[playerB.playerId]! - netAmount;
          netFromBilateralByPlayer[playerA.playerId] =
              netFromBilateralByPlayer[playerA.playerId]! + netAmount;
        }

        bilateralCompensations.add(
          BilateralCompensation(
            playerAId: playerA.playerId,
            playerAName: playerA.displayName,
            playerBId: playerB.playerId,
            playerBName: playerB.displayName,
            obligationAToBCents: aOwesB,
            obligationBToACents: bOwesA,
            compensatedCents: compensated,
            netDebtorId: netDebtorId,
            netDebtorName: netDebtorName,
            netCreditorId: netCreditorId,
            netCreditorName: netCreditorName,
            netAmountCents: netAmount,
          ),
        );
      }
    }

    // 4. Obtener saldo neto de cada participante y verificar invariantes matemáticos
    final netBalancesByPlayerCents = <String, int>{};
    int sumOfNets = 0;

    for (final p in inputs) {
      final grossEarned = grossByPlayerId[p.playerId]!.grossTotalCents;
      int totalOwedToRivals = 0;
      for (final rival in inputs) {
        if (rival.playerId == p.playerId) continue;
        totalOwedToRivals +=
            grossByPlayerId[rival.playerId]!.totalClaimPerRivalCents;
      }
      final netBalance = grossEarned - totalOwedToRivals;

      // Verificación cruzada: el saldo neto por fórmula bruta debe coincidir exactamente
      // con la suma de compensaciones bilaterales.
      final bilateralNet = netFromBilateralByPlayer[p.playerId]!;
      if (netBalance != bilateralNet) {
        throw StateError(
          'Inconsistencia contable interna para ${p.playerId}: bruto=$netBalance vs bilateral=$bilateralNet',
        );
      }

      netBalancesByPlayerCents[p.playerId] = netBalance;
      sumOfNets += netBalance;
    }

    // Invariante fundamental: la suma de todos los saldos netos debe ser estrictamente 0.
    if (sumOfNets != 0) {
      throw StateError(
        'Violación de suma cero en el motor de cálculo: suma=$sumOfNets',
      );
    }

    // 5. Generar plan de liquidación global optimizado
    final namesById = {
      for (final p in inputs) p.playerId: p.displayName,
    };
    final optimizedPlan = _buildOptimizedSettlementPlan(
      roundId: roundId,
      netBalancesByPlayerCents: netBalancesByPlayerCents,
      namesById: namesById,
    );

    // Verificar que el plan optimizado preserva al 100% el resultado económico de cada participante
    final reconstructedNet = <String, int>{
      for (final p in inputs) p.playerId: 0,
    };
    for (final item in optimizedPlan) {
      reconstructedNet[item.fromPlayerId] =
          (reconstructedNet[item.fromPlayerId] ?? 0) - item.amountCents;
      reconstructedNet[item.toPlayerId] =
          (reconstructedNet[item.toPlayerId] ?? 0) + item.amountCents;
    }
    for (final p in inputs) {
      if (reconstructedNet[p.playerId] != netBalancesByPlayerCents[p.playerId]) {
        throw StateError(
          'El plan de liquidación optimizado no conserva el saldo neto de ${p.displayName}.',
        );
      }
    }

    // 6. Generar firma SHA-256 determinista para auditoría
    final canonicalPayload = jsonEncode({
      'roundId': roundId,
      'roundNumber': roundNumber,
      'tariffs': {
        'tableWinCents': frozenTariffs.tableWinCents,
        'aceCents': frozenTariffs.aceCents,
        'kingCents': frozenTariffs.kingCents,
        'rusoCents': frozenTariffs.rusoCents,
        'patasCents': frozenTariffs.patasCents,
      },
      'inputs': inputs.map((e) => e.toMap()).toList(),
      'netBalances': netBalancesByPlayerCents,
      'settlementPlan': optimizedPlan
          .map((e) => {
                'from': e.fromPlayerId,
                'to': e.toPlayerId,
                'amountCents': e.amountCents,
              })
          .toList(),
    });
    final checksum =
        sha256.convert(utf8.encode(canonicalPayload)).toString().substring(0, 16);
    final calculationId = 'calc_${roundId}_$checksum';

    return RoundCalculationResult(
      calculationId: calculationId,
      roundId: roundId,
      roundNumber: roundNumber,
      tariffSnapshot: frozenTariffs,
      playerInputs: List.unmodifiable(inputs),
      grossBreakdowns: List.unmodifiable(grossBreakdowns),
      rawPairwiseObligations: List.unmodifiable(rawPairwiseObligations),
      bilateralCompensations: List.unmodifiable(bilateralCompensations),
      netBalancesByPlayerCents: Map.unmodifiable(netBalancesByPlayerCents),
      optimizedSettlementPlan: List.unmodifiable(optimizedPlan),
      auditChecksum: checksum,
      calculatedAt: now,
    );
  }

  /// Algoritmo determinista para reducir el número de transferencias al mínimo posible
  /// manteniendo intacto el saldo neto de cada jugador.
  static List<SettlementTransferItem> _buildOptimizedSettlementPlan({
    required String roundId,
    required Map<String, int> netBalancesByPlayerCents,
    required Map<String, String> namesById,
  }) {
    final debtors = <_BalanceNode>[];
    final creditors = <_BalanceNode>[];

    final sortedKeys = netBalancesByPlayerCents.keys.toList()..sort();
    for (final playerId in sortedKeys) {
      final net = netBalancesByPlayerCents[playerId]!;
      if (net < 0) {
        debtors.add(_BalanceNode(playerId, -net));
      } else if (net > 0) {
        creditors.add(_BalanceNode(playerId, net));
      }
    }

    final plan = <SettlementTransferItem>[];
    int stepIndex = 1;

    // Paso 1: Emparejar primero deudores y acreedores con importes exactamente iguales
    // (minimiza aristas cuando existen pares simétricos disjuntos).
    for (final d in debtors) {
      if (d.remainingCents == 0) continue;
      for (final c in creditors) {
        if (c.remainingCents == 0) continue;
        if (d.remainingCents == c.remainingCents) {
          final amount = d.remainingCents;
          plan.add(
            SettlementTransferItem(
              itemId: 'tr_${roundId}_$stepIndex',
              index: stepIndex,
              fromPlayerId: d.playerId,
              fromPlayerName: namesById[d.playerId] ?? d.playerId,
              toPlayerId: c.playerId,
              toPlayerName: namesById[c.playerId] ?? c.playerId,
              amountCents: amount,
            ),
          );
          d.remainingCents = 0;
          c.remainingCents = 0;
          stepIndex++;
          break;
        }
      }
    }

    // Paso 2: Emparejamiento voraz determinista ordenando por mayor saldo pendiente
    while (true) {
      debtors.removeWhere((d) => d.remainingCents <= 0);
      creditors.removeWhere((c) => c.remainingCents <= 0);

      if (debtors.isEmpty || creditors.isEmpty) {
        break;
      }

      debtors.sort((a, b) {
        final cmp = b.remainingCents.compareTo(a.remainingCents);
        return cmp != 0 ? cmp : a.playerId.compareTo(b.playerId);
      });
      creditors.sort((a, b) {
        final cmp = b.remainingCents.compareTo(a.remainingCents);
        return cmp != 0 ? cmp : a.playerId.compareTo(b.playerId);
      });

      final topDebtor = debtors.first;
      final topCreditor = creditors.first;
      final transferAmount =
          math.min(topDebtor.remainingCents, topCreditor.remainingCents);

      plan.add(
        SettlementTransferItem(
          itemId: 'tr_${roundId}_$stepIndex',
          index: stepIndex,
          fromPlayerId: topDebtor.playerId,
          fromPlayerName: namesById[topDebtor.playerId] ?? topDebtor.playerId,
          toPlayerId: topCreditor.playerId,
          toPlayerName: namesById[topCreditor.playerId] ?? topCreditor.playerId,
          amountCents: transferAmount,
        ),
      );

      topDebtor.remainingCents -= transferAmount;
      topCreditor.remainingCents -= transferAmount;
      stepIndex++;
    }

    return plan;
  }
}

class _BalanceNode {
  final String playerId;
  int remainingCents;

  _BalanceNode(this.playerId, this.remainingCents);
}
