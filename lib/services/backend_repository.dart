import 'dart:math';

import '../engine/settlement_engine.dart';
import '../models/game_table.dart';
import '../models/ledger_entry.dart';
import '../models/player_account.dart';
import '../models/recharge_request.dart';
import '../models/round_models.dart';
import '../models/tariff_config.dart';

/// Sesión autenticada del usuario actual.
class AppUserSession {
  final String userId;
  final String displayName;
  final String email;
  final bool isFirebaseAccount;

  const AppUserSession({
    required this.userId,
    required this.displayName,
    required this.email,
    this.isFirebaseAccount = false,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'displayName': displayName,
        'email': email,
        'isFirebaseAccount': isFirebaseAccount,
      };

  factory AppUserSession.fromMap(Map<String, dynamic> map) {
    return AppUserSession(
      userId: map['userId']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? 'Jugador',
      email: map['email']?.toString() ?? '',
      isFirebaseAccount: map['isFirebaseAccount'] == true,
    );
  }
}

/// Excepción controlada para errores financieros, de seguridad, permisos o idempotencia.
class BankOperationException implements Exception {
  final String code;
  final String message;

  const BankOperationException(this.code, this.message);

  @override
  String toString() => message;
}

/// Contrato de repositorio del servidor/banco para «Me Voy».
abstract class GameBackendRepository {
  bool get isUsingCloudFirebase;

  Future<AppUserSession?> restoreSession();

  Future<AppUserSession> signInWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  Future<AppUserSession> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AppUserSession> signInQuickProfile({
    required String displayName,
    required String email,
  });

  Future<void> signOut();

  Future<String?> getSavedActiveTableId();
  Future<void> saveActiveTableId(String? tableId);

  Future<GameTable> createTable({
    required AppUserSession adminUser,
    required String tableName,
    required int initialCreditsCents,
    TariffConfig? customTariffs,
    bool autoCreateDemoPlayers = false,
  });

  Future<GameTable> joinTableByCode({
    required AppUserSession user,
    required String inviteCode,
  });

  Future<GameTable?> getTableById(String tableId);

  Stream<GameTable?> watchTable(String tableId);

  Future<GameTable> addParticipantAccountByAdmin({
    required String tableId,
    required String adminUserId,
    required String displayName,
    required String email,
    required int initialCreditsCents,
    String? customPlayerId,
  });

  Future<GameTable> updateTableTariffs({
    required String tableId,
    required String adminUserId,
    required TariffConfig newTariffs,
  });

  Future<GameTable> requestRecharge({
    required String tableId,
    required String playerId,
    required int amountCents,
    required String note,
    required String idempotencyKey,
  });

  Future<GameTable> resolveRechargeRequest({
    required String tableId,
    required String adminUserId,
    required String requestId,
    required bool approve,
    required String reason,
  });

  Future<GameTable> applyAdminCreditAdjustment({
    required String tableId,
    required String adminUserId,
    required String targetPlayerId,
    required int deltaCents,
    required String reason,
    required bool isInitialCreditAllocation,
    required String idempotencyKey,
  });

  Future<GameTable> executeInternalTransfer({
    required String tableId,
    required String callerUserId,
    required String fromPlayerId,
    required String toPlayerId,
    required int amountCents,
    required String reason,
    required String idempotencyKey,
  });

  Future<GameTable> startNextRound({
    required String tableId,
    required String callerUserId,
  });

  Future<GameTable> updatePlayerRoundPrizes({
    required String tableId,
    required String callerUserId,
    required PlayerRoundInput input,
  });

  Future<GameTable> calculateCurrentRound({
    required String tableId,
    required String callerUserId,
  });

  Future<GameTable> reopenCurrentRoundForEditing({
    required String tableId,
    required String adminUserId,
  });

  Future<GameTable> confirmRoundResultByPlayer({
    required String tableId,
    required String playerId,
  });

  Future<GameTable> executeRoundSettlement({
    required String tableId,
    required String adminUserId,
    required String roundId,
    required bool allowPendingIfInsufficient,
  });

  Future<GameTable> settlePendingRoundTransfer({
    required String tableId,
    required String adminUserId,
    required String roundId,
    required String transferItemId,
    required bool useInternalCredits,
    required String verificationNote,
    required String idempotencyKey,
  });

  Future<GameTable> closeTableSession({
    required String tableId,
    required String adminUserId,
  });
}

/// Procesador transaccional determinista que aplica todas las reglas de seguridad,
/// contabilidad, idempotencia y permisos tanto en transacciones de Firestore como en modo local.
class TransactionalTableProcessor {
  const TransactionalTableProcessor._();

  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generateInviteCode([int length = 6]) {
    final rnd = Random.secure();
    return List.generate(
      length,
      (_) => _chars[rnd.nextInt(_chars.length)],
    ).join();
  }

