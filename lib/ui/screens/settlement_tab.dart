import 'package:flutter/material.dart';
import '../../models/round_models.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/money_badge.dart';

/// Pantalla 6: Liquidación determinista, compensación de deudas y cierre atómico de partida.
class SettlementTab extends StatelessWidget {
  final AppController controller;
  final VoidCallback onGoToPrizeEntry;
  final VoidCallback onGoToBankAdmin;

  const SettlementTab({
    super.key,
    required this.controller,
    required this.onGoToPrizeEntry,
    required this.onGoToBankAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final table = controller.activeTable!;
    final currentRound = table.currentRound;
    final calc = currentRound?.calculationResult;

    // Si la ronda actual aún está capturando premios, mostrar llamada a calcular
    // y debajo la última liquidación completada si existe.
    if (currentRound == null || calc == null) {
      final lastClosed = table.completedRounds.isNotEmpty
          ? table.completedRounds.first
          : null;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.calculate_outlined,
                    size: 46,
                    color: MeVoyTheme.goldAccent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentRound != null
                        ? 'La Partida #${currentRound.roundNumber} está en captura de premios'
                        : 'No hay liquidación pendiente en este momento',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Registra el ganador y las cartas premiadas en la pestaña «Premios» para ejecutar el motor determinista de compensación.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: onGoToPrizeEntry,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Ir a Registro de Premios'),
                  ),
                ],
              ),
            ),
          ),
          if (lastClosed != null && lastClosed.calculationResult != null) ...[
            const SizedBox(height: 18),
            const Text(
              'ÚLTIMA PARTIDA LIQUIDADA Y CERRADA',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: MeVoyTheme.goldSoft,
              ),
            ),
            const SizedBox(height: 8),
            _RoundCalculationDetailView(
              round: lastClosed,
              calc: lastClosed.calculationResult!,
              controller: controller,
              isReadOnlyHistorical: true,
              onGoToBankAdmin: onGoToBankAdmin,
            ),
          ],
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _RoundCalculationDetailView(
          round: currentRound,
          calc: calc,
          controller: controller,
          isReadOnlyHistorical: false,
          onGoToBankAdmin: onGoToBankAdmin,
        ),
      ],
    );
  }
}

class _RoundCalculationDetailView extends StatelessWidget {
  final GameRound round;
  final RoundCalculationResult calc;
  final AppController controller;
  final bool isReadOnlyHistorical;
  final VoidCallback onGoToBankAdmin;

