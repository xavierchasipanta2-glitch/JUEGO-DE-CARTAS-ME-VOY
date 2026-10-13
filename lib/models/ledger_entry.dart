/// Tipo de movimiento contable dentro del banco virtual.
/// Distingue estrictamente emisiones de capital (asignación inicial, recarga, ajuste)
/// de las liquidaciones y transferencias entre jugadores.
enum LedgerMovementType {
  /// Asignación inicial de créditos al unirse o iniciar la cuenta en la mesa.
  initialAllocation,

  /// Recarga de créditos aprobada por el administrador del banco.
  approvedRecharge,

  /// Liquidación automática o pago de deuda originado por el resultado de una partida.
  roundSettlementTransfer,

  /// Verificación de un pago externo pendiente asociado a una liquidación de partida.
  externalPaymentVerified,

  /// Transferencia directa voluntaria de créditos internos entre dos jugadores.
  directPeerTransfer,

  /// Ajuste administrativo auditable (positivo o negativo) para corrección de errores.
  adminAdjustment,
}

/// Estado de un movimiento en el libro mayor.
enum LedgerMovementStatus {
  completed,
  pendingVerification,
  rejected,
}

/// Registro inmutable en el libro mayor contable (Ledger) de la mesa.
/// Ningún movimiento confirmado puede ser borrado silenciosamente.
class LedgerEntry {
  /// Identificador único del movimiento (`tx_...`).
  final String entryId;

  /// Clave de idempotencia única para impedir operaciones o liquidaciones duplicadas.
  final String idempotencyKey;

  /// Identificador de la mesa.
  final String tableId;

  /// Partida (ronda) asociada, o `null` si es asignación inicial / recarga / ajuste general.
  final String? roundId;
  final int? roundNumber;

  /// Tipo de movimiento contable.
  final LedgerMovementType type;

  /// Cuenta de origen (`BANK` cuando es emisión del banco virtual, o el `playerId` deudor).
  final String fromAccountId;
  final String fromAccountName;

  /// Cuenta de destino (`BANK` en caso de reverso/ajuste negativo al banco, o el `playerId` acreedor).
  final String toAccountId;
  final String toAccountName;

  /// Importe exacto en centavos enteros (> 0).
  final int amountCents;

  /// Fecha y hora exacta del registro en UTC.
  final DateTime createdAt;

  /// Estado del movimiento.
  final LedgerMovementStatus status;

  /// Motivo descriptivo y auditable de la operación.
  final String reason;

  /// Usuario responsable que autorizó o ejecutó la operación.
  final String authorizedByUserId;
  final String authorizedByUserName;

  /// Referencia al identificador del cálculo (`calculationId`) o liquidación (`settlementId`) que originó el movimiento.
  final String? calculationReferenceId;

  const LedgerEntry({
    required this.entryId,
    required this.idempotencyKey,
    required this.tableId,
    this.roundId,
    this.roundNumber,
    required this.type,
    required this.fromAccountId,
    required this.fromAccountName,
    required this.toAccountId,
    required this.toAccountName,
    required this.amountCents,
    required this.createdAt,
    required this.status,
    required this.reason,
    required this.authorizedByUserId,
    required this.authorizedByUserName,
    this.calculationReferenceId,
  });

  String get typeDisplayLabel {
    switch (type) {
      case LedgerMovementType.initialAllocation:
        return 'Asignación inicial';
      case LedgerMovementType.approvedRecharge:
        return 'Recarga aprobada';
      case LedgerMovementType.roundSettlementTransfer:
        return 'Liquidación de partida';
      case LedgerMovementType.externalPaymentVerified:
        return 'Pago externo verificado';
      case LedgerMovementType.directPeerTransfer:
        return 'Transferencia entre jugadores';
      case LedgerMovementType.adminAdjustment:
        return 'Ajuste auditable';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'entryId': entryId,
      'idempotencyKey': idempotencyKey,
      'tableId': tableId,
      'roundId': roundId,
      'roundNumber': roundNumber,
      'type': type.name,
      'fromAccountId': fromAccountId,
      'fromAccountName': fromAccountName,
      'toAccountId': toAccountId,
      'toAccountName': toAccountName,
      'amountCents': amountCents,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'status': status.name,
      'reason': reason,
      'authorizedByUserId': authorizedByUserId,
      'authorizedByUserName': authorizedByUserName,
      'calculationReferenceId': calculationReferenceId,
    };
  }

  factory LedgerEntry.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type']?.toString() ?? 'roundSettlementTransfer';
    final statusStr = map['status']?.toString() ?? 'completed';
    return LedgerEntry(
      entryId: map['entryId']?.toString() ?? '',
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      tableId: map['tableId']?.toString() ?? '',
      roundId: map['roundId']?.toString(),
      roundNumber: (map['roundNumber'] as num?)?.toInt(),
      type: LedgerMovementType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => LedgerMovementType.roundSettlementTransfer,
      ),
      fromAccountId: map['fromAccountId']?.toString() ?? '',
      fromAccountName: map['fromAccountName']?.toString() ?? '',
      toAccountId: map['toAccountId']?.toString() ?? '',
      toAccountName: map['toAccountName']?.toString() ?? '',
      amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())?.toUtc() ??
              DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      status: LedgerMovementStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => LedgerMovementStatus.completed,
      ),
      reason: map['reason']?.toString() ?? '',
      authorizedByUserId: map['authorizedByUserId']?.toString() ?? '',
      authorizedByUserName: map['authorizedByUserName']?.toString() ?? '',
      calculationReferenceId: map['calculationReferenceId']?.toString(),
    );
  }
}