  /// Crea una nueva mesa con el administrador como primer participante y asiento 1.
  static GameTable buildNewTable({
    required String tableId,
    required String inviteCode,
    required AppUserSession adminUser,
    required String tableName,
    required int initialCreditsCents,
    TariffConfig? customTariffs,
    bool autoCreateDemoPlayers = false,
  }) {
    if (initialCreditsCents < 0) {
      throw const BankOperationException(
        'invalid-amount',
        'Los créditos iniciales no pueden ser negativos.',
      );
    }

    final now = DateTime.now().toUtc();
    final tariffs = (customTariffs ??
            TariffConfig.defaultStandard(adminUserId: adminUser.userId))
        .freezeCopy();

    final participants = <String, PlayerAccount>{};
    final ledgerEntries = <LedgerEntry>[];
    final processedKeys = <String>[];

    // Cuenta del Administrador (Asiento 1)
    participants[adminUser.userId] = PlayerAccount(
      playerId: adminUser.userId,
      displayName: adminUser.displayName,
      email: adminUser.email,
      seatNumber: 1,
      isAdmin: true,
      availableBalanceCents: initialCreditsCents,
      initialCreditsCents: initialCreditsCents,
      joinedAt: now,
      lastUpdatedAt: now,
    );

    if (initialCreditsCents > 0) {
      final initKey = 'init_${tableId}_${adminUser.userId}';
      processedKeys.add(initKey);
      ledgerEntries.add(
        LedgerEntry(
          entryId: 'tx_init_${adminUser.userId}',
          idempotencyKey: initKey,
          tableId: tableId,
          type: LedgerMovementType.initialAllocation,
          fromAccountId: 'BANK',
          fromAccountName: 'Banco Virtual',
          toAccountId: adminUser.userId,
          toAccountName: adminUser.displayName,
          amountCents: initialCreditsCents,
          createdAt: now,
          status: LedgerMovementStatus.completed,
          reason: 'Asignación inicial de créditos al crear la mesa',
          authorizedByUserId: adminUser.userId,
          authorizedByUserName: adminUser.displayName,
        ),
      );
    }

    var table = GameTable(
      tableId: tableId,
      inviteCode: inviteCode.toUpperCase(),
      tableName: tableName.trim().isEmpty ? 'Mesa Rummy Me Voy' : tableName.trim(),
      adminUserId: adminUser.userId,
      adminDisplayName: adminUser.displayName,
      defaultInitialCreditsCents: initialCreditsCents,
      status: TableStatus.waitingForPlayers,
      currentTariffs: tariffs,
      participants: participants,
      ledgerEntries: ledgerEntries,
      processedIdempotencyKeys: processedKeys,
      version: 1,
      createdAt: now,
      updatedAt: now,
    );

    if (autoCreateDemoPlayers) {
      final demoCompanions = [
        ('p2_carlos', 'Carlos', 'carlos@mevoy.app'),
        ('p3_elena', 'Elena', 'elena@mevoy.app'),
        ('p4_marco', 'Marco', 'marco@mevoy.app'),
      ];
      for (final comp in demoCompanions) {
        table = applyAddParticipant(
          table: table,
          playerId: comp.$1,
          displayName: comp.$2,
          email: comp.$3,
          initialCreditsCents: initialCreditsCents,
          authorizedByUserId: adminUser.userId,
          authorizedByUserName: adminUser.displayName,
        );
      }
      table = applyStartNextRound(
        table: table,
        callerUserId: adminUser.userId,
      );
    }

    return table;
  }

  /// Une a un jugador o crea su cuenta en la mesa (hasta 4 jugadores).
  static GameTable applyAddParticipant({
    required GameTable table,
    required String playerId,
    required String displayName,
    required String email,
    required int initialCreditsCents,
    required String authorizedByUserId,
    required String authorizedByUserName,
  }) {
    if (table.status == TableStatus.closed) {
      throw const BankOperationException(
        'table-closed',
        'La mesa ya se encuentra cerrada y no admite nuevos participantes.',
      );
    }

    // Si el jugador ya pertenece a la mesa, devolvemos el estado actual (idempotente al reconectar)
    if (table.participants.containsKey(playerId)) {
      return table;
    }

    if (table.participants.length >= table.maxPlayers) {
      throw BankOperationException(
        'table-full',
        'La mesa ya tiene el máximo de ${table.maxPlayers} jugadores conectados.',
      );
    }

    if (initialCreditsCents < 0) {
      throw const BankOperationException(
        'invalid-amount',
        'Los créditos iniciales no pueden ser negativos.',
      );
    }

    final now = DateTime.now().toUtc();
    final usedSeats =
        table.participants.values.map((p) => p.seatNumber).toSet();
    int nextSeat = 1;
    while (usedSeats.contains(nextSeat)) {
      nextSeat++;
    }

    final newPlayer = PlayerAccount(
      playerId: playerId,
      displayName: displayName.trim().isEmpty ? 'Jugador $nextSeat' : displayName.trim(),
      email: email.trim(),
      seatNumber: nextSeat,
      isAdmin: false,
      availableBalanceCents: initialCreditsCents,
      initialCreditsCents: initialCreditsCents,
      joinedAt: now,
      lastUpdatedAt: now,
    );

    final updatedParticipants = Map<String, PlayerAccount>.from(table.participants)
      ..[playerId] = newPlayer;

    final updatedLedger = List<LedgerEntry>.from(table.ledgerEntries);
    final updatedKeys = List<String>.from(table.processedIdempotencyKeys);

    if (initialCreditsCents > 0) {
      final initKey = 'init_${table.tableId}_$playerId';
      if (!updatedKeys.contains(initKey)) {
        updatedKeys.add(initKey);
        updatedLedger.insert(
          0,
          LedgerEntry(
            entryId: 'tx_init_${playerId}_${now.millisecondsSinceEpoch}',
            idempotencyKey: initKey,
            tableId: table.tableId,
            type: LedgerMovementType.initialAllocation,
            fromAccountId: 'BANK',
            fromAccountName: 'Banco Virtual',
            toAccountId: playerId,
            toAccountName: newPlayer.displayName,
            amountCents: initialCreditsCents,
            createdAt: now,
            status: LedgerMovementStatus.completed,
            reason: 'Asignación inicial de créditos al ingresar a la mesa',
            authorizedByUserId: authorizedByUserId,
            authorizedByUserName: authorizedByUserName,
          ),
        );
      }
    }

    // Si hay una ronda en captura de premios, agregar entrada en blanco para el nuevo jugador
    GameRound? updatedRound = table.currentRound;
    if (updatedRound != null &&
        updatedRound.status == RoundStatus.collectingPrizes) {
      final updatedInputs =
          Map<String, PlayerRoundInput>.from(updatedRound.playerInputs);
      updatedInputs[playerId] = PlayerRoundInput(
        playerId: playerId,
        displayName: newPlayer.displayName,
      );
      updatedRound = updatedRound.copyWith(playerInputs: updatedInputs);
    }

    return table.copyWith(
      participants: updatedParticipants,
      ledgerEntries: updatedLedger,
      processedIdempotencyKeys: updatedKeys,
      currentRound: updatedRound,
      version: table.version + 1,
      updatedAt: now,
    );
  }