  const _RoundCalculationDetailView({
    required this.round,
    required this.calc,
    required this.controller,
    required this.isReadOnlyHistorical,
    required this.onGoToBankAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final table = controller.activeTable!;

    // Verificar si algún deudor tiene saldo insuficiente para cubrir su pérdida neta
    final insolventAlerts = <String>[];
    if (!isReadOnlyHistorical &&
        round.status == RoundStatus.awaitingConfirmation) {
      for (final entry in calc.netBalancesByPlayerCents.entries) {
        if (entry.value < 0) {
          final needed = -entry.value;
          final player = table.participants[entry.key];
          if (player != null && player.availableBalanceCents < needed) {
            final deficit = needed - player.availableBalanceCents;
            insolventAlerts.add(
              '${player.displayName}: debe ${MoneyFormatter.formatCents(needed)} pero su saldo disponible es ${MoneyFormatter.formatCents(player.availableBalanceCents)} (faltan ${MoneyFormatter.formatCents(deficit)}).',
            );
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Cabecera de Auditoría y Suma Cero
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: MeVoyTheme.creditPositive,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Partida #${round.roundNumber} — Liquidación Determinista',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: calc.isZeroSumVerified
                            ? MeVoyTheme.creditPositive.withValues(alpha: 0.18)
                            : MeVoyTheme.debtNegative.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        calc.isZeroSumVerified
                            ? 'SUMA CERO VERIFICADA (\$0.00)'
                            : 'ERROR SUMA',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: MeVoyTheme.creditPositive,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'ID Cálculo: ${calc.calculationId} • Firma SHA-256: ${calc.auditChecksum}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _AuditStatPill(
                      label: 'Obligaciones brutas',
                      value: MoneyFormatter.formatCents(
                        calc.totalRawObligationsVolumeCents,
                      ),
                    ),
                    _AuditStatPill(
                      label: 'Tras compensar pares',
                      value: MoneyFormatter.formatCents(
                        calc.totalBilateralNetVolumeCents,
                      ),
                    ),
                    _AuditStatPill(
                      label: 'Transferencias óptimas',
                      value:
                          '${calc.optimizedSettlementPlan.length} (${MoneyFormatter.formatCents(calc.totalOptimizedTransferVolumeCents)})',
                    ),
                    _AuditStatPill(
                      label: 'Pagos evitados',
                      value: '${calc.paymentsReducedCount} movimientos menos',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Alerta visual de saldo insuficiente (si aplica)
        if (insolventAlerts.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MeVoyTheme.debtNegative.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MeVoyTheme.debtNegative),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: MeVoyTheme.debtNegative,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Alerta: Saldo disponible insuficiente para liquidación automática completa',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...insolventAlerts.map(
                  (msg) => Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('• $msg', style: const TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onGoToBankAdmin,
                      icon: const Icon(Icons.account_balance_rounded, size: 16),
                      label: const Text('Recargar en Panel del Banco'),
                    ),
                    if (controller.isCurrentUserTableAdmin)
                      ElevatedButton.icon(
                        onPressed: controller.isBusy
                            ? null
                            : () => controller.executeRoundSettlement(
                                  allowPendingIfInsufficient: true,
                                ),
                        icon: const Icon(Icons.pending_actions_rounded, size: 16),
                        label: const Text(
                          'Liquidar Registrando Deuda Pendiente',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 3. PLAN DE LIQUIDACIÓN GLOBAL OPTIMIZADO
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: MeVoyTheme.goldAccent,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Plan de Liquidación Global Optimizado',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Reduce los movimientos de pago al mínimo posible manteniendo exactamente el mismo resultado económico.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                if (calc.optimizedSettlementPlan.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.done_all_rounded,
                          color: MeVoyTheme.creditPositive,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Todas las obligaciones se compensaron exactamente a \$0.00. No se requiere ningún movimiento de pago.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...calc.optimizedSettlementPlan.map(
                    (item) => _SettlementTransferTile(
                      item: item,
                      round: round,
                      controller: controller,
                      isReadOnlyHistorical: isReadOnlyHistorical,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 4. Botones de Aprobación y Ejecución Atómica (cuando la partida está esperando liquidación)
        if (!isReadOnlyHistorical &&
            round.status == RoundStatus.awaitingConfirmation) ...[
          Card(
            color: const Color(0xFF144233),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Confirmaciones de jugadores: ${round.confirmedByPlayerIds.length}/${table.participants.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (!round.confirmedByPlayerIds
                          .contains(controller.effectivePlayerId))
                        TextButton.icon(
                          onPressed: controller.isBusy
                              ? null
                              : () => controller.confirmRoundResultByPlayer(),
                          icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
                          label: const Text('Confirmar mi acuerdo'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (controller.isCurrentUserTableAdmin) ...[
                        OutlinedButton.icon(
                          onPressed: controller.isBusy
                              ? null
                              : () => controller.reopenCurrentRoundForEditing(),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Corregir Premios'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (!controller.isCurrentUserTableAdmin ||
                                  controller.isBusy)
                              ? null
                              : () => controller.executeRoundSettlement(
                                    allowPendingIfInsufficient: false,
                                  ),
                          icon: const Icon(Icons.lock_clock_rounded),
                          label: const Text(
                            'Ejecutar Liquidación Automática y Cerrar Partida',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 5. SALDOS NETOS INDIVIDUALES DE LA RONDA
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldos Netos de cada Participante en la Ronda',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ...calc.grossBreakdowns.map((g) {
                  final net = calc.netBalancesByPlayerCents[g.playerId] ?? 0;
                  final paidOut = g.grossTotalCents - net;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                ),
                              ),
                              Text(
                                'Bruto ganado: ${MoneyFormatter.formatCents(g.grossTotalCents)} (Cartas: ${MoneyFormatter.formatCents(g.grossCardPrizeTotalCents)} + Mesa: ${MoneyFormatter.formatCents(g.grossTablePrizeTotalCents)}) • Obligaciones: -${MoneyFormatter.formatCents(paidOut)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        MoneyBadge(
                          cents: net,
                          showPlusSign: true,
                          fontSize: 15,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 6. AUDITORÍA: COMPENSACIONES BILATERALES ENTRE PAREJAS
        Card(
          child: ExpansionTile(
            title: Text(
              'Auditoría de Compensación entre Parejas (${calc.bilateralCompensations.length} pares)',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
            ),
            subtitle: const Text(
              'Muestra las deudas opuestas originales y el importe compensado entre cada par',
              style: TextStyle(fontSize: 12),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: calc.bilateralCompensations.map((c) {
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${c.playerAName} ↔ ${c.playerBName}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Compensado: ${MoneyFormatter.formatCents(c.compensatedCents)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: MeVoyTheme.goldSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${c.playerAName} debía ${MoneyFormatter.formatCents(c.obligationAToBCents)} a ${c.playerBName} | '
                      '${c.playerBName} debía ${MoneyFormatter.formatCents(c.obligationBToACents)} a ${c.playerAName}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.netAmountCents == 0
                          ? 'Resultado bilateral: Empate (\$0.00)'
                          : 'Saldo bilateral neto: ${c.netDebtorName} debe ${MoneyFormatter.formatCents(c.netAmountCents)} a ${c.netCreditorName}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettlementTransferTile extends StatelessWidget {
  final SettlementTransferItem item;
  final GameRound round;
  final AppController controller;
  final bool isReadOnlyHistorical;

  const _SettlementTransferTile({
    required this.item,
    required this.round,
    required this.controller,
    required this.isReadOnlyHistorical,
  });

  @override
  Widget build(BuildContext context) {
    final isSettled = item.isSettled;
    final canResolvePending = !isReadOnlyHistorical &&
        round.status == RoundStatus.partiallySettledPending &&
        !isSettled &&
        controller.isCurrentUserTableAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSettled
              ? MeVoyTheme.creditPositive.withValues(alpha: 0.5)
              : MeVoyTheme.goldAccent.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isSettled
                    ? MeVoyTheme.creditPositive
                    : MeVoyTheme.goldAccent,
                foregroundColor: const Color(0xFF1A1600),
                child: isSettled
                    ? const Icon(Icons.check, size: 16)
                    : Text(
                        '${item.index}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${item.fromPlayerName}  paga a  ${item.toPlayerName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              MoneyBadge(
                cents: item.amountCents,
                fontSize: 15.5,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isSettled
                ? 'Estado: Liquidado (${item.status == SettlementTransferStatus.settledInternalCredits ? "Créditos internos" : "Pago externo verificado"}) • Ref: ${item.ledgerTransactionId ?? ""}'
                : 'Estado: Pendiente de ejecución',
            style: TextStyle(
              fontSize: 11.5,
              color: isSettled
                  ? MeVoyTheme.creditPositive
                  : Colors.white.withValues(alpha: 0.7),
            ),
          ),
          if (canResolvePending) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () => controller.settlePendingRoundTransfer(
                            roundId: round.roundId,
                            transferItemId: item.itemId,
                            useInternalCredits: true,
                            verificationNote:
                                'Liquidación con créditos internos tras recarga',
                          ),
                  icon: const Icon(Icons.account_balance_wallet, size: 16),
                  label: const Text('Cobrar de Créditos Internos'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () => controller.settlePendingRoundTransfer(
                            roundId: round.roundId,
                            transferItemId: item.itemId,
                            useInternalCredits: false,
                            verificationNote:
                                'Pago externo verificado por el administrador',
                          ),
                  icon: const Icon(Icons.verified_outlined, size: 16),
                  label: const Text('Verificar Pago Externo'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AuditStatPill extends StatelessWidget {
  final String label;
  final String value;

  const _AuditStatPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
