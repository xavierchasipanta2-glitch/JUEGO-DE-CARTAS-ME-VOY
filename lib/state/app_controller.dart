import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/game_table.dart';
import '../models/round_models.dart';
import '../models/tariff_config.dart';
import '../services/backend_repository.dart';

/// Controlador central de estado reactivo de la aplicación «Me Voy».
///
/// Gestiona:
/// - Autenticación y recuperación automática de sesión tras cerrar/reiniciar el teléfono.
/// - Suscripción en tiempo real (`Stream<GameTable?>`) a la fuente única de datos de la mesa.
/// - Prevención de envíos duplicados en cliente mediante bloqueo de operación en curso + claves de idempotencia.
/// - Generación de reportes de exportación auditables.
class AppController extends ChangeNotifier {
  final GameBackendRepository repository;
  final Uuid _uuid = const Uuid();

  AppUserSession? _currentUser;
  GameTable? _activeTable;
  StreamSubscription<GameTable?>? _tableSubscription;

  /// En modo local/pruebas, permite cambiar qué jugador de la mesa se está visualizando
  /// en pantalla para verificar la experiencia de los 4 participantes desde un teléfono.
  String? _actingPlayerIdOverride;

  bool _isInitializing = true;
  bool _isBusy = false;
  String? _errorMessage;
  String? _successMessage;

  AppController({required this.repository});

  GameBackendRepository get _repository => repository;

  bool get isInitializing => _isInitializing;
  bool get isBusy => _isBusy;
  bool get isUsingCloudFirebase => _repository.isUsingCloudFirebase;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  AppUserSession? get currentUser => _currentUser;
  GameTable? get activeTable => _activeTable;

  /// Identificador del jugador activo en la vista actual.
  String get effectivePlayerId {
    if (_actingPlayerIdOverride != null &&
        _activeTable != null &&
        _activeTable!.participants.containsKey(_actingPlayerIdOverride)) {
      return _actingPlayerIdOverride!;
    }
    return _currentUser?.userId ?? '';
  }

  /// Verifica si el usuario actual (o el jugador activo seleccionado) es el administrador de la mesa.
  bool get isCurrentUserTableAdmin {
    final table = _activeTable;
    if (table == null) return false;
    return table.isUserAdmin(effectivePlayerId) ||
        table.isUserAdmin(_currentUser?.userId ?? '');
  }

  void clearMessages() {
    if (_errorMessage != null || _successMessage != null) {
      _errorMessage = null;
      _successMessage = null;
      notifyListeners();
    }
  }

  void setActingPlayerOverride(String? playerId) {
    _actingPlayerIdOverride = playerId;
    notifyListeners();
  }

  /// Inicializa el controlador y recupera el estado después de cerrar o reiniciar el teléfono.
  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();