  /// Actualiza las tarifas de la mesa para partidas futuras (sin alterar rondas cerradas).
  static GameTable applyUpdateTariffs({
    required GameTable table,
    required String adminUserId,
    required TariffConfig newTariffs,
  }) {
    if (!table.isUserAdmin(adminUserId)) {
      throw const BankOperationException(
        'permission-denied',
        'Solo el administrador de la mesa puede modificar las tarifas.',
      );
    }
    final errors = newTariffs.validate();
    if (errors.isNotEmpty) {
      throw BankOperationException('invalid-tariffs', errors.join('\n'));
    }

    final now = DateTime.now().toUtc();
    final frozen = newTariffs.copyWith(
      updatedAt: now,
      updatedByUserId: adminUserId,
    );

    // Si la ronda activa aún está en captura de premios (no calculada), actualiza su snapshot;
    // las rondas ya calculadas o cerradas conservan intacta su copia histórica.
    GameRound? updatedCurrentRound = table.currentRound;
    if (updatedCurrentRound != null &&
        updatedCurrentRound.status == RoundStatus.collectingPrizes) {
      updatedCurrentRound = updatedCurrentRound.copyWith(
        tariffSnapshot: frozen.freezeCopy(),
      );
    }

    return table.copyWith(
      currentTariffs: frozen,
      currentRound: updatedCurrentRound,
      version: table.version + 1,
      updatedAt: now,
    );
  }

  /// Crea una solicitud de recarga de créditos para un jugador.
  static GameTable applyRequestRecharge({
    required GameTable table,
    required String playerId,
    required int amountCents,
    required String note,
    required String idempotencyKey,
  }) {
    if (!table.participants.containsKey(playerId)) {
      throw const BankOperationException(
        'not-participant',
        'El jugador no pertenece a esta mesa.',
      );
    }
    if (amountCents <= 0) {
      throw const BankOperationException(
        'invalid-amount',
        'El importe de la recarga debe ser mayor a \$0.00.',
      );
    }
    if (table.processedIdempotencyKeys.contains(idempotencyKey)) {
      throw const BankOperationException(
        'duplicate-operation',
        'Esta solicitud de recarga ya fue registrada.',
      );
    }

    final player = table.participants[playerId]!;
    final now = DateTime.now().toUtc();
    final requestId = 'req_${now.millisecondsSinceEpoch}_${playerId.hashCode.abs()}';

    final newRequest = RechargeRequest(
      requestId: requestId,
      tableId: table.tableId,
      playerId: playerId,
      playerName: player.displayName,
      amountCents: amountCents,
      note: note.trim().isEmpty ? 'Solicitud de recarga de créditos' : note.trim(),
      status: RechargeRequestStatus.pending,
      requestedAt: now,
    );

    return table.copyWith(
      rechargeRequests: [newRequest, ...table.rechargeRequests],
      processedIdempotencyKeys: [
        ...table.processedIdempotencyKeys,
        idempotencyKey,
      ],
      version: table.version + 1,
      updatedAt: now,
    );
  }

  /// Aprueba o rechaza una solicitud de recarga pendiente (solo administrador del banco).
  static GameTable applyResolveRecharge({
    required GameTable table,
    required String adminUserId,
    required String requestId,
    required bool approve,
    required String reason,
  }) {
    if (!table.isUserAdmin(adminUserId)) {
      throw const BankOperationException(
        'permission-denied',
        'Solo el administrador del banco puede aprobar o rechazar solicitudes de recarga.',
      );
    }

    final idempotencyKey = 'resolve_recharge_$requestId';
    if (table.processedIdempotencyKeys.contains(idempotencyKey)) {
      throw const BankOperationException(
        'duplicate-operation',
        'Esta solicitud de recarga ya fue procesada anteriormente.',
      );
    }

    final index =
        table.rechargeRequests.indexWhere((r) => r.requestId == requestId);
    if (index == -1) {
      throw const BankOperationException(
        'not-found',
        'No se encontró la solicitud de recarga especificada.',
      );
    }

    final req = table.rechargeRequests[index];
    if (!req.isPending) {
      throw const BankOperationException(
        'already-resolved',
        'La solicitud de recarga ya fue resuelta.',
      );
    }

    final now = DateTime.now().toUtc();
    final updatedParticipants =
        Map<String, PlayerAccount>.from(table.participants);
    final updatedLedger = List<LedgerEntry>.from(table.ledgerEntries);
    final updatedRequests = List<RechargeRequest>.from(table.rechargeRequests);

    String? txId;
    if (approve) {
      final player = updatedParticipants[req.playerId];
      if (player == null) {
        throw const BankOperationException(
          'not-found',
          'La cuenta del jugador solicitante no existe en la mesa.',
        );
      }

      txId = 'tx_rec_$requestId';
      // Importante (Sección 3 y 7):
      // La recarga aumenta el saldo disponible y el total de recargas,
      // pero NUNCA se registra como ganancia del juego.
      updatedParticipants[req.playerId] = player.copyWith(
        availableBalanceCents: player.availableBalanceCents + req.amountCents,
        totalRechargesCents: player.totalRechargesCents + req.amountCents,
        lastUpdatedAt: now,
      );

      updatedLedger.insert(
        0,
        LedgerEntry(
          entryId: txId,
          idempotencyKey: idempotencyKey,
          tableId: table.tableId,
          type: LedgerMovementType.approvedRecharge,
          fromAccountId: 'BANK',
          fromAccountName: 'Banco Virtual',
          toAccountId: player.playerId,
          toAccountName: player.displayName,
          amountCents: req.amountCents,
          createdAt: now,
          status: LedgerMovementStatus.completed,
          reason: reason.trim().isEmpty
              ? 'Recarga aprobada (${req.note})'
              : reason.trim(),
          authorizedByUserId: adminUserId,
          authorizedByUserName: table.adminDisplayName,
          calculationReferenceId: requestId,
        ),
      );
    }

    updatedRequests[index] = req.copyWith(
      status: approve
          ? RechargeRequestStatus.approved
          : RechargeRequestStatus.rejected,
      resolvedAt: now,
      resolvedByUserId: adminUserId,
      resolvedByUserName: table.adminDisplayName,
      resolutionReason: reason.trim().isEmpty
          ? (approve ? 'Aprobada por el banco' : 'Rechazada por el banco')
          : reason.trim(),
      ledgerEntryId: txId,
    );

    return table.copyWith(
      participants: updatedParticipants,
      ledgerEntries: updatedLedger,
      rechargeRequests: updatedRequests,
      processedIdempotencyKeys: [
        ...table.processedIdempotencyKeys,
        idempotencyKey,
      ],
      version: table.version + 1,
      updatedAt: now,
    );
  }

