/// Cuenta individual de un jugador dentro del banco virtual de una mesa.
/// Separa estrictamente el capital emitido (créditos iniciales, recargas y ajustes)
/// del resultado económico de juego (ganancias acumuladas, pérdidas acumuladas, saldo neto de sesión)
/// y de las cuentas por cobrar/pagar (premios pendientes, deudas pendientes).
class PlayerAccount {
  final String playerId;
  final String displayName;
  final String email;
  final int seatNumber;
  final bool isAdmin;

  /// Saldo disponible actual en créditos internos (en centavos).
  /// Nunca puede ser negativo: el banco bloquea operaciones que excedan este saldo.
  final int availableBalanceCents;

  /// Créditos iniciales asignados por el banco al crear/abrir la cuenta en la mesa.
  final int initialCreditsCents;

  /// Total acumulado de recargas aprobadas por el banco.
  /// No se contabiliza como ganancia del juego.
  final int totalRechargesCents;

  /// Suma neta de ajustes administrativos auditables (positivos o negativos).
  final int adminAdjustmentsCents;

  /// Ganancias netas acumuladas en rondas donde el jugador obtuvo resultado neto positivo.
  final int accumulatedWinningsCents;

  /// Pérdidas netas acumuladas (valor absoluto en centavos) en rondas donde el jugador obtuvo resultado neto negativo.
  final int accumulatedLossesCents;

  /// Deudas pendientes de pago por rondas finalizadas que aún no se han liquidado en créditos.
  final int pendingDebtsCents;

  /// Premios pendientes de cobro por rondas finalizadas que aún no han sido pagados por los deudores.
  final int pendingPrizesCents;

  /// Número de partidas (mesas/rondas) ganadas por este jugador en la sesión.
  final int roundsWon;

  final DateTime joinedAt;
  final DateTime lastUpdatedAt;

  const PlayerAccount({
    required this.playerId,
    required this.displayName,
    required this.email,
    required this.seatNumber,
    this.isAdmin = false,
    required this.availableBalanceCents,
    required this.initialCreditsCents,
    this.totalRechargesCents = 0,
    this.adminAdjustmentsCents = 0,
    this.accumulatedWinningsCents = 0,
    this.accumulatedLossesCents = 0,
    this.pendingDebtsCents = 0,
    this.pendingPrizesCents = 0,
    this.roundsWon = 0,
    required this.joinedAt,
    required this.lastUpdatedAt,
  });

  /// Saldo neto histórico de la sesión de juego (Ganancias acumuladas - Pérdidas acumuladas).
  /// Es independiente de los créditos iniciales y de las recargas.
  int get sessionNetBalanceCents =>
      accumulatedWinningsCents - accumulatedLossesCents;

  /// Total de créditos emitidos por el banco a favor de este jugador (Iniciales + Recargas + Ajustes).
  int get totalIssuedCreditsCents =>
      initialCreditsCents + totalRechargesCents + adminAdjustmentsCents;

  /// Indica si el jugador tiene deudas pendientes por saldar.
  bool get hasPendingDebts => pendingDebtsCents > 0;

  /// Indica si el jugador tiene premios pendientes por cobrar.
  bool get hasPendingPrizes => pendingPrizesCents > 0;

  /// Alerta visual de saldo bajo (menos de $1.00 = 100 centavos) o insuficiente para cubrir deudas pendientes.
  bool get hasLowOrInsufficientBalance =>
      availableBalanceCents < 100 || availableBalanceCents < pendingDebtsCents;

  PlayerAccount copyWith({
    String? playerId,
    String? displayName,
    String? email,
    int? seatNumber,
    bool? isAdmin,
    int? availableBalanceCents,
    int? initialCreditsCents,
    int? totalRechargesCents,
    int? adminAdjustmentsCents,
    int? accumulatedWinningsCents,
    int? accumulatedLossesCents,
    int? pendingDebtsCents,
    int? pendingPrizesCents,
    int? roundsWon,
    DateTime? joinedAt,
    DateTime? lastUpdatedAt,
  }) {
    return PlayerAccount(
      playerId: playerId ?? this.playerId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      seatNumber: seatNumber ?? this.seatNumber,
      isAdmin: isAdmin ?? this.isAdmin,
      availableBalanceCents:
          availableBalanceCents ?? this.availableBalanceCents,
      initialCreditsCents: initialCreditsCents ?? this.initialCreditsCents,
      totalRechargesCents: totalRechargesCents ?? this.totalRechargesCents,
      adminAdjustmentsCents:
          adminAdjustmentsCents ?? this.adminAdjustmentsCents,
      accumulatedWinningsCents:
          accumulatedWinningsCents ?? this.accumulatedWinningsCents,
      accumulatedLossesCents:
          accumulatedLossesCents ?? this.accumulatedLossesCents,
      pendingDebtsCents: pendingDebtsCents ?? this.pendingDebtsCents,
      pendingPrizesCents: pendingPrizesCents ?? this.pendingPrizesCents,
      roundsWon: roundsWon ?? this.roundsWon,
      joinedAt: joinedAt ?? this.joinedAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'displayName': displayName,
      'email': email,
      'seatNumber': seatNumber,
      'isAdmin': isAdmin,
      'availableBalanceCents': availableBalanceCents,
      'initialCreditsCents': initialCreditsCents,
      'totalRechargesCents': totalRechargesCents,
      'adminAdjustmentsCents': adminAdjustmentsCents,
      'accumulatedWinningsCents': accumulatedWinningsCents,
      'accumulatedLossesCents': accumulatedLossesCents,
      'sessionNetBalanceCents': sessionNetBalanceCents,
      'pendingDebtsCents': pendingDebtsCents,
      'pendingPrizesCents': pendingPrizesCents,
      'roundsWon': roundsWon,
      'joinedAt': joinedAt.toUtc().toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toUtc().toIso8601String(),
    };
  }

  factory PlayerAccount.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now().toUtc();
    return PlayerAccount(
      playerId: map['playerId']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? 'Jugador',
      email: map['email']?.toString() ?? '',
      seatNumber: (map['seatNumber'] as num?)?.toInt() ?? 1,
      isAdmin: map['isAdmin'] == true,
      availableBalanceCents:
          (map['availableBalanceCents'] as num?)?.toInt() ?? 0,
      initialCreditsCents: (map['initialCreditsCents'] as num?)?.toInt() ?? 0,
      totalRechargesCents: (map['totalRechargesCents'] as num?)?.toInt() ?? 0,
      adminAdjustmentsCents:
          (map['adminAdjustmentsCents'] as num?)?.toInt() ?? 0,
      accumulatedWinningsCents:
          (map['accumulatedWinningsCents'] as num?)?.toInt() ?? 0,
      accumulatedLossesCents:
          (map['accumulatedLossesCents'] as num?)?.toInt() ?? 0,
      pendingDebtsCents: (map['pendingDebtsCents'] as num?)?.toInt() ?? 0,
      pendingPrizesCents: (map['pendingPrizesCents'] as num?)?.toInt() ?? 0,
      roundsWon: (map['roundsWon'] as num?)?.toInt() ?? 0,
      joinedAt: map['joinedAt'] != null
          ? DateTime.tryParse(map['joinedAt'].toString())?.toUtc() ?? now
          : now,
      lastUpdatedAt: map['lastUpdatedAt'] != null
          ? DateTime.tryParse(map['lastUpdatedAt'].toString())?.toUtc() ?? now
          : now,
    );
  }
}
