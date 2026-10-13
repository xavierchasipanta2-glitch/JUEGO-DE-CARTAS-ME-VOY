/// Estado de una solicitud de recarga de créditos internos.
enum RechargeRequestStatus {
  pending,
  approved,
  rejected,
}

/// Solicitud de recarga realizada por un participante al banco virtual de la mesa.
class RechargeRequest {
  final String requestId;
  final String tableId;
  final String playerId;
  final String playerName;
  final int amountCents;
  final String note;
  final RechargeRequestStatus status;
  final DateTime requestedAt;
  final DateTime? resolvedAt;
  final String? resolvedByUserId;
  final String? resolvedByUserName;
  final String? resolutionReason;
  final String? ledgerEntryId;

  const RechargeRequest({
    required this.requestId,
    required this.tableId,
    required this.playerId,
    required this.playerName,
    required this.amountCents,
    required this.note,
    this.status = RechargeRequestStatus.pending,
    required this.requestedAt,
    this.resolvedAt,
    this.resolvedByUserId,
    this.resolvedByUserName,
    this.resolutionReason,
    this.ledgerEntryId,
  });

  bool get isPending => status == RechargeRequestStatus.pending;

  RechargeRequest copyWith({
    RechargeRequestStatus? status,
    DateTime? resolvedAt,
    String? resolvedByUserId,
    String? resolvedByUserName,
    String? resolutionReason,
    String? ledgerEntryId,
  }) {
    return RechargeRequest(
      requestId: requestId,
      tableId: tableId,
      playerId: playerId,
      playerName: playerName,
      amountCents: amountCents,
      note: note,
      status: status ?? this.status,
      requestedAt: requestedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedByUserId: resolvedByUserId ?? this.resolvedByUserId,
      resolvedByUserName: resolvedByUserName ?? this.resolvedByUserName,
      resolutionReason: resolutionReason ?? this.resolutionReason,
      ledgerEntryId: ledgerEntryId ?? this.ledgerEntryId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'tableId': tableId,
      'playerId': playerId,
      'playerName': playerName,
      'amountCents': amountCents,
      'note': note,
      'status': status.name,
      'requestedAt': requestedAt.toUtc().toIso8601String(),
      'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
      'resolvedByUserId': resolvedByUserId,
      'resolvedByUserName': resolvedByUserName,
      'resolutionReason': resolutionReason,
      'ledgerEntryId': ledgerEntryId,
    };
  }

  factory RechargeRequest.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status']?.toString() ?? 'pending';
    return RechargeRequest(
      requestId: map['requestId']?.toString() ?? '',
      tableId: map['tableId']?.toString() ?? '',
      playerId: map['playerId']?.toString() ?? '',
      playerName: map['playerName']?.toString() ?? 'Jugador',
      amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
      note: map['note']?.toString() ?? '',
      status: RechargeRequestStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => RechargeRequestStatus.pending,
      ),
      requestedAt: map['requestedAt'] != null
          ? DateTime.tryParse(map['requestedAt'].toString())?.toUtc() ??
              DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.tryParse(map['resolvedAt'].toString())?.toUtc()
          : null,
      resolvedByUserId: map['resolvedByUserId']?.toString(),
      resolvedByUserName: map['resolvedByUserName']?.toString(),
      resolutionReason: map['resolutionReason']?.toString(),
      ledgerEntryId: map['ledgerEntryId']?.toString(),
    );
  }
}