  /// Asignación de créditos iniciales adicionales o ajuste administrativo auditable.
  static GameTable applyAdminCreditAdjustment({
    required GameTable table,
    required String adminUserId,
    required String targetPlayerId,
    required int deltaCents,
    required String reason,
    required bool isInitialCreditAllocation,
    required String idempotencyKey,
  }) {
    if (!table.isUserAdmin(adminUserId)) {
      throw const BankOperationException(
        'permission-denied',
        'Solo el administrador autorizado del banco puede emitir o ajustar créditos.',
      );
    }
    if (deltaCents == 0) {
      throw const BankOperationException(
        'invalid-amount',
        'El importe del ajuste no puede ser \$0.00.',
      );
    }
    if (reason.trim().isEmpty) {
      throw const BankOperationException(
        'missing-reason',
        'Todo ajuste o emisión del banco requiere un motivo auditable.',
      );
    }
    if (table.processedIdempotencyKeys.contains(idempotencyKey)) {
      throw const BankOperationException(
        'duplicate-operation',
        'Esta operación de ajuste ya fue registrada.',
      );
    }

    final player = table.participants[targetPlayerId];
    if (player == null) {
      throw const BankOperationException(
        'not-found',
        'El jugador seleccionado no existe en la mesa.',
      );
    }

    final newAvailable = player.availableBalanceCents + deltaCents;
    if (newAvailable < 0) {
      throw BankOperationException(
        'insufficient-funds',
        'Operación bloqueada: el ajuste dejaría a ${player.displayName} con saldo negativo.',
      );
    }

    final now = DateTime.now().toUtc();
    final updatedParticipants =
        Map<String, PlayerAccount>.from(table.participants);

    if (isInitialCreditAllocation && deltaCents > 0) {
      updatedParticipants[targetPlayerId] = player.copyWith(
        availableBalanceCents: newAvailable,
        initialCreditsCents: player.initialCreditsCents + deltaCents,
        lastUpdatedAt: now,
      );
    } else {
      updatedParticipants[targetPlayerId] = player.copyWith(
        availableBalanceCents: newAvailable,
        adminAdjustmentsCents: player.adminAdjustmentsCents + deltaCents,
        lastUpdatedAt: now,
      );
    }

    final entry = LedgerEntry(
      entryId: 'tx_adj_${now.millisecondsSinceEpoch}_${targetPlayerId.hashCode.abs()}',
      idempotencyKey: idempotencyKey,
      tableId: table.tableId,
      type: isInitialCreditAllocation && deltaCents > 0
          ? LedgerMovementType.initialAllocation
          : LedgerMovementType.adminAdjustment,
      fromAccountId: deltaCents > 0 ? 'BANK' : player.playerId,
      fromAccountName: deltaCents > 0 ? 'Banco Virtual' : player.displayName,
      toAccountId: deltaCents > 0 ? player.playerId : 'BANK',
      toAccountName: deltaCents > 0 ? player.displayName : 'Banco Virtual',
      amountCents: deltaCents.abs(),
      createdAt: now,
      status: LedgerMovementStatus.completed,
      reason: reason.trim(),
      authorizedByUserId: adminUserId,
      authorizedByUserName: table.adminDisplayName,
    );

    return table.copyWith(
      participants: updatedParticipants,
      ledgerEntries: [entry, ...table.ledgerEntries],
      processedIdempotencyKeys: [
        ...table.processedIdempotencyKeys,
        idempotencyKey,
      ],
      version: table.version + 1,
      updatedAt: now,
    );
  }

  /// Transferencia atómica de créditos internos entre dos jugadores.
  static GameTable applyInternalTransfer({
    required GameTable table,
    required String callerUserId,
    required String fromPlayerId,
    required String toPlayerId,
    required int amountCents,
    required String reason,
    required String idempotencyKey,
  }) {
    // Seguridad (Sección 6):
    // Impedir modificar directamente el saldo de otro usuario.
    // Solo el propio titular de la cuenta de origen (o el administrador ejecutando orden autorizada)
    // puede transferir desde su cuenta.
    if (callerUserId != fromPlayerId && !table.isUserAdmin(callerUserId)) {
      throw const BankOperationException(
        'permission-denied',
        'No tienes permiso para transferir créditos desde la cuenta de otro jugador.',
      );
    }
    if (fromPlayerId == toPlayerId) {
      throw const BankOperationException(
        'invalid-transfer',
        'La cuenta de origen y destino no pueden ser la misma.',
      );
    }
    if (amountCents <= 0) {
      throw const BankOperationException(
        'invalid-amount',
        'El importe a transferir debe ser mayor a \$0.00.',
      );
    }
    if (table.processedIdempotencyKeys.contains(idempotencyKey)) {
      throw const BankOperationException(
        'duplicate-operation',
        'Esta transferencia ya fue procesada (protección contra duplicados).',
      );
    }

    final sender = table.participants[fromPlayerId];
    final receiver = table.participants[toPlayerId];
    if (sender == null || receiver == null) {
      throw const BankOperationException(
        'account-not-found',
        'Ambas cuentas deben pertenecer a participantes activos de la mesa.',
      );
    }

    // Bloquear operaciones que excedan los créditos disponibles
    if (sender.availableBalanceCents < amountCents) {
      throw BankOperationException(
        'insufficient-funds',
        'Saldo insuficiente: ${sender.displayName} dispone de ${(sender.availableBalanceCents / 100).toStringAsFixed(2)} y se requieren ${(amountCents / 100).toStringAsFixed(2)}.',
      );
    }

    final now = DateTime.now().toUtc();
    final callerName =
        table.participants[callerUserId]?.displayName ?? table.adminDisplayName;

    // Si existen deudas pendientes entre estos dos jugadores, descontarlas también
    int updatedSenderPendingDebt = sender.pendingDebtsCents;
    int updatedReceiverPendingPrize = receiver.pendingPrizesCents;
    if (updatedSenderPendingDebt > 0 && updatedReceiverPendingPrize > 0) {
      final debtReduction = min(
        amountCents,
        min(updatedSenderPendingDebt, updatedReceiverPendingPrize),
      );
      updatedSenderPendingDebt -= debtReduction;
      updatedReceiverPendingPrize -= debtReduction;
    }

    final updatedParticipants =
        Map<String, PlayerAccount>.from(table.participants);
    updatedParticipants[fromPlayerId] = sender.copyWith(
      availableBalanceCents: sender.availableBalanceCents - amountCents,
      pendingDebtsCents: updatedSenderPendingDebt,
      lastUpdatedAt: now,
    );
    updatedParticipants[toPlayerId] = receiver.copyWith(
      availableBalanceCents: receiver.availableBalanceCents + amountCents,
      pendingPrizesCents: updatedReceiverPendingPrize,
      lastUpdatedAt: now,
    );

    final entry = LedgerEntry(
      entryId: 'tx_tr_${now.millisecondsSinceEpoch}_${idempotencyKey.hashCode.abs()}',
      idempotencyKey: idempotencyKey,
      tableId: table.tableId,
      roundId: table.currentRound?.roundId,
      roundNumber: table.currentRound?.roundNumber,
      type: LedgerMovementType.directPeerTransfer,
      fromAccountId: sender.playerId,
      fromAccountName: sender.displayName,
      toAccountId: receiver.playerId,
      toAccountName: receiver.displayName,
      amountCents: amountCents,
      createdAt: now,
      status: LedgerMovementStatus.completed,
      reason: reason.trim().isEmpty
          ? 'Transferencia interna de créditos'
          : reason.trim(),
      authorizedByUserId: callerUserId,
      authorizedByUserName: callerName,
    );

    return table.copyWith(
      participants: updatedParticipants,
      ledgerEntries: [entry, ...table.ledgerEntries],
      processedIdempotencyKeys: [
        ...table.processedIdempotencyKeys,
        idempotencyKey,
      ],
      version: table.version + 1,
      updatedAt: now,
    );
  }

