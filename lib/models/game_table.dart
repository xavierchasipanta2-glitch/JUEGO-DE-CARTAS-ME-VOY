import 'ledger_entry.dart';
import 'player_account.dart';
import 'recharge_request.dart';
import 'round_models.dart';
import 'tariff_config.dart';

/// Estado global de la mesa de juego compartida.
enum TableStatus {
  /// Esperando que se conecten jugadores (mínimo 2, soporte principal para 4).
  waitingForPlayers,

  /// Partida/ronda en curso (captura de premios).
  inProgress,

  /// Ronda calculada en proceso de revisión y liquidación.
  settlingRound,

  /// Sesión de mesa cerrada definitivamente.
  closed,
}

/// Modelo único y centralizado de una Mesa de Juego «Me Voy».
/// Todos los teléfonos consultan y se suscriben a esta misma fuente de datos.
class GameTable {
  final String tableId;
  final String inviteCode;
  final String tableName;
  final String adminUserId;
  final String adminDisplayName;
  final int minPlayers;
  final int maxPlayers;
  final int defaultInitialCreditsCents;
  final bool autoSettleInternalCredits;
  final TableStatus status;
  final TariffConfig currentTariffs;
  final Map<String, PlayerAccount> participants;
  final GameRound? currentRound;
  final List<GameRound> completedRounds;
  final List<LedgerEntry> ledgerEntries;
  final List<RechargeRequest> rechargeRequests;
  final List<String> processedIdempotencyKeys;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;

  const GameTable({
    required this.tableId,
    required this.inviteCode,
    required this.tableName,
    required this.adminUserId,
    required this.adminDisplayName,
    this.minPlayers = 2,
    this.maxPlayers = 4,
    this.defaultInitialCreditsCents = 500, // $5.00 por defecto
    this.autoSettleInternalCredits = true,
    required this.status,
    required this.currentTariffs,
    required this.participants,
    this.currentRound,
    this.completedRounds = const [],
    this.ledgerEntries = const [],
    this.rechargeRequests = const [],
    this.processedIdempotencyKeys = const [],
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
  });

  /// Lista de participantes ordenada por número de asiento (1 a 4).
  List<PlayerAccount> get sortedParticipants {
    final list = participants.values.toList();
    list.sort((a, b) => a.seatNumber.compareTo(b.seatNumber));
    return list;
  }

  /// Verifica si un usuario es el administrador/banquero de la mesa.
  bool isUserAdmin(String userId) => adminUserId == userId;

  /// Cantidad de solicitudes de recarga pendientes de aprobación.
  int get pendingRechargeRequestsCount =>
      rechargeRequests.where((r) => r.isPending).length;

  /// Suma de todos los saldos netos de sesión de los participantes (invariante: debe ser 0).
  int get totalSessionNetSumCents => participants.values
      .fold(0, (sum, p) => sum + p.sessionNetBalanceCents);

  /// Total de créditos emitidos por el banco en toda la mesa.
  int get totalBankIssuedCreditsCents => participants.values
      .fold(0, (sum, p) => sum + p.totalIssuedCreditsCents);

  /// Total de créditos disponibles sumando las cuentas de todos los jugadores.
  int get totalAvailableCreditsInCirculationCents => participants.values
      .fold(0, (sum, p) => sum + p.availableBalanceCents);

  /// Indica si existe algún jugador con saldo insuficiente o deudas pendientes.
  bool get hasAnyFinancialAlert => participants.values.any(
        (p) =>
            p.hasPendingDebts ||
            p.hasLowOrInsufficientBalance ||
            pendingRechargeRequestsCount > 0,
      );

