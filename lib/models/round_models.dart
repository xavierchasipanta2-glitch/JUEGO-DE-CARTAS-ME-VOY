import 'tariff_config.dart';

/// Estado del ciclo de vida de una partida/ronda dentro de la mesa.
enum RoundStatus {
  /// Los jugadores o el administrador están registrando los premios de cartas y el ganador.
  collectingPrizes,

  /// Los premios han sido calculados; el resumen y plan de liquidación están listos para revisión/aprobación.
  awaitingConfirmation,

  /// La liquidación se ejecutó con deudas o pagos externos pendientes de verificación.
  partiallySettledPending,

  /// La partida ha sido liquidada íntegramente y cerrada de forma atómica.
  closed,
}

/// Estado de cada transferencia dentro del plan de liquidación de una ronda.
enum SettlementTransferStatus {
  pending,
  settledInternalCredits,
  settledVerifiedExternal,
}

/// Premios declarados para un participante en una ronda.
class PlayerRoundInput {
  final String playerId;
  final String displayName;
  final bool isWinner;
  final int acesCount;
  final int kingsCount;
  final int rusosCount;
  final int patasCount;

  const PlayerRoundInput({
    required this.playerId,
    required this.displayName,
    this.isWinner = false,
    this.acesCount = 0,
    this.kingsCount = 0,
    this.rusosCount = 0,
    this.patasCount = 0,
  });

  PlayerRoundInput copyWith({
    String? playerId,
    String? displayName,
    bool? isWinner,
    int? acesCount,
    int? kingsCount,
    int? rusosCount,
    int? patasCount,
  }) {
    return PlayerRoundInput(
      playerId: playerId ?? this.playerId,
      displayName: displayName ?? this.displayName,
      isWinner: isWinner ?? this.isWinner,
      acesCount: acesCount ?? this.acesCount,
      kingsCount: kingsCount ?? this.kingsCount,
      rusosCount: rusosCount ?? this.rusosCount,
      patasCount: patasCount ?? this.patasCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'displayName': displayName,
      'isWinner': isWinner,
      'acesCount': acesCount,
      'kingsCount': kingsCount,
      'rusosCount': rusosCount,
      'patasCount': patasCount,
    };
  }