  /// Inicia o prepara la siguiente partida sin borrar el historial anterior.
  static GameTable applyStartNextRound({
    required GameTable table,
    required String callerUserId,
  }) {
    if (table.status == TableStatus.closed) {
      throw const BankOperationException(
        'table-closed',
        'La sesión de la mesa está cerrada.',
      );
    }
    if (table.participants.length < table.minPlayers) {
      throw BankOperationException(
        'not-enough-players',
        'Se necesitan al menos ${table.minPlayers} jugadores en la mesa para iniciar una partida.',
      );
    }
    if (table.currentRound != null && !table.currentRound!.isClosed) {
      throw const BankOperationException(
        'round-already-active',
        'Ya existe una partida en curso. Debe cerrarse antes de iniciar la siguiente.',
      );
    }

    final now = DateTime.now().toUtc();
    final nextNumber = table.completedRounds.length + 1;
    final roundId = 'rnd_${table.tableId}_$nextNumber';

    final initialInputs = <String, PlayerRoundInput>{};
    for (final p in table.sortedParticipants) {
      initialInputs[p.playerId] = PlayerRoundInput(
        playerId: p.playerId,
        displayName: p.displayName,
      );
    }

    final newRound = GameRound(
      roundId: roundId,
      roundNumber: nextNumber,
      tableId: table.tableId,
      status: RoundStatus.collectingPrizes,
      tariffSnapshot: table.currentTariffs.freezeCopy(),
      playerInputs: initialInputs,
      createdAt: now,
    );

    return table.copyWith(
      status: TableStatus.inProgress,
      currentRound: newRound,
      version: table.version + 1,
      updatedAt: now,
    );
  }

  /// Registra o actualiza los premios de un jugador en la partida actual.
  static GameTable applyUpdatePlayerRoundPrizes({
    required GameTable table,
    required String callerUserId,
    required PlayerRoundInput input,
  }) {
    final currentRound = table.currentRound;
    if (currentRound == null) {
      throw const BankOperationException(
        'no-active-round',
        'No hay una partida activa en este momento.',
      );
    }
    if (currentRound.status != RoundStatus.collectingPrizes) {
      throw const BankOperationException(
        'round-locked',
        'Los premios de la partida ya fueron calculados. Reabra la edición si necesita corregirlos antes de liquidar.',
      );
    }

    // Seguridad: Un jugador solo puede editar sus propios premios, salvo que sea el administrador.
    if (callerUserId != input.playerId && !table.isUserAdmin(callerUserId)) {
      throw const BankOperationException(
        'permission-denied',
        'Solo puedes registrar tus propios premios o solicitar al administrador de la mesa.',
      );
    }
    if (!table.participants.containsKey(input.playerId)) {
      throw const BankOperationException(
        'not-participant',
        'El jugador no pertenece a la mesa.',
      );
    }
    if (input.acesCount < 0 ||
        input.kingsCount < 0 ||
        input.rusosCount < 0 ||
        input.patasCount < 0) {
      throw const BankOperationException(
        'invalid-prizes',
        'Las cantidades de cartas premiadas no pueden ser negativas.',
      );
    }

    final updatedInputs =
        Map<String, PlayerRoundInput>.from(currentRound.playerInputs);

    // Si este jugador se marca como ganador de la mesa, desmarcar automáticamente a los demás
    // para mantener la regla de un único ganador por partida.
    if (input.isWinner) {
      for (final entry in updatedInputs.entries) {
        if (entry.key != input.playerId && entry.value.isWinner) {
          updatedInputs[entry.key] = entry.value.copyWith(isWinner: false);
        }
      }
    }

    updatedInputs[input.playerId] = input.copyWith(
      displayName:
          table.participants[input.playerId]?.displayName ?? input.displayName,
    );

    final now = DateTime.now().toUtc();
    return table.copyWith(
      currentRound: currentRound.copyWith(playerInputs: updatedInputs),
      version: table.version + 1,
      updatedAt: now,
    );
  }

  /// Calcula determinísticamente los premios brutos, obligaciones, compensaciones y plan de liquidación.
  static GameTable applyCalculateCurrentRound({
    required GameTable table,
    required String callerUserId,
  }) {
    final currentRound = table.currentRound;
    if (currentRound == null) {
      throw const BankOperationException(
        'no-active-round',
        'No hay ninguna partida activa para calcular.',
      );
    }
    if (!table.participants.containsKey(callerUserId)) {
      throw const BankOperationException(
        'permission-denied',
        'Solo los participantes de la mesa pueden calcular la partida.',
      );
    }

    final orderedInputs = <PlayerRoundInput>[];
    for (final p in table.sortedParticipants) {
      final input = currentRound.playerInputs[p.playerId] ??
          PlayerRoundInput(playerId: p.playerId, displayName: p.displayName);
      orderedInputs.add(input);
    }

    try {
      final now = DateTime.now().toUtc();
      final calcResult = SettlementEngine.calculateRound(
        roundId: currentRound.roundId,
        roundNumber: currentRound.roundNumber,
        tariffs: currentRound.tariffSnapshot,
        inputs: orderedInputs,
        timestamp: now,
      );

      final updatedRound = currentRound.copyWith(
        status: RoundStatus.awaitingConfirmation,
        calculationResult: calcResult,
        confirmedByPlayerIds: [callerUserId],
      );

      return table.copyWith(
        status: TableStatus.settlingRound,
        currentRound: updatedRound,
        version: table.version + 1,
        updatedAt: now,
      );
    } on RoundValidationException catch (e) {
      throw BankOperationException('validation-error', e.toString());
    }
  }