  GameTable copyWith({
    String? tableName,
    int? defaultInitialCreditsCents,
    bool? autoSettleInternalCredits,
    TableStatus? status,
    TariffConfig? currentTariffs,
    Map<String, PlayerAccount>? participants,
    GameRound? currentRound,
    bool clearCurrentRound = false,
    List<GameRound>? completedRounds,
    List<LedgerEntry>? ledgerEntries,
    List<RechargeRequest>? rechargeRequests,
    List<String>? processedIdempotencyKeys,
    int? version,
    DateTime? updatedAt,
    DateTime? closedAt,
  }) {
    return GameTable(
      tableId: tableId,
      inviteCode: inviteCode,
      tableName: tableName ?? this.tableName,
      adminUserId: adminUserId,
      adminDisplayName: adminDisplayName,
      minPlayers: minPlayers,
      maxPlayers: maxPlayers,
      defaultInitialCreditsCents:
          defaultInitialCreditsCents ?? this.defaultInitialCreditsCents,
      autoSettleInternalCredits:
          autoSettleInternalCredits ?? this.autoSettleInternalCredits,
      status: status ?? this.status,
      currentTariffs: currentTariffs ?? this.currentTariffs,
      participants: participants ?? this.participants,
      currentRound:
          clearCurrentRound ? null : (currentRound ?? this.currentRound),
      completedRounds: completedRounds ?? this.completedRounds,
      ledgerEntries: ledgerEntries ?? this.ledgerEntries,
      rechargeRequests: rechargeRequests ?? this.rechargeRequests,
      processedIdempotencyKeys:
          processedIdempotencyKeys ?? this.processedIdempotencyKeys,
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tableId': tableId,
      'inviteCode': inviteCode,
      'tableName': tableName,
      'adminUserId': adminUserId,
      'adminDisplayName': adminDisplayName,
      'minPlayers': minPlayers,
      'maxPlayers': maxPlayers,
      'defaultInitialCreditsCents': defaultInitialCreditsCents,
      'autoSettleInternalCredits': autoSettleInternalCredits,
      'status': status.name,
      'currentTariffs': currentTariffs.toMap(),
      'participants':
          participants.map((key, value) => MapEntry(key, value.toMap())),
      'currentRound': currentRound?.toMap(),
      'completedRounds': completedRounds.map((e) => e.toMap()).toList(),
      'ledgerEntries': ledgerEntries.map((e) => e.toMap()).toList(),
      'rechargeRequests': rechargeRequests.map((e) => e.toMap()).toList(),
      'processedIdempotencyKeys': processedIdempotencyKeys,
      'version': version,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'closedAt': closedAt?.toUtc().toIso8601String(),
    };
  }

  factory GameTable.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status']?.toString() ?? 'waitingForPlayers';
    final status = TableStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => TableStatus.waitingForPlayers,
    );

    final participantsRaw =
        map['participants'] as Map<String, dynamic>? ?? {};
    final participantsMap = <String, PlayerAccount>{};
    for (final entry in participantsRaw.entries) {
      participantsMap[entry.key] = PlayerAccount.fromMap(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }

    return GameTable(
      tableId: map['tableId']?.toString() ?? '',
      inviteCode: map['inviteCode']?.toString() ?? '',
      tableName: map['tableName']?.toString() ?? 'Mesa Me Voy',
      adminUserId: map['adminUserId']?.toString() ?? '',
      adminDisplayName: map['adminDisplayName']?.toString() ?? 'Admin',
      minPlayers: (map['minPlayers'] as num?)?.toInt() ?? 2,
      maxPlayers: (map['maxPlayers'] as num?)?.toInt() ?? 4,
      defaultInitialCreditsCents:
          (map['defaultInitialCreditsCents'] as num?)?.toInt() ?? 500,
      autoSettleInternalCredits: map['autoSettleInternalCredits'] != false,
      status: status,
      currentTariffs: TariffConfig.fromMap(
        Map<String, dynamic>.from(map['currentTariffs'] as Map? ?? {}),
      ),
      participants: participantsMap,
      currentRound: map['currentRound'] != null
          ? GameRound.fromMap(
              Map<String, dynamic>.from(map['currentRound'] as Map),
            )
          : null,
      completedRounds: (map['completedRounds'] as List<dynamic>? ?? [])
          .map((e) => GameRound.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      ledgerEntries: (map['ledgerEntries'] as List<dynamic>? ?? [])
          .map((e) => LedgerEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      rechargeRequests: (map['rechargeRequests'] as List<dynamic>? ?? [])
          .map((e) =>
              RechargeRequest.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      processedIdempotencyKeys:
          (map['processedIdempotencyKeys'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      version: (map['version'] as num?)?.toInt() ?? 1,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())?.toUtc() ??
              DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())?.toUtc() ??
              DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      closedAt: map['closedAt'] != null
          ? DateTime.tryParse(map['closedAt'].toString())?.toUtc()
          : null,
    );
  }
}