  factory PlayerRoundInput.fromMap(Map<String, dynamic> map) {
    return PlayerRoundInput(
      playerId: map['playerId']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? 'Jugador',
      isWinner: map['isWinner'] == true,
      acesCount: (map['acesCount'] as num?)?.toInt() ?? 0,
      kingsCount: (map['kingsCount'] as num?)?.toInt() ?? 0,
      rusosCount: (map['rusosCount'] as num?)?.toInt() ?? 0,
      patasCount: (map['patasCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Desglose de premios brutos de un jugador antes de compensaciones.
class PlayerGrossPrizeBreakdown {
  final String playerId;
  final String displayName;
  final int rivalsCount;

  /// Lo que cobra a cada rival por cartas (Ases, K, Ruso, Patas).
  final int cardPrizePerRivalCents;

  /// Lo que cobra a cada rival por haber ganado la mesa ($0.50 si ganó, $0.00 si no).
  final int tablePrizePerRivalCents;

  /// Total unitario que cobra a cada rival.
  int get totalClaimPerRivalCents =>
      cardPrizePerRivalCents + tablePrizePerRivalCents;

  /// Total bruto por cartas cobrado a todos los rivales.
  int get grossCardPrizeTotalCents => cardPrizePerRivalCents * rivalsCount;

  /// Total bruto por mesa ganada cobrado a todos los rivales.
  int get grossTablePrizeTotalCents => tablePrizePerRivalCents * rivalsCount;

  /// Premio bruto total del jugador en la ronda.
  int get grossTotalCents => totalClaimPerRivalCents * rivalsCount;

  const PlayerGrossPrizeBreakdown({
    required this.playerId,
    required this.displayName,
    required this.rivalsCount,
    required this.cardPrizePerRivalCents,
    required this.tablePrizePerRivalCents,
  });

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'displayName': displayName,
      'rivalsCount': rivalsCount,
      'cardPrizePerRivalCents': cardPrizePerRivalCents,
      'tablePrizePerRivalCents': tablePrizePerRivalCents,
      'totalClaimPerRivalCents': totalClaimPerRivalCents,
      'grossCardPrizeTotalCents': grossCardPrizeTotalCents,
      'grossTablePrizeTotalCents': grossTablePrizeTotalCents,
      'grossTotalCents': grossTotalCents,
    };
  }

  factory PlayerGrossPrizeBreakdown.fromMap(Map<String, dynamic> map) {
    return PlayerGrossPrizeBreakdown(
      playerId: map['playerId']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      rivalsCount: (map['rivalsCount'] as num?)?.toInt() ?? 3,
      cardPrizePerRivalCents:
          (map['cardPrizePerRivalCents'] as num?)?.toInt() ?? 0,
      tablePrizePerRivalCents:
          (map['tablePrizePerRivalCents'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Obligación bruta unilateral entre un par ordenado de jugadores (deudor -> acreedor).
class PairwiseObligation {
  final String debtorId;
  final String debtorName;
  final String creditorId;
  final String creditorName;
  final int cardAmountCents;
  final int tableWinAmountCents;

  int get totalAmountCents => cardAmountCents + tableWinAmountCents;

  const PairwiseObligation({
    required this.debtorId,
    required this.debtorName,
    required this.creditorId,
    required this.creditorName,
    required this.cardAmountCents,
    required this.tableWinAmountCents,
  });

  Map<String, dynamic> toMap() {
    return {
      'debtorId': debtorId,
      'debtorName': debtorName,
      'creditorId': creditorId,
      'creditorName': creditorName,
      'cardAmountCents': cardAmountCents,
      'tableWinAmountCents': tableWinAmountCents,
      'totalAmountCents': totalAmountCents,
    };
  }

  factory PairwiseObligation.fromMap(Map<String, dynamic> map) {
    return PairwiseObligation(
      debtorId: map['debtorId']?.toString() ?? '',
      debtorName: map['debtorName']?.toString() ?? '',
      creditorId: map['creditorId']?.toString() ?? '',
      creditorName: map['creditorName']?.toString() ?? '',
      cardAmountCents: (map['cardAmountCents'] as num?)?.toInt() ?? 0,
      tableWinAmountCents: (map['tableWinAmountCents'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Resultado de compensar las deudas opuestas entre dos jugadores (A y B).
class BilateralCompensation {
  final String playerAId;
  final String playerAName;
  final String playerBId;
  final String playerBName;

  /// Lo que A debía originalmente a B.
  final int obligationAToBCents;

  /// Lo que B debía originalmente a A.
  final int obligationBToACents;

  /// Monto que se anuló/compensó mutuamente: min(A->B, B->A).
  final int compensatedCents;

  /// Jugador que queda debiendo tras la compensación bilateral (null si quedaron en 0).
  final String? netDebtorId;
  final String? netDebtorName;

  /// Jugador que queda cobrando tras la compensación bilateral (null si quedaron en 0).
  final String? netCreditorId;
  final String? netCreditorName;

  /// Saldo neto bilateral restante entre ambos jugadores (>= 0).
  final int netAmountCents;

  const BilateralCompensation({
    required this.playerAId,
    required this.playerAName,
    required this.playerBId,
    required this.playerBName,
    required this.obligationAToBCents,
    required this.obligationBToACents,
    required this.compensatedCents,
    this.netDebtorId,
    this.netDebtorName,
    this.netCreditorId,
    this.netCreditorName,
    required this.netAmountCents,
  });

  Map<String, dynamic> toMap() {
    return {
      'playerAId': playerAId,
      'playerAName': playerAName,
      'playerBId': playerBId,
      'playerBName': playerBName,
      'obligationAToBCents': obligationAToBCents,
      'obligationBToACents': obligationBToACents,
      'compensatedCents': compensatedCents,
      'netDebtorId': netDebtorId,
      'netDebtorName': netDebtorName,
      'netCreditorId': netCreditorId,
      'netCreditorName': netCreditorName,
      'netAmountCents': netAmountCents,
    };
  }

  factory BilateralCompensation.fromMap(Map<String, dynamic> map) {
    return BilateralCompensation(
      playerAId: map['playerAId']?.toString() ?? '',
      playerAName: map['playerAName']?.toString() ?? '',
      playerBId: map['playerBId']?.toString() ?? '',
      playerBName: map['playerBName']?.toString() ?? '',
      obligationAToBCents: (map['obligationAToBCents'] as num?)?.toInt() ?? 0,
      obligationBToACents: (map['obligationBToACents'] as num?)?.toInt() ?? 0,
      compensatedCents: (map['compensatedCents'] as num?)?.toInt() ?? 0,
      netDebtorId: map['netDebtorId']?.toString(),
      netDebtorName: map['netDebtorName']?.toString(),
      netCreditorId: map['netCreditorId']?.toString(),
      netCreditorName: map['netCreditorName']?.toString(),
      netAmountCents: (map['netAmountCents'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Movimiento individual dentro del plan de liquidación global optimizado.
class SettlementTransferItem {
  final String itemId;
  final int index;
  final String fromPlayerId;
  final String fromPlayerName;
  final String toPlayerId;
  final String toPlayerName;
  final int amountCents;
  final SettlementTransferStatus status;
  final String? ledgerTransactionId;
  final DateTime? settledAt;

  const SettlementTransferItem({
    required this.itemId,
    required this.index,
    required this.fromPlayerId,
    required this.fromPlayerName,
    required this.toPlayerId,
    required this.toPlayerName,
    required this.amountCents,
    this.status = SettlementTransferStatus.pending,
    this.ledgerTransactionId,
    this.settledAt,
  });

  bool get isSettled =>
      status == SettlementTransferStatus.settledInternalCredits ||
      status == SettlementTransferStatus.settledVerifiedExternal;

  SettlementTransferItem copyWith({
    SettlementTransferStatus? status,
    String? ledgerTransactionId,
    DateTime? settledAt,
  }) {
    return SettlementTransferItem(
      itemId: itemId,
      index: index,
      fromPlayerId: fromPlayerId,
      fromPlayerName: fromPlayerName,
      toPlayerId: toPlayerId,
      toPlayerName: toPlayerName,
      amountCents: amountCents,
      status: status ?? this.status,
      ledgerTransactionId: ledgerTransactionId ?? this.ledgerTransactionId,
      settledAt: settledAt ?? this.settledAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'index': index,
      'fromPlayerId': fromPlayerId,
      'fromPlayerName': fromPlayerName,
      'toPlayerId': toPlayerId,
      'toPlayerName': toPlayerName,
      'amountCents': amountCents,
      'status': status.name,
      'ledgerTransactionId': ledgerTransactionId,
      'settledAt': settledAt?.toUtc().toIso8601String(),
    };
  }

  factory SettlementTransferItem.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status']?.toString() ?? 'pending';
    final status = SettlementTransferStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => SettlementTransferStatus.pending,
    );
    return SettlementTransferItem(
      itemId: map['itemId']?.toString() ?? '',
      index: (map['index'] as num?)?.toInt() ?? 0,
      fromPlayerId: map['fromPlayerId']?.toString() ?? '',
      fromPlayerName: map['fromPlayerName']?.toString() ?? '',
      toPlayerId: map['toPlayerId']?.toString() ?? '',
      toPlayerName: map['toPlayerName']?.toString() ?? '',
      amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
      status: status,
      ledgerTransactionId: map['ledgerTransactionId']?.toString(),
      settledAt: map['settledAt'] != null
          ? DateTime.tryParse(map['settledAt'].toString())?.toUtc()
          : null,
    );
  }
}

/// Resultado completo y auditable del motor determinista de cálculo para una partida.
/// Conserva tanto el cálculo original (premios brutos y obligaciones por pareja)
/// como las compensaciones bilaterales y el plan de liquidación global optimizado.
class RoundCalculationResult {
  final String calculationId;
  final String roundId;
  final int roundNumber;
  final TariffConfig tariffSnapshot;
  final List<PlayerRoundInput> playerInputs;
  final List<PlayerGrossPrizeBreakdown> grossBreakdowns;
  final List<PairwiseObligation> rawPairwiseObligations;
  final List<BilateralCompensation> bilateralCompensations;

  /// Saldo neto económico de cada participante en esta ronda (suma estricta = 0).
  final Map<String, int> netBalancesByPlayerCents;

  /// Plan de liquidación global optimizado que minimiza el número de transferencias.
  final List<SettlementTransferItem> optimizedSettlementPlan;

  /// Firma SHA-256 determinista para auditoría de integridad del cálculo.
  final String auditChecksum;

  final DateTime calculatedAt;

  const RoundCalculationResult({
    required this.calculationId,
    required this.roundId,
    required this.roundNumber,
    required this.tariffSnapshot,
    required this.playerInputs,
    required this.grossBreakdowns,
    required this.rawPairwiseObligations,
    required this.bilateralCompensations,
    required this.netBalancesByPlayerCents,
    required this.optimizedSettlementPlan,
    required this.auditChecksum,
    required this.calculatedAt,
  });

  /// Suma de todos los saldos netos de los participantes (invariante contable: debe ser 0).
  int get sumOfNetBalancesCents =>
      netBalancesByPlayerCents.values.fold(0, (sum, v) => sum + v);

  /// Verifica que la suma de saldos netos sea estrictamente cero.
  bool get isZeroSumVerified => sumOfNetBalancesCents == 0;

  /// Volumen total bruto de obligaciones antes de compensar.
  int get totalRawObligationsVolumeCents => rawPairwiseObligations.fold(
        0,
        (sum, item) => sum + item.totalAmountCents,
      );

  /// Volumen total después de compensación bilateral par a par.
  int get totalBilateralNetVolumeCents => bilateralCompensations.fold(
        0,
        (sum, item) => sum + item.netAmountCents,
      );

  /// Volumen total a transferir en el plan global optimizado.
  int get totalOptimizedTransferVolumeCents => optimizedSettlementPlan.fold(
        0,
        (sum, item) => sum + item.amountCents,
      );

  /// Cantidad de pagos evitados gracias a la compensación y optimización.
  int get paymentsReducedCount {
    final nonZeroRaw =
        rawPairwiseObligations.where((o) => o.totalAmountCents > 0).length;
    return nonZeroRaw - optimizedSettlementPlan.length;
  }

  RoundCalculationResult copyWith({
    List<SettlementTransferItem>? optimizedSettlementPlan,
  }) {
    return RoundCalculationResult(
      calculationId: calculationId,
      roundId: roundId,
      roundNumber: roundNumber,
      tariffSnapshot: tariffSnapshot,
      playerInputs: playerInputs,
      grossBreakdowns: grossBreakdowns,
      rawPairwiseObligations: rawPairwiseObligations,
      bilateralCompensations: bilateralCompensations,
      netBalancesByPlayerCents: netBalancesByPlayerCents,
      optimizedSettlementPlan:
          optimizedSettlementPlan ?? this.optimizedSettlementPlan,
      auditChecksum: auditChecksum,
      calculatedAt: calculatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'calculationId': calculationId,
      'roundId': roundId,
      'roundNumber': roundNumber,
      'tariffSnapshot': tariffSnapshot.toMap(),
      'playerInputs': playerInputs.map((e) => e.toMap()).toList(),
      'grossBreakdowns': grossBreakdowns.map((e) => e.toMap()).toList(),
      'rawPairwiseObligations':
          rawPairwiseObligations.map((e) => e.toMap()).toList(),
      'bilateralCompensations':
          bilateralCompensations.map((e) => e.toMap()).toList(),
      'netBalancesByPlayerCents': netBalancesByPlayerCents,
      'sumOfNetBalancesCents': sumOfNetBalancesCents,
      'optimizedSettlementPlan':
          optimizedSettlementPlan.map((e) => e.toMap()).toList(),
      'auditChecksum': auditChecksum,
      'calculatedAt': calculatedAt.toUtc().toIso8601String(),
    };
  }

  factory RoundCalculationResult.fromMap(Map<String, dynamic> map) {
    final netMapRaw =
        map['netBalancesByPlayerCents'] as Map<String, dynamic>? ?? {};
    final netMap = <String, int>{};
    for (final entry in netMapRaw.entries) {
      netMap[entry.key] = (entry.value as num?)?.toInt() ?? 0;
    }

    return RoundCalculationResult(
      calculationId: map['calculationId']?.toString() ?? '',
      roundId: map['roundId']?.toString() ?? '',
      roundNumber: (map['roundNumber'] as num?)?.toInt() ?? 1,
      tariffSnapshot: TariffConfig.fromMap(
        Map<String, dynamic>.from(map['tariffSnapshot'] as Map? ?? {}),
      ),
      playerInputs: (map['playerInputs'] as List<dynamic>? ?? [])
          .map((e) => PlayerRoundInput.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      grossBreakdowns: (map['grossBreakdowns'] as List<dynamic>? ?? [])
          .map((e) =>
              PlayerGrossPrizeBreakdown.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      rawPairwiseObligations:
          (map['rawPairwiseObligations'] as List<dynamic>? ?? [])
              .map((e) =>
                  PairwiseObligation.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
      bilateralCompensations:
          (map['bilateralCompensations'] as List<dynamic>? ?? [])
              .map((e) =>
                  BilateralCompensation.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
      netBalancesByPlayerCents: netMap,
      optimizedSettlementPlan:
          (map['optimizedSettlementPlan'] as List<dynamic>? ?? [])
              .map((e) =>
                  SettlementTransferItem.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
      auditChecksum: map['auditChecksum']?.toString() ?? '',
      calculatedAt: map['calculatedAt'] != null
          ? DateTime.tryParse(map['calculatedAt'].toString())?.toUtc() ??
              DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }
}

/// Representa una partida (ronda) dentro de una mesa de juego.
class GameRound {
  final String roundId;
  final int roundNumber;
  final String tableId;
  final RoundStatus status;

  /// Copia inmutable de las tarifas vigentes cuando se creó/calculó la partida.
  final TariffConfig tariffSnapshot;

  /// Premios capturados por cada jugador en la partida.
  final Map<String, PlayerRoundInput> playerInputs;

  /// Resultado determinista calculado al finalizar la ronda (null mientras se capturan premios).
  final RoundCalculationResult? calculationResult;

  /// Identificador único de liquidación (`stl_<roundId>`) para impedir liquidaciones duplicadas.
  final String? settlementId;

  /// Lista de IDs de jugadores que han confirmado estar de acuerdo con el resultado.
  final List<String> confirmedByPlayerIds;

  /// Indica si las ganancias y pérdidas acumuladas de esta ronda ya se contabilizaron
  /// en el historial de sesión (garantiza que se actualice una sola vez).
  final bool sessionPnlAccounted;

  final DateTime createdAt;
  final DateTime? closedAt;

  const GameRound({
    required this.roundId,
    required this.roundNumber,
    required this.tableId,
    required this.status,
    required this.tariffSnapshot,
    required this.playerInputs,
    this.calculationResult,
    this.settlementId,
    this.confirmedByPlayerIds = const [],
    this.sessionPnlAccounted = false,
    required this.createdAt,
    this.closedAt,
  });

  bool get isClosed => status == RoundStatus.closed;

  int get pendingTransfersCount {
    if (calculationResult == null) return 0;
    return calculationResult!.optimizedSettlementPlan
        .where((item) => !item.isSettled)
        .length;
  }

  GameRound copyWith({
    RoundStatus? status,
    TariffConfig? tariffSnapshot,
    Map<String, PlayerRoundInput>? playerInputs,
    RoundCalculationResult? calculationResult,
    String? settlementId,
    List<String>? confirmedByPlayerIds,
    bool? sessionPnlAccounted,
    DateTime? closedAt,
  }) {
    return GameRound(
      roundId: roundId,
      roundNumber: roundNumber,
      tableId: tableId,
      status: status ?? this.status,
      tariffSnapshot: tariffSnapshot ?? this.tariffSnapshot,
      playerInputs: playerInputs ?? this.playerInputs,
      calculationResult: calculationResult ?? this.calculationResult,
      settlementId: settlementId ?? this.settlementId,
      confirmedByPlayerIds: confirmedByPlayerIds ?? this.confirmedByPlayerIds,
      sessionPnlAccounted: sessionPnlAccounted ?? this.sessionPnlAccounted,
      createdAt: createdAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roundId': roundId,
      'roundNumber': roundNumber,
      'tableId': tableId,
      'status': status.name,
      'tariffSnapshot': tariffSnapshot.toMap(),
      'playerInputs':
          playerInputs.map((key, value) => MapEntry(key, value.toMap())),
      'calculationResult': calculationResult?.toMap(),
      'settlementId': settlementId,
      'confirmedByPlayerIds': confirmedByPlayerIds,
      'sessionPnlAccounted': sessionPnlAccounted,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'closedAt': closedAt?.toUtc().toIso8601String(),
    };
  }

  factory GameRound.fromMap(Map<String, dynamic> map) {
    final statusName = map['status']?.toString() ?? 'collectingPrizes';
    final status = RoundStatus.values.firstWhere(
      (e) => e.name == statusName,
      orElse: () => RoundStatus.collectingPrizes,
    );

    final inputsRaw = map['playerInputs'] as Map<String, dynamic>? ?? {};
    final inputs = <String, PlayerRoundInput>{};
    for (final entry in inputsRaw.entries) {
      inputs[entry.key] = PlayerRoundInput.fromMap(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }

    return GameRound(
      roundId: map['roundId']?.toString() ?? '',
      roundNumber: (map['roundNumber'] as num?)?.toInt() ?? 1,
      tableId: map['tableId']?.toString() ?? '',
      status: status,
      tariffSnapshot: TariffConfig.fromMap(
        Map<String, dynamic>.from(map['tariffSnapshot'] as Map? ?? {}),
      ),
      playerInputs: inputs,
      calculationResult: map['calculationResult'] != null
          ? RoundCalculationResult.fromMap(
              Map<String, dynamic>.from(map['calculationResult'] as Map),
            )
          : null,
      settlementId: map['settlementId']?.toString(),
      confirmedByPlayerIds: (map['confirmedByPlayerIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      sessionPnlAccounted: map['sessionPnlAccounted'] == true,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())?.toUtc() ??
              DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      closedAt: map['closedAt'] != null
          ? DateTime.tryParse(map['closedAt'].toString())?.toUtc()
          : null,
    );
  }
}