  /// Permite reabrir la captura de premios si aún no se ha ejecutado la liquidación.
  static GameTable applyReopenCurrentRoundForEditing({
    required GameTable table,
    required String adminUserId,
  }) {
    if (!table.isUserAdmin(adminUserId)) {
      throw const BankOperationException(
        'permission-denied',
        'Solo el administrador puede reabrir la edición de premios.',
      );
    }
    final currentRound = table.currentRound;
    if (currentRound == null ||
        currentRound.status != RoundStatus.awaitingConfirmation) {
      throw const BankOperationException(
        'invalid-state',
        'La partida no puede reabrirse porque ya fue liquidada o está en edición.',
      );
    }

    final now = DateTime.now().toUtc();
    return table.copyWith(
      status: TableStatus.inProgress,
      currentRound: currentRound.copyWith(
        status: RoundStatus.collectingPrizes,
        confirmedByPlayerIds: const [],
      ),
      version: table.version + 1,
      updatedAt: now,
    );
  }

  /// Registra la confirmación de conformidad de un participante con el cálculo de la ronda.
  static GameTable applyConfirmRoundResultByPlayer({
    required GameTable table,
    required String playerId,
  }) {
    final currentRound = table.currentRound;
    if (currentRound == null ||
        currentRound.status != RoundStatus.awaitingConfirmation) {
      throw const BankOperationException(
        'invalid-state',
        'No hay un cálculo pendiente de confirmación.',
      );
    }
    if (!table.participants.containsKey(playerId)) {
      throw const BankOperationException(
        'not-participant',
        'El usuario no pertenece a la mesa.',
      );
    }

    if (currentRound.confirmedByPlayerIds.contains(playerId)) {
      return table;
    }

    final now = DateTime.now().toUtc();
    final updatedConfirmations = [
      ...currentRound.confirmedByPlayerIds,
      playerId,
    ];

    return table.copyWith(
      currentRound:
          currentRound.copyWith(confirmedByPlayerIds: updatedConfirmations),
      version: table.version + 1,
      updatedAt: now,
    );
  }