    try {
      final restoredUser = await _repository.restoreSession();
      _currentUser = restoredUser;

      if (restoredUser != null) {
        final savedTableId = await _repository.getSavedActiveTableId();
        if (savedTableId != null && savedTableId.isNotEmpty) {
          final table = await _repository.getTableById(savedTableId);
          if (table != null) {
            _subscribeToTable(table.tableId, initialTable: table);
          }
        }
      }
    } catch (e) {
      _errorMessage = 'Error al recuperar la sesión: $e';
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  void _subscribeToTable(String tableId, {GameTable? initialTable}) {
    _tableSubscription?.cancel();
    if (initialTable != null) {
      _activeTable = initialTable;
      notifyListeners();
    }
    _tableSubscription = _repository.watchTable(tableId).listen(
      (updatedTable) {
        _activeTable = updatedTable;
        notifyListeners();
      },
      onError: (Object err) {
        _errorMessage = 'Error de sincronización en tiempo real: $err';
        notifyListeners();
      },
    );
  }

  Future<bool> _guardOperation(
    Future<void> Function() action, {
    String? successMsg,
  }) async {
    if (_isBusy) return false;
    _isBusy = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await action();
      if (successMsg != null) {
        _successMessage = successMsg;
      }
      return true;
    } on BankOperationException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // AUTENTICACIÓN
  // ===========================================================================

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _guardOperation(() async {
      _currentUser = await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      final savedTableId = await _repository.getSavedActiveTableId();
      if (savedTableId != null) {
        final table = await _repository.getTableById(savedTableId);
        if (table != null) {
          _subscribeToTable(table.tableId, initialTable: table);
        }
      }
    });
  }

  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _guardOperation(() async {
      _currentUser = await _repository.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
    });
  }

  Future<bool> signInQuickProfile({
    required String displayName,
    required String email,
  }) {
    return _guardOperation(() async {
      _currentUser = await _repository.signInQuickProfile(
        displayName: displayName,
        email: email,
      );
      final savedTableId = await _repository.getSavedActiveTableId();
      if (savedTableId != null) {
        final table = await _repository.getTableById(savedTableId);
        if (table != null) {
          _subscribeToTable(table.tableId, initialTable: table);
        }
      }
    });
  }

  Future<void> signOut() async {
    await _tableSubscription?.cancel();
    _tableSubscription = null;
    _activeTable = null;
    _actingPlayerIdOverride = null;
    await _repository.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // ===========================================================================
  // SISTEMA DE MESAS
  // ===========================================================================

  Future<bool> createTable({
    required String tableName,
    required int initialCreditsCents,
    TariffConfig? customTariffs,
    bool autoCreateDemoPlayers = false,
  }) {
    return _guardOperation(
      () async {
        final user = _currentUser;
        if (user == null) {
          throw const BankOperationException(
            'unauthenticated',
            'Debe iniciar sesión antes de crear una mesa.',
          );
        }
        final table = await _repository.createTable(
          adminUser: user,
          tableName: tableName,
          initialCreditsCents: initialCreditsCents,
          customTariffs: customTariffs,
          autoCreateDemoPlayers: autoCreateDemoPlayers,
        );
        _actingPlayerIdOverride = null;
        _subscribeToTable(table.tableId, initialTable: table);
      },
      successMsg: 'Mesa creada correctamente. Código de invitación listo.',
    );
  }

  Future<bool> joinTableByCode(String inviteCode) {
    return _guardOperation(
      () async {
        final user = _currentUser;
        if (user == null) {
          throw const BankOperationException(
            'unauthenticated',
            'Debe iniciar sesión antes de unirse a una mesa.',
          );
        }
        final table = await _repository.joinTableByCode(
          user: user,
          inviteCode: inviteCode,
        );
        _actingPlayerIdOverride = null;
        _subscribeToTable(table.tableId, initialTable: table);
      },
      successMsg: 'Te has unido a la mesa en tiempo real.',
    );
  }

  Future<void> leaveCurrentTableView() async {
    await _tableSubscription?.cancel();
    _tableSubscription = null;
    _activeTable = null;
    _actingPlayerIdOverride = null;
    await _repository.saveActiveTableId(null);
    notifyListeners();
  }

  Future<bool> addParticipantAccountByAdmin({
    required String displayName,
    required String email,
    required int initialCreditsCents,
  }) {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        final updated = await _repository.addParticipantAccountByAdmin(
          tableId: table.tableId,
          adminUserId: table.adminUserId,
          displayName: displayName,
          email: email,
          initialCreditsCents: initialCreditsCents,
        );
        _activeTable = updated;
      },
      successMsg: 'Cuenta de jugador creada y asignada a la mesa.',
    );
  }

  // ===========================================================================
  // TARIFAS, BANCO VIRTUAL, RECARGAS Y TRANSFERENCIAS
  // ===========================================================================

  Future<bool> updateTariffs(TariffConfig newTariffs) {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        final updated = await _repository.updateTableTariffs(
          tableId: table.tableId,
          adminUserId: table.adminUserId,
          newTariffs: newTariffs,
        );
        _activeTable = updated;
      },
      successMsg:
          'Tarifas actualizadas. Las partidas anteriores conservan su tarifa original.',
    );
  }

  Future<bool> requestRecharge({
    required int amountCents,
    required String note,
    String? forPlayerId,
  }) {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        final pid = forPlayerId ?? effectivePlayerId;
        final updated = await _repository.requestRecharge(
          tableId: table.tableId,
          playerId: pid,
          amountCents: amountCents,
          note: note,
          idempotencyKey: 'req_${_uuid.v4()}',
        );
        _activeTable = updated;
      },
      successMsg: 'Solicitud de recarga enviada al Banco Virtual.',
    );
  }

  Future<bool> resolveRechargeRequest({
    required String requestId,
    required bool approve,
    required String reason,
  }) {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        final updated = await _repository.resolveRechargeRequest(
          tableId: table.tableId,
          adminUserId: table.adminUserId,
          requestId: requestId,
          approve: approve,
          reason: reason,
        );
        _activeTable = updated;
      },
      successMsg: approve
          ? 'Recarga aprobada y acreditada en saldo disponible.'
          : 'Solicitud de recarga rechazada.',
    );
  }

  Future<bool> applyAdminCreditAdjustment({
    required String targetPlayerId,
    required int deltaCents,
    required String reason,
    required bool isInitialCreditAllocation,
  }) {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        final updated = await _repository.applyAdminCreditAdjustment(
          tableId: table.tableId,
          adminUserId: table.adminUserId,
          targetPlayerId: targetPlayerId,
          deltaCents: deltaCents,
          reason: reason,
          isInitialCreditAllocation: isInitialCreditAllocation,
          idempotencyKey: 'adj_${_uuid.v4()}',
        );
        _activeTable = updated;
      },
      successMsg: 'Operación del banco registrada en el libro mayor auditable.',
    );
  }

  Future<bool> executeInternalTransfer({
    required String fromPlayerId,
    required String toPlayerId,
    required int amountCents,
    required String reason,
  }) {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        final updated = await _repository.executeInternalTransfer(
          tableId: table.tableId,
          callerUserId: fromPlayerId,
          fromPlayerId: fromPlayerId,
          toPlayerId: toPlayerId,
          amountCents: amountCents,
          reason: reason,
          idempotencyKey: 'tr_${_uuid.v4()}',
        );
        _activeTable = updated;
      },
      successMsg: 'Transferencia interna ejecutada de forma atómica.',
    );
  }

  // ===========================================================================
  // PARTIDAS, PREMIOS Y MOTOR DE LIQUIDACIÓN
  // ===========================================================================

  Future<bool> startNextRound() {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        final updated = await _repository.startNextRound(
          tableId: table.tableId,
          callerUserId: effectivePlayerId,
        );
        _activeTable = updated;
      },
      successMsg: 'Nueva partida iniciada.',
    );
  }

  Future<bool> updatePlayerRoundPrizes(PlayerRoundInput input) {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        // Si el admin está editando o el propio jugador está editando
        final caller = isCurrentUserTableAdmin
            ? table.adminUserId
            : effectivePlayerId;
        final updated = await _repository.updatePlayerRoundPrizes(
          tableId: table.tableId,
          callerUserId: caller,
          input: input,
        );
        _activeTable = updated;
      },
    );
  }

  Future<bool> calculateCurrentRound() {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        final updated = await _repository.calculateCurrentRound(
          tableId: table.tableId,
          callerUserId: effectivePlayerId,
        );
        _activeTable = updated;
      },
      successMsg:
          'Cálculo determinista completado. Revise la liquidación optimizada.',
    );
  }

  Future<bool> reopenCurrentRoundForEditing() {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        final updated = await _repository.reopenCurrentRoundForEditing(
          tableId: table.tableId,
          adminUserId: table.adminUserId,
        );
        _activeTable = updated;
      },
      successMsg: 'Partida reabierta para corregir premios.',
    );
  }

  Future<bool> confirmRoundResultByPlayer({String? playerId}) {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        final updated = await _repository.confirmRoundResultByPlayer(
          tableId: table.tableId,
          playerId: playerId ?? effectivePlayerId,
        );
        _activeTable = updated;
      },
      successMsg: 'Resultado confirmado por el jugador.',
    );
  }

  Future<bool> executeRoundSettlement({
    required bool allowPendingIfInsufficient,
  }) {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        final round = table.currentRound;
        if (round == null) {
          throw const BankOperationException(
            'no-round',
            'No hay partida activa para liquidar.',
          );
        }
        final updated = await _repository.executeRoundSettlement(
          tableId: table.tableId,
          adminUserId: table.adminUserId,
          roundId: round.roundId,
          allowPendingIfInsufficient: allowPendingIfInsufficient,
        );
        _activeTable = updated;
      },
      successMsg:
          'Liquidación ejecutada atómicamente. Saldos actualizados y siguiente partida lista.',
    );
  }

  Future<bool> settlePendingRoundTransfer({
    required String roundId,
    required String transferItemId,
    required bool useInternalCredits,
    required String verificationNote,
  }) {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        final updated = await _repository.settlePendingRoundTransfer(
          tableId: table.tableId,
          adminUserId: table.adminUserId,
          roundId: roundId,
          transferItemId: transferItemId,
          useInternalCredits: useInternalCredits,
          verificationNote: verificationNote,
          idempotencyKey: 'settle_pnd_${_uuid.v4()}',
        );
        _activeTable = updated;
      },
      successMsg: 'Obligación pendiente liquidada y verificada.',
    );
  }

  Future<bool> closeTableSession() {
    return _guardOperation(
      () async {
        final table = _activeTable!;
        final updated = await _repository.closeTableSession(
          tableId: table.tableId,
          adminUserId: table.adminUserId,
        );
        _activeTable = updated;
      },
      successMsg: 'Sesión de mesa cerrada oficialmente.',
    );
  }

  /// Genera un informe auditable completo en texto y JSON para exportar resultados.
  String buildExportReportText() {
    final table = _activeTable;
    if (table == null) return 'Sin mesa activa.';

    final sb = StringBuffer();
    sb.writeln('====================================================');
    sb.writeln('REPORTE AUDITABLE — ME VOY (BANCO VIRTUAL RUMMY)');
    sb.writeln('====================================================');
    sb.writeln('Mesa: ${table.tableName} (ID: ${table.tableId})');
    sb.writeln('Código de invitación: ${table.inviteCode}');
    sb.writeln('Administrador: ${table.adminDisplayName}');
    sb.writeln('Estado: ${table.status.name} | Versión: v${table.version}');
    sb.writeln('Fecha de exportación: ${DateTime.now().toUtc().toIso8601String()}');
    sb.writeln('----------------------------------------------------');
    sb.writeln('RESUMEN DE CUENTAS Y SALDOS INDIVIDUALES:');
    for (final p in table.sortedParticipants) {
      sb.writeln(
        '• Asiento ${p.seatNumber} — ${p.displayName} ${p.isAdmin ? "(Admin)" : ""}',
      );
      sb.writeln(
        '  - Saldo Disponible: \$${(p.availableBalanceCents / 100).toStringAsFixed(2)}',
      );
      sb.writeln(
        '  - Créditos Iniciales: \$${(p.initialCreditsCents / 100).toStringAsFixed(2)} | Recargas: \$${(p.totalRechargesCents / 100).toStringAsFixed(2)} | Ajustes: \$${(p.adminAdjustmentsCents / 100).toStringAsFixed(2)}',
      );
      sb.writeln(
        '  - Ganancias Juego: \$${(p.accumulatedWinningsCents / 100).toStringAsFixed(2)} | Pérdidas Juego: \$${(p.accumulatedLossesCents / 100).toStringAsFixed(2)}',
      );
      sb.writeln(
        '  - Saldo Neto Sesión: \$${(p.sessionNetBalanceCents / 100).toStringAsFixed(2)} | Mesas Ganadas: ${p.roundsWon}',
      );
      sb.writeln(
        '  - Deudas Pendientes: \$${(p.pendingDebtsCents / 100).toStringAsFixed(2)} | Premios por Cobrar: \$${(p.pendingPrizesCents / 100).toStringAsFixed(2)}',
      );
    }
    sb.writeln('----------------------------------------------------');
    sb.writeln(
      'Verificación Suma Cero Sesión: \$${(table.totalSessionNetSumCents / 100).toStringAsFixed(2)}',
    );
    sb.writeln(
      'Total Créditos Emitidos por Banco: \$${(table.totalBankIssuedCreditsCents / 100).toStringAsFixed(2)}',
    );
    sb.writeln(
      'Total Créditos Disponibles en Circulación: \$${(table.totalAvailableCreditsInCirculationCents / 100).toStringAsFixed(2)}',
    );
    sb.writeln('Partidas Completadas: ${table.completedRounds.length}');
    sb.writeln('Movimientos en Libro Mayor: ${table.ledgerEntries.length}');
    sb.writeln('----------------------------------------------------');
    sb.writeln('ÚLTIMOS MOVIMIENTOS AUDITABLES:');
    for (final tx in table.ledgerEntries.take(25)) {
      sb.writeln(
        '[${tx.createdAt.toIso8601String()}] ${tx.entryId} | ${tx.typeDisplayLabel} | '
        '${tx.fromAccountName} -> ${tx.toAccountName}: \$${(tx.amountCents / 100).toStringAsFixed(2)} '
        '(${tx.reason}) [Ref: ${tx.calculationReferenceId ?? "N/A"}]',
      );
    }
    return sb.toString();
  }

  String buildExportJson() {
    final table = _activeTable;
    if (table == null) return '{}';
    return const JsonEncoder.withIndent('  ').convert(table.toMap());
  }

  @override
  void dispose() {
    _tableSubscription?.cancel();
    super.dispose();
  }
}
