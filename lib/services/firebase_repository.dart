import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/game_table.dart';
import '../models/round_models.dart';
import '../models/tariff_config.dart';
import 'backend_repository.dart';

/// Implementación en tiempo real respaldada por Firebase Authentication y Cloud Firestore
/// mediante transacciones atómicas (`runTransaction`) y suscripciones en vivo (`snapshots()`).
class FirebaseGameRepository implements GameBackendRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  static const String _activeTablePrefKey = 'me_voy_active_table_id';

  FirebaseGameRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  bool get isUsingCloudFirebase => true;

  CollectionReference<Map<String, dynamic>> get _tablesCol =>
      _firestore.collection('tables');

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  @override
  Future<AppUserSession?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final userDoc = await _usersCol.doc(user.uid).get();
    final data = userDoc.data();
    return AppUserSession(
      userId: user.uid,
      displayName: data?['displayName']?.toString() ??
          user.displayName ??
          user.email?.split('@').first ??
          'Jugador',
      email: user.email ?? data?['email']?.toString() ?? '',
      isFirebaseAccount: true,
    );
  }

  @override
  Future<AppUserSession> signInWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      final resolvedName = displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : (user.displayName ?? email.split('@').first);

      await _usersCol.doc(user.uid).set(
        {
          'userId': user.uid,
          'displayName': resolvedName,
          'email': email.trim(),
          'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
        },
        SetOptions(merge: true),
      );

      return AppUserSession(
        userId: user.uid,
        displayName: resolvedName,
        email: email.trim(),
        isFirebaseAccount: true,
      );
    } on FirebaseAuthException catch (e) {
      throw BankOperationException(
        e.code,
        'Error de autenticación en Firebase: ${e.message ?? e.code}',
      );
    }
  }

  @override
  Future<AppUserSession> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(displayName.trim());

      await _usersCol.doc(user.uid).set({
        'userId': user.uid,
        'displayName': displayName.trim(),
        'email': email.trim(),
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });

      return AppUserSession(
        userId: user.uid,
        displayName: displayName.trim(),
        email: email.trim(),
        isFirebaseAccount: true,
      );
    } on FirebaseAuthException catch (e) {
      throw BankOperationException(
        e.code,
        'No se pudo registrar el usuario en Firebase: ${e.message ?? e.code}',
      );
    }
  }

  @override
  Future<AppUserSession> signInQuickProfile({
    required String displayName,
    required String email,
  }) async {
    try {
      final cred = await _auth.signInAnonymously();
      final user = cred.user!;
      await user.updateDisplayName(displayName.trim());

      await _usersCol.doc(user.uid).set(
        {
          'userId': user.uid,
          'displayName': displayName.trim(),
          'email': email.trim(),
          'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
        },
        SetOptions(merge: true),
      );

      return AppUserSession(
        userId: user.uid,
        displayName: displayName.trim(),
        email: email.trim(),
        isFirebaseAccount: true,
      );
    } on FirebaseAuthException catch (e) {
      throw BankOperationException(
        e.code,
        'No se pudo iniciar sesión en Firebase Auth: ${e.message ?? e.code}',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<String?> getSavedActiveTableId() async {
    final prefs = await SharedPreferences.getInstance();
    final localId = prefs.getString(_activeTablePrefKey);
    if (localId != null && localId.isNotEmpty) return localId;

    final user = _auth.currentUser;
    if (user != null) {
      final snap = await _usersCol.doc(user.uid).get();
      return snap.data()?['activeTableId']?.toString();
    }
    return null;
  }

  @override
  Future<void> saveActiveTableId(String? tableId) async {
    final prefs = await SharedPreferences.getInstance();
    if (tableId == null || tableId.isEmpty) {
      await prefs.remove(_activeTablePrefKey);
    } else {
      await prefs.setString(_activeTablePrefKey, tableId);
    }

    final user = _auth.currentUser;
    if (user != null) {
      await _usersCol.doc(user.uid).set(
        {'activeTableId': tableId},
        SetOptions(merge: true),
      );
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
    final tableId = 'tbl_${_uuid.v4().substring(0, 8)}';
    String inviteCode = TransactionalTableProcessor.generateInviteCode();

    // Asegurar unicidad del código de invitación en Firestore
    final existing = await _tablesCol
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
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

    await _tablesCol.doc(tableId).set(table.toMap());
    await saveActiveTableId(tableId);
    return table;
  }

  @override
  Future<GameTable> joinTableByCode({
    required AppUserSession user,
    required String inviteCode,
  }) async {
    final normalizedCode = inviteCode.trim().toUpperCase();
    final query = await _tablesCol
        .where('inviteCode', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw BankOperationException(
        'invalid-code',
        'No existe ninguna mesa activa con el código de invitación "$normalizedCode".',
      );
    }

    final docRef = query.docs.first.reference;
    final updatedTable = await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists || snap.data() == null) {
        throw const BankOperationException(
          'not-found',
          'La mesa ya no se encuentra disponible.',
        );
      }

      final currentTable = GameTable.fromMap(snap.data()!);
      final resultTable = TransactionalTableProcessor.applyAddParticipant(
        table: currentTable,
        playerId: user.userId,
        displayName: user.displayName,
        email: user.email,
        initialCreditsCents: currentTable.defaultInitialCreditsCents,
        authorizedByUserId: currentTable.adminUserId,
        authorizedByUserName: currentTable.adminDisplayName,
      );

      tx.set(docRef, resultTable.toMap());
      return resultTable;
    });

    await saveActiveTableId(updatedTable.tableId);
    return updatedTable;
  }

  @override
  Future<GameTable?> getTableById(String tableId) async {
    final snap = await _tablesCol.doc(tableId).get();
    if (!snap.exists || snap.data() == null) return null;
    return GameTable.fromMap(snap.data()!);
  }

  @override
  Stream<GameTable?> watchTable(String tableId) {
    return _tablesCol.doc(tableId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return GameTable.fromMap(snap.data()!);
    });
  }

  Future<GameTable> _runAtomicTableMutation(
    String tableId,
    GameTable Function(GameTable current) mutator,
  ) {
    final docRef = _tablesCol.doc(tableId);
    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists || snap.data() == null) {
        throw const BankOperationException(
          'table-not-found',
          'La mesa solicitada no existe en el servidor.',
        );
      }
      final current = GameTable.fromMap(snap.data()!);
      final updated = mutator(current);
      tx.set(docRef, updated.toMap());
      return updated;
    });
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
    return _runAtomicTableMutation(tableId, (table) {
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
    return _runAtomicTableMutation(
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
    return _runAtomicTableMutation(
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
    return _runAtomicTableMutation(
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
    return _runAtomicTableMutation(
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
    return _runAtomicTableMutation(
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
    return _runAtomicTableMutation(
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
    return _runAtomicTableMutation(
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
    return _runAtomicTableMutation(
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
    return _runAtomicTableMutation(
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
    return _runAtomicTableMutation(
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
    return _runAtomicTableMutation(
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
    return _runAtomicTableMutation(
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
    return _runAtomicTableMutation(
      tableId,
      (table) => TransactionalTableProcessor.applyCloseTableSession(
        table: table,
        adminUserId: adminUserId,
      ),
    );
  }
}