  /// Ejecuta el cierre y liquidación atómica de la partida (Secciones 6, 7 y 8).
  ///
  /// - Genera todos los movimientos como una única operación lógica con `settlementId = stl_<roundId>`.
  /// - Impide ejecutar liquidaciones duplicadas o descontar dos veces la misma deuda.
  /// - Actualiza ganancias y pérdidas acumuladas una sola vez.
  /// - Bloquea sobregiros: si algún deudor no tiene créditos suficientes, exige recarga
  ///   o registro explícito de deuda pendiente verificable (`allowPendingIfInsufficient`).
  /// - Al cerrarse la partida, prepara automáticamente la siguiente partida sin borrar el historial.
  static GameTable applyExecuteRoundSettlement({
    required GameTable table,
    required String adminUserId,
    required String roundId,
    required bool allowPendingIfInsufficient,
  }) {
    if (!table.isUserAdmin(adminUserId)) {
      throw const BankOperationException(
        'permission-denied',
        'Solo el administrador de la mesa puede ejecutar la liquidación de la partida.',
      );
    }

    final settlementId = 'stl_$roundId';
    if (table.processedIdempotencyKeys.contains(settlementId)) {
      throw const BankOperationException(
        'duplicate-settlement',
        'Esta partida ya fue liquidada anteriormente (protección contra liquidación duplicada).',
      );
    }

    final currentRound = table.currentRound;
    if (currentRound == null || currentRound.roundId != roundId) {
      throw const BankOperationException(
        'round-mismatch',
        'La partida solicitada no coincide con la ronda activa.',
      );
    }

    // Recalcular en servidor/transacción para garantizar integridad total
    final orderedInputs = <PlayerRoundInput>[];
    for (final p in table.sortedParticipants) {
      orderedInputs.add(
        currentRound.playerInputs[p.playerId] ??
            PlayerRoundInput(playerId: p.playerId, displayName: p.displayName),
      );
    }

    final now = DateTime.now().toUtc();
    final calcResult = SettlementEngine.calculateRound(
      roundId: currentRound.roundId,
      roundNumber: currentRound.roundNumber,
      tariffs: currentRound.tariffSnapshot,
      inputs: orderedInputs,
      timestamp: now,
    );

    final updatedParticipants =
        Map<String, PlayerAccount>.from(table.participants);

    // Verificar solvencia de todos los deudores en créditos internos
    final insolventPlayers = <String>[];
    for (final entry in calcResult.netBalancesByPlayerCents.entries) {
      if (entry.value < 0) {
        final requiredCents = -entry.value;
        final account = updatedParticipants[entry.key];
        if (account == null || account.availableBalanceCents < requiredCents) {
          final deficit =
              requiredCents - (account?.availableBalanceCents ?? 0);
          insolventPlayers.add(
            '${account?.displayName ?? entry.key} (faltan \$${(deficit / 100).toStringAsFixed(2)})',
          );
        }
      }
    }

    if (insolventPlayers.isNotEmpty && !allowPendingIfInsufficient) {
      throw BankOperationException(
        'insufficient-credits-for-settlement',
        'Créditos internos insuficientes para liquidar automáticamente: ${insolventPlayers.join(", ")}. '
            'Apruebe una recarga en el Banco Virtual o elija «Liquidar dejando saldo pendiente de cobro».',
      );
    }

    // Actualizar Ganancias Acumuladas y Pérdidas Acumuladas de la sesión UNA SOLA VEZ
    if (!currentRound.sessionPnlAccounted) {
      for (final input in orderedInputs) {
        final account = updatedParticipants[input.playerId]!;
        final netCents = calcResult.netBalancesByPlayerCents[input.playerId] ?? 0;

        updatedParticipants[input.playerId] = account.copyWith(
          accumulatedWinningsCents: netCents > 0
              ? account.accumulatedWinningsCents + netCents
              : account.accumulatedWinningsCents,
          accumulatedLossesCents: netCents < 0
              ? account.accumulatedLossesCents + (-netCents)
              : account.accumulatedLossesCents,
          roundsWon: input.isWinner ? account.roundsWon + 1 : account.roundsWon,
          lastUpdatedAt: now,
        );
      }
    }

    final updatedLedger = List<LedgerEntry>.from(table.ledgerEntries);
    final updatedPlan = <SettlementTransferItem>[];

    for (final item in calcResult.optimizedSettlementPlan) {
      final debtor = updatedParticipants[item.fromPlayerId]!;
      final creditor = updatedParticipants[item.toPlayerId]!;

      if (debtor.availableBalanceCents >= item.amountCents) {
        final txId = 'tx_${roundId}_${item.index}';
        updatedParticipants[debtor.playerId] = debtor.copyWith(
          availableBalanceCents:
              debtor.availableBalanceCents - item.amountCents,
          lastUpdatedAt: now,
        );
        updatedParticipants[creditor.playerId] = creditor.copyWith(
          availableBalanceCents:
              creditor.availableBalanceCents + item.amountCents,
          lastUpdatedAt: now,
        );

        updatedLedger.insert(
          0,
          LedgerEntry(
            entryId: txId,
            idempotencyKey: '${settlementId}_${item.index}',
            tableId: table.tableId,
            roundId: roundId,
            roundNumber: currentRound.roundNumber,
            type: LedgerMovementType.roundSettlementTransfer,
            fromAccountId: debtor.playerId,
            fromAccountName: debtor.displayName,
            toAccountId: creditor.playerId,
            toAccountName: creditor.displayName,
            amountCents: item.amountCents,
            createdAt: now,
            status: LedgerMovementStatus.completed,
            reason:
                'Liquidación automática Partida #${currentRound.roundNumber}',
            authorizedByUserId: adminUserId,
            authorizedByUserName: table.adminDisplayName,
            calculationReferenceId: calcResult.calculationId,
          ),
        );

        updatedPlan.add(
          item.copyWith(
            status: SettlementTransferStatus.settledInternalCredits,
            ledgerTransactionId: txId,
            settledAt: now,
          ),
        );
      } else {
        // Deuda pendiente de pago y premio pendiente de cobro (sin permitir saldo disponible negativo)
        updatedParticipants[debtor.playerId] = debtor.copyWith(
          pendingDebtsCents: debtor.pendingDebtsCents + item.amountCents,
          lastUpdatedAt: now,
        );
        updatedParticipants[creditor.playerId] = creditor.copyWith(
          pendingPrizesCents: creditor.pendingPrizesCents + item.amountCents,
          lastUpdatedAt: now,
        );

        updatedPlan.add(
          item.copyWith(status: SettlementTransferStatus.pending),
        );
      }
    }

    final finalCalcResult =
        calcResult.copyWith(optimizedSettlementPlan: updatedPlan);
    final hasPendingItems = updatedPlan.any((i) => !i.isSettled);

    final settledRound = currentRound.copyWith(
      status: hasPendingItems
          ? RoundStatus.partiallySettledPending
          : RoundStatus.closed,
      calculationResult: finalCalcResult,
      settlementId: settlementId,
      sessionPnlAccounted: true,
      closedAt: hasPendingItems ? null : now,
    );

    final updatedKeys = [
      ...table.processedIdempotencyKeys,
      settlementId,
    ];

    // Si todos los pagos quedaron cubiertos, cerramos la partida, la guardamos en el historial
    // y preparamos inmediatamente la siguiente partida sin borrar el historial.
    if (!hasPendingItems) {
      final updatedCompletedRounds = [
        settledRound,
        ...table.completedRounds,
      ];

      final nextRoundNumber = updatedCompletedRounds.length + 1;
      final nextRoundId = 'rnd_${table.tableId}_$nextRoundNumber';
      final nextInputs = <String, PlayerRoundInput>{};
      for (final p in updatedParticipants.values) {
        nextInputs[p.playerId] = PlayerRoundInput(
          playerId: p.playerId,
          displayName: p.displayName,
        );
      }

      final nextRound = GameRound(
        roundId: nextRoundId,
        roundNumber: nextRoundNumber,
        tableId: table.tableId,
        status: RoundStatus.collectingPrizes,
        tariffSnapshot: table.currentTariffs.freezeCopy(),
        playerInputs: nextInputs,
        createdAt: now,
      );

      return table.copyWith(
        status: TableStatus.inProgress,
        participants: updatedParticipants,
        currentRound: nextRound,
        completedRounds: updatedCompletedRounds,
        ledgerEntries: updatedLedger,
        processedIdempotencyKeys: updatedKeys,
        version: table.version + 1,
        updatedAt: now,
      );
    } else {
      return table.copyWith(
        status: TableStatus.settlingRound,
        participants: updatedParticipants,
        currentRound: settledRound,
        ledgerEntries: updatedLedger,
        processedIdempotencyKeys: updatedKeys,
        version: table.version + 1,
        updatedAt: now,
      );
    }
  }

