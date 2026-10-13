import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/game_table.dart';
import '../models/round_models.dart';
import '../models/tariff_config.dart';
import 'backend_repository.dart';

/// Repositorio transaccional persistente con sincronización reactiva y recuperación
/// automática de estado tras cerrar o reiniciar el teléfono.
///
/// Utiliza exactamente el mismo `TransactionalTableProcessor` que `FirebaseGameRepository`,
/// permitiendo ejecutar y verificar la aplicación inmediatamente en cualquier teléfono
/// incluso antes de configurar un proyecto en Firebase Console.
class LocalSyncedGameRepository implements GameBackendRepository {
  static const String _sessionKey = 'me_voy_local_user_session_v1';
  static const String _activeTableIdKey = 'me_voy_local_active_table_id_v1';
  static const String _tablesStoreKey = 'me_voy_local_tables_store_v1';

  final Uuid _uuid = const Uuid();
  final Map<String, GameTable> _tablesById = {};
  final Map<String, StreamController<GameTable?>> _tableStreams = {};
  bool _initialized = false;

  @override
  bool get isUsingCloudFirebase => false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_tablesStoreKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final tableMap = Map<String, dynamic>.from(entry.value as Map);
          _tablesById[entry.key] = GameTable.fromMap(tableMap);
        }
      } catch (_) {
        // Si hubiera datos corruptos previos, se reinicia limpio
      }
    }
    _initialized = true;
  }

  Future<void> _persistTables() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = <String, dynamic>{
      for (final entry in _tablesById.entries) entry.key: entry.value.toMap(),
    };
    await prefs.setString(_tablesStoreKey, jsonEncode(serialized));
  }

  void _emitTableUpdate(String tableId) {
    final controller = _tableStreams[tableId];
    if (controller != null && !controller.isClosed) {
      controller.add(_tablesById[tableId]);
    }
  }

  @override
  Future<AppUserSession?> restoreSession() async {
    await _ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppUserSession.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<AppUserSession> _saveSession(AppUserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toMap()));
    return session;
  }

  @override
  Future<AppUserSession> signInWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await _ensureInitialized();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const BankOperationException(
        'invalid-email',
        'Ingrese un correo electrónico válido.',
      );
    }
    if (password.length < 4) {
      throw const BankOperationException(
        'weak-password',
        'La contraseña debe tener al menos 4 caracteres.',
      );
    }
    final uid = 'usr_${cleanEmail.hashCode.abs()}';
    final name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : cleanEmail.split('@').first;

    return _saveSession(
      AppUserSession(
        userId: uid,
        displayName: name,
        email: cleanEmail,
        isFirebaseAccount: false,
      ),
    );
  }

  @override
  Future<AppUserSession> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (displayName.trim().isEmpty) {
      throw const BankOperationException(
        'missing-name',
        'Ingrese su nombre de jugador.',
      );
    }
    return signInWithEmail(
      email: email,
      password: password,
      displayName: displayName.trim(),
    );
  }

  @override
  Future<AppUserSession> signInQuickProfile({
    required String displayName,
    required String email,
  }) async {
    await _ensureInitialized();
    final cleanName = displayName.trim();
    if (cleanName.isEmpty) {
      throw const BankOperationException(
        'missing-name',
        'Ingrese su nombre o alias de jugador.',
      );
    }
    final cleanEmail = email.trim().isEmpty
        ? '${cleanName.toLowerCase().replaceAll(' ', '.')}@mevoy.app'
        : email.trim().toLowerCase();
    final uid = 'usr_${cleanEmail.hashCode.abs()}';

    return _saveSession(
      AppUserSession(
        userId: uid,
        displayName: cleanName,
        email: cleanEmail,
        isFirebaseAccount: false,
      ),
    );
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  @override
  Future<String?> getSavedActiveTableId() async {
    await _ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeTableIdKey);
  }

  @override
  Future<void> saveActiveTableId(String? tableId) async {
    final prefs = await SharedPreferences.getInstance();
    if (tableId == null || tableId.isEmpty) {
      await prefs.remove(_activeTableIdKey);
    } else {
      await prefs.setString(_activeTableIdKey, tableId);
    }
  }

  @override
  Future<GameTable> createTable({
    required AppUserSession adminUser,
    required String tableName,
    required int initialCreditsCents,
    TariffConfig? customTariffs,
    bool autoCreateDemoPlayers = false,
  }) async {
    await _ensureInitialized();
    final tableId = 'tbl_${_uuid.v4().substring(0, 8)}';
    String inviteCode = TransactionalTableProcessor.generateInviteCode();
    while (_tablesById.values.any((t) => t.inviteCode == inviteCode)) {
      inviteCode = TransactionalTableProcessor.generateInviteCode();
    }

    final table = TransactionalTableProcessor.buildNewTable(
      tableId: tableId,
      inviteCode: inviteCode,
      adminUser: adminUser,
      tableName: tableName,
      initialCreditsCents: initialCreditsCents,
      customTariffs: customTariffs,
      autoCreateDemoPlayers: autoCreateDemoPlayers,
    );

    _tablesById[tableId] = table;
    await _persistTables();
    await saveActiveTableId(tableId);
    _emitTableUpdate(tableId);
    return table;
  }

  @override
  Future<GameTable> joinTableByCode({
    required AppUserSession user,
    required String inviteCode,
  }) async {
    await _ensureInitialized();
    final normalized = inviteCode.trim().toUpperCase();
    final matching =
        _tablesById.values.where((t) => t.inviteCode == normalized).toList();

    if (matching.isEmpty) {
      throw BankOperationException(
        'invalid-code',
        'No se encontró ninguna mesa con el código "$normalized".',
      );
    }

    final current = matching.first;
    final updated = TransactionalTableProcessor.applyAddParticipant(
      table: current,
      playerId: user.userId,
      displayName: user.displayName,
      email: user.email,
      initialCreditsCents: current.defaultInitialCreditsCents,
      authorizedByUserId: current.adminUserId,
      authorizedByUserName: current.adminDisplayName,
    );

    _tablesById[updated.tableId] = updated;
    await _persistTables();
    await saveActiveTableId(updated.tableId);
    _emitTableUpdate(updated.tableId);
    return updated;
  }

  @override
  Future<GameTable?> getTableById(String tableId) async {
    await _ensureInitialized();
    return _tablesById[tableId];
  }

  @override
  Stream<GameTable?> watchTable(String tableId) {
    final controller = _tableStreams.putIfAbsent(
      tableId,
      () => StreamController<GameTable?>.broadcast(),
    );

    // Emitir el estado actual de inmediato al suscribirse
    Future.microtask(() async {
      await _ensureInitialized();
      if (!controller.isClosed) {
        controller.add(_tablesById[tableId]);
      }
    });

    return controller.stream;
  }

  Future<GameTable> _mutateTableAtomically(
    String tableId,
    GameTable Function(GameTable current) mutator,
  ) async {
    await _ensureInitialized();
    final current = _tablesById[tableId];
    if (current == null) {
      throw const BankOperationException(
        'table-not-found',
        'La mesa solicitada no existe.',
      );
    }

    final updated = mutator(current);
    _tablesById[tableId] = updated;
    await _persistTables();
    _emitTableUpdate(tableId);
    return updated;
  }

  @override
  Future<GameTable> addParticipantAccountByAdmin({
    required String tableId,
    required String adminUserId,
    required String displayName,
    required String email,
    required int initialCreditsCents,
    String? customPlayerId,
  }) {
    return _mutateTableAtomically(tableId, (table) {
      if (!table.isUserAdmin(adminUserId)) {
        throw const BankOperationException(
          'permission-denied',
          'Solo el administrador del banco puede crear cuentas de jugadores en la mesa.',
        );
      }
      final pid =
          customPlayerId ?? 'plr_${_uuid.v4().substring(0, 6)}';
      return TransactionalTableProcessor.applyAddParticipant(
        table: table,
        playerId: pid,
        displayName: displayName,
        email: email,
        initialCreditsCents: initialCreditsCents,
        authorizedByUserId: adminUserId,
        authorizedByUserName: table.adminDisplayName,
      );
    });
  }

  @override
  Future<GameTable> updateTableTariffs({
    required String tableId,
    required String adminUserId,
    required TariffConfig newTariffs,
  }) {
    return _mutateTableAtomically(
      tableId,
      (table) => TransactionalTableProcessor.applyUpdateTariffs(
        table: table,
        adminUserId: adminUserId,
        newTariffs: newTariffs,
      ),
    );
  }

  @override
  Future<GameTable> requestRecharge({
    required String tableId,
    required String playerId,
    required int amountCents,
    required String note,
    required String idempotencyKey,
  }) {
    return _mutateTableAtomically(
      tableId,
      (table) => TransactionalTableProcessor.applyRequestRecharge(
        table: table,
        playerId: playerId,
        amountCents: amountCents,
        note: note,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  @override
  Future<GameTable> resolveRechargeRequest({
    required String tableId,
    required String adminUserId,
    required String requestId,
    required bool approve,
    required String reason,
  }) {
    return _mutateTableAtomically(
      tableId,
      (table) => TransactionalTableProcessor.applyResolveRecharge(
        table: table,
        adminUserId: adminUserId,
        requestId: requestId,
        approve: approve,
        reason: reason,
      ),
    );
  }

  @override
  Future<GameTable> applyAdminCreditAdjustment({
    required String tableId,
    required String adminUserId,
    required String targetPlayerId,
    required int deltaCents,
    required String reason,
    required bool isInitialCreditAllocation,
    required String idempotencyKey,
  }) {
    return _mutateTableAtomically(
      tableId,
      (table) => TransactionalTableProcessor.applyAdminCreditAdjustment(
        table: table,
        adminUserId: adminUserId,
        targetPlayerId: targetPlayerId,
        deltaCents: deltaCents,
        reason: reason,
        isInitialCreditAllocation: isInitialCreditAllocation,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  @override
  Future<GameTable> executeInternalTransfer({
    required String tableId,
    required String callerUserId,
    required String fromPlayerId,
    required String toPlayerId,
    required int amountCents,
    required String reason,
    required String idempotencyKey,
  }) {
    return _mutateTableAtomically(
      tableId,
      (table) => TransactionalTableProcessor.applyInternalTransfer(
        table: table,
        callerUserId: callerUserId,
        fromPlayerId: fromPlayerId,
        toPlayerId: toPlayerId,
        amountCents: amountCents,
        reason: reason,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  @override
  Future<GameTable> startNextRound({
    required String tableId,
    required String callerUserId,
  }) {
    return _mutateTableAtomically(
      tableId,
      (table) => TransactionalTableProcessor.applyStartNextRound(
        table: table,
        callerUserId: callerUserId,
      ),
    );
  }

  @override
  Future<GameTable> updatePlayerRoundPrizes({
    required String tableId,
    required String callerUserId,
    required PlayerRoundInput input,
  }) {
    return _mutateTableAtomically(
      tableId,
      (table) => TransactionalTableProcessor.applyUpdatePlayerRoundPrizes(
        table: table,
        callerUserId: callerUserId,
        input: input,
      ),
    );
  }

  @override
  Future<GameTable> calculateCurrentRound({
    required String tableId,
    required String callerUserId,
  }) {
    return _mutateTableAtomically(
      tableId,
      (table) => TransactionalTableProcessor.applyCalculateCurrentRound(
        table: table,
        callerUserId: callerUserId,
      ),
    );
  }

  @override
  Future<GameTable> reopenCurrentRoundForEditing({
    required String tableId,
    required String adminUserId,
  }) {
    return _mutateTableAtomically(
      tableId,
      (table) => TransactionalTableProcessor.applyReopenCurrentRoundForEditing(
        table: table,
        adminUserId: adminUserId,
      ),
    );
  }

  @override
  Future<GameTable> confirmRoundResultByPlayer({
    required String tableId,
    required String playerId,
  }) {
    return _mutateTableAtomically(
      tableId,
      (table) => TransactionalTableProcessor.applyConfirmRoundResultByPlayer(
        table: table,
        playerId: playerId,
      ),
    );
  }

  @override
  Future<GameTable> executeRoundSettlement({
    required String tableId,
    required String adminUserId,
    required String roundId,
    required bool allowPendingIfInsufficient,
  }) {
    return _mutateTableAtomically(
      tableId,
      (table) => TransactionalTableProcessor.applyExecuteRoundSettlement(
        table: table,
        adminUserId: adminUserId,
        roundId: roundId,
        allowPendingIfInsufficient: allowPendingIfInsufficient,
      ),
    );
  }

  @override
  Future<GameTable> settlePendingRoundTransfer({
    required String tableId,
    required String adminUserId,
    required String roundId,
    required String transferItemId,
    required bool useInternalCredits,
    required String verificationNote,
    required String idempotencyKey,
  }) {
    return _mutateTableAtomically(
      tableId,
      (table) => TransactionalTableProcessor.applySettlePendingRoundTransfer(
        table: table,
        adminUserId: adminUserId,
        roundId: roundId,
        transferItemId: transferItemId,
        useInternalCredits: useInternalCredits,
        verificationNote: verificationNote,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  @override
  Future<GameTable> closeTableSession({
    required String tableId,
    required String adminUserId,
  }) {
    return _mutateTableAtomically(
      tableId,
      (table) => TransactionalTableProcessor.applyCloseTableSession(
        table: table,
        adminUserId: adminUserId,
      ),
    );
  }
}