  /// Liquida una transferencia que había quedado pendiente en una partida, ya sea:
  /// - Con créditos internos (tras haber aprobado una recarga al deudor), o
  /// - Verificando explícitamente que el pago externo fue recibido.
  static GameTable applySettlePendingRoundTransfer({
    required GameTable table,
    required String adminUserId,
    required String roundId,
    required String transferItemId,
    required bool useInternalCredits,
    required String verificationNote,
    required String idempotencyKey,
  }) {
    if (!table.isUserAdmin(adminUserId)) {
      throw const BankOperationException(
        'permission-denied',
        'Solo el administrador puede verificar o ejecutar pagos pendientes de liquidación.',
      );
    }
    if (table.processedIdempotencyKeys.contains(idempotencyKey)) {
      throw const BankOperationException(
        'duplicate-operation',
        'Este pago pendiente ya fue liquidado anteriormente.',
      );
    }

    final currentRound = table.currentRound;
    if (currentRound == null ||
        currentRound.roundId != roundId ||
        currentRound.calculationResult == null) {
      throw const BankOperationException(
        'round-not-found',
        'No se encontró la partida con pagos pendientes.',
      );
    }

    final plan = List<SettlementTransferItem>.from(
      currentRound.calculationResult!.optimizedSettlementPlan,
    );
    final idx = plan.indexWhere((i) => i.itemId == transferItemId);
    if (idx == -1) {
      throw const BankOperationException(
        'item-not-found',
        'No existe la obligación pendiente indicada.',
      );
    }

    final item = plan[idx];
    if (item.isSettled) {
      throw const BankOperationException(
        'already-settled',
        'Esta deuda ya fue saldada anteriormente (protección contra doble cobro).',
      );
    }

    final updatedParticipants =
        Map<String, PlayerAccount>.from(table.participants);
    final debtor = updatedParticipants[item.fromPlayerId]!;
    final creditor = updatedParticipants[item.toPlayerId]!;
    final now = DateTime.now().toUtc();

    if (useInternalCredits && debtor.availableBalanceCents < item.amountCents) {
      throw BankOperationException(
        'insufficient-funds',
        '${debtor.displayName} aún no tiene créditos internos suficientes (\$${(debtor.availableBalanceCents / 100).toStringAsFixed(2)}) para cubrir \$${(item.amountCents / 100).toStringAsFixed(2)}.',
      );
    }

    final txId = 'tx_pnd_${roundId}_${item.index}';

    updatedParticipants[debtor.playerId] = debtor.copyWith(
      availableBalanceCents: useInternalCredits
          ? debtor.availableBalanceCents - item.amountCents
          : debtor.availableBalanceCents,
      pendingDebtsCents: max(0, debtor.pendingDebtsCents - item.amountCents),
      lastUpdatedAt: now,
    );

    updatedParticipants[creditor.playerId] = creditor.copyWith(
      availableBalanceCents: useInternalCredits
          ? creditor.availableBalanceCents + item.amountCents
          : creditor.availableBalanceCents,
      pendingPrizesCents:
          max(0, creditor.pendingPrizesCents - item.amountCents),
      lastUpdatedAt: now,
    );

    final ledgerEntry = LedgerEntry(
      entryId: txId,
      idempotencyKey: idempotencyKey,
      tableId: table.tableId,
      roundId: roundId,
      roundNumber: currentRound.roundNumber,
      type: useInternalCredits
          ? LedgerMovementType.roundSettlementTransfer
          : LedgerMovementType.externalPaymentVerified,
      fromAccountId: debtor.playerId,
      fromAccountName: debtor.displayName,
      toAccountId: creditor.playerId,
      toAccountName: creditor.displayName,
      amountCents: item.amountCents,
      createdAt: now,
      status: LedgerMovementStatus.completed,
      reason: verificationNote.trim().isEmpty
          ? (useInternalCredits
              ? 'Pago de deuda pendiente con créditos internos (Partida #${currentRound.roundNumber})'
              : 'Pago externo verificado (Partida #${currentRound.roundNumber})')
          : verificationNote.trim(),
      authorizedByUserId: adminUserId,
      authorizedByUserName: table.adminDisplayName,
      calculationReferenceId: currentRound.calculationResult!.calculationId,
    );

    plan[idx] = item.copyWith(
      status: useInternalCredits
          ? SettlementTransferStatus.settledInternalCredits
          : SettlementTransferStatus.settledVerifiedExternal,
      ledgerTransactionId: txId,
      settledAt: now,
    );

    final allSettled = plan.every((i) => i.isSettled);
    final updatedCalc = currentRound.calculationResult!
        .copyWith(optimizedSettlementPlan: plan);

    final updatedRound = currentRound.copyWith(
      status:
          allSettled ? RoundStatus.closed : RoundStatus.partiallySettledPending,
      calculationResult: updatedCalc,
      closedAt: allSettled ? now : null,
    );

    final updatedLedger = [ledgerEntry, ...table.ledgerEntries];
    final updatedKeys = [...table.processedIdempotencyKeys, idempotencyKey];

    if (allSettled) {
      final updatedCompleted = [updatedRound, ...table.completedRounds];
      final nextNumber = updatedCompleted.length + 1;
      final nextInputs = <String, PlayerRoundInput>{
        for (final p in updatedParticipants.values)
          p.playerId: PlayerRoundInput(
            playerId: p.playerId,
            displayName: p.displayName,
          ),
      };
      final nextRound = GameRound(
        roundId: 'rnd_${table.tableId}_$nextNumber',
        roundNumber: nextNumber,
        tableId: table.tableId,
        status: RoundStatus.collectingPrizes,
        tariffSnapshot: table.currentTariffs.freezeCopy(),
        playerInputs: nextInputs,
        createdAt: now,
      );

      return table.copyWith(
        status: TableStatus.inProgress,
        participants: updatedParticipants,
        currentRound: nextRound,
        completedRounds: updatedCompleted,
        ledgerEntries: updatedLedger,
        processedIdempotencyKeys: updatedKeys,
        version: table.version + 1,
        updatedAt: now,
      );
    }

    return table.copyWith(
      participants: updatedParticipants,
      currentRound: updatedRound,
      ledgerEntries: updatedLedger,
      processedIdempotencyKeys: updatedKeys,
      version: table.version + 1,
      updatedAt: now,
    );
  }

  /// Cierra definitivamente la mesa cuando no existan operaciones pendientes.
  static GameTable applyCloseTableSession({
    required GameTable table,
    required String adminUserId,
  }) {
    if (!table.isUserAdmin(adminUserId)) {
      throw const BankOperationException(
        'permission-denied',
        'Solo el administrador puede cerrar la mesa.',
      );
    }
    final hasAnyPendingDebt =
        table.participants.values.any((p) => p.hasPendingDebts);
    if (hasAnyPendingDebt) {
      throw const BankOperationException(
        'pending-debts-exist',
        'No se puede cerrar la mesa mientras existan deudas o pagos pendientes de verificar.',
      );
    }

    final now = DateTime.now().toUtc();
    return table.copyWith(
      status: TableStatus.closed,
      clearCurrentRound: true,
      version: table.version + 1,
      updatedAt: now,
      closedAt: now,
    );
  }
}
