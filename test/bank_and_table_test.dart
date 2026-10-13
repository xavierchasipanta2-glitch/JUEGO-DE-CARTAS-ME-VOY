import 'package:flutter_test/flutter_test.dart';
import 'package:me_voy/models/round_models.dart';
import 'package:me_voy/services/backend_repository.dart';
import 'package:me_voy/services/local_synced_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Pruebas Funcionales — Conexión de 4 Jugadores, Banco Virtual y Liquidación',
      () {
    late LocalSyncedGameRepository repo;
    late AppUserSession adminSession;
    late AppUserSession player2Session;
    late AppUserSession player3Session;
    late AppUserSession player4Session;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = LocalSyncedGameRepository();

      adminSession = await repo.signInQuickProfile(
        displayName: 'Ana (Admin)',
        email: 'ana@mevoy.app',
      );
      player2Session = const AppUserSession(
        userId: 'usr_beto',
        displayName: 'Beto',
        email: 'beto@mevoy.app',
      );
      player3Session = const AppUserSession(
        userId: 'usr_carla',
        displayName: 'Carla',
        email: 'carla@mevoy.app',
      );
      player4Session = const AppUserSession(
        userId: 'usr_diego',
        displayName: 'Diego',
        email: 'diego@mevoy.app',
      );
    });

    test(
        'Conecta 4 jugadores mediante código de invitación único, asigna créditos iniciales y bloquea quinto jugador',
        () async {
      // Crear mesa con $5.00 (500 centavos) de créditos iniciales
      final created = await repo.createTable(
        adminUser: adminSession,
        tableName: 'Mesa Viernes Rummy',
        initialCreditsCents: 500,
      );

      expect(created.inviteCode.length, 6);
      expect(created.participants.length, 1);
      expect(
        created.participants[adminSession.userId]!.availableBalanceCents,
        500,
      );
      expect(
        created.participants[adminSession.userId]!.initialCreditsCents,
        500,
      );
      expect(
        created.participants[adminSession.userId]!.sessionNetBalanceCents,
        0,
      );

      // Unirse Jugadores 2, 3 y 4 mediante el código de invitación
      await repo.joinTableByCode(
        user: player2Session,
        inviteCode: created.inviteCode,
      );
      await repo.joinTableByCode(
        user: player3Session,
        inviteCode: created.inviteCode,
      );
      final fullTable = await repo.joinTableByCode(
        user: player4Session,
        inviteCode: created.inviteCode,
      );

      expect(fullTable.participants.length, 4);
      expect(fullTable.totalBankIssuedCreditsCents, 2000); // $20.00 en la mesa
      expect(fullTable.totalAvailableCreditsInCirculationCents, 2000);
      expect(fullTable.ledgerEntries.length, 4); // 4 asignaciones iniciales auditables

      // Intentar unir un 5to jugador debe ser rechazado
      const player5 = AppUserSession(
        userId: 'usr_extra',
        displayName: 'Extra',
        email: 'extra@mevoy.app',
      );
      expect(
        () => repo.joinTableByCode(
          user: player5,
          inviteCode: created.inviteCode,
        ),
        throwsA(isA<BankOperationException>()),
      );
    });

    test(
        'Distingue recargas de ganancias del juego y bloquea transferencias que excedan créditos disponibles',
        () async {
      var table = await repo.createTable(
        adminUser: adminSession,
        tableName: 'Mesa Control Banco',
        initialCreditsCents: 200, // $2.00 iniciales
      );
      table = await repo.joinTableByCode(
        user: player2Session,
        inviteCode: table.inviteCode,
      );

      // Beto solicita una recarga de $3.00 (300c)
      table = await repo.requestRecharge(
        tableId: table.tableId,
        playerId: player2Session.userId,
        amountCents: 300,
        note: 'Recarga para segunda ronda',
        idempotencyKey: 'req_key_1',
      );
      expect(table.pendingRechargeRequestsCount, 1);

      // Un jugador NO administrador no puede aprobar recargas
      final reqId = table.rechargeRequests.first.requestId;
      expect(
        () => repo.resolveRechargeRequest(
          tableId: table.tableId,
          adminUserId: player2Session.userId,
          requestId: reqId,
          approve: true,
          reason: 'Intento no autorizado',
        ),
        throwsA(isA<BankOperationException>()),
      );

      // El administrador aprueba la recarga
      table = await repo.resolveRechargeRequest(
        tableId: table.tableId,
        adminUserId: adminSession.userId,
        requestId: reqId,
        approve: true,
        reason: 'Recarga verificada por el banco',
      );

      final betoAccount = table.participants[player2Session.userId]!;
      expect(betoAccount.initialCreditsCents, 200);
      expect(betoAccount.totalRechargesCents, 300);
      expect(betoAccount.availableBalanceCents, 500); // $2.00 + $3.00 = $5.00
      // CRÍTICO: La recarga NO se registra como ganancia del juego
      expect(betoAccount.accumulatedWinningsCents, 0);
      expect(betoAccount.sessionNetBalanceCents, 0);

      // Bloquear transferencia que exceda los créditos disponibles ($6.00 > $5.00)
      expect(
        () => repo.executeInternalTransfer(
          tableId: table.tableId,
          callerUserId: player2Session.userId,
          fromPlayerId: player2Session.userId,
          toPlayerId: adminSession.userId,
          amountCents: 600,
          reason: 'Transferencia excesiva',
          idempotencyKey: 'tr_over_1',
        ),
        throwsA(isA<BankOperationException>()),
      );

      // Impedir que un jugador transfiera desde la cuenta de otro jugador
      expect(
        () => repo.executeInternalTransfer(
          tableId: table.tableId,
          callerUserId: player2Session.userId,
          fromPlayerId: adminSession.userId,
          toPlayerId: player2Session.userId,
          amountCents: 50,
          reason: 'Intento de robo de saldo',
          idempotencyKey: 'tr_unauth_1',
        ),
        throwsA(isA<BankOperationException>()),
      );

      // Transferencia válida e idempotente ($1.00 de Beto a Ana)
      table = await repo.executeInternalTransfer(
        tableId: table.tableId,
        callerUserId: player2Session.userId,
        fromPlayerId: player2Session.userId,
        toPlayerId: adminSession.userId,
        amountCents: 100,
        reason: 'Pago directo',
        idempotencyKey: 'tr_valid_1',
      );
      expect(table.participants[player2Session.userId]!.availableBalanceCents, 400);
      expect(table.participants[adminSession.userId]!.availableBalanceCents, 300);

      // Repetir la misma operación con el mismo idempotencyKey debe ser rechazado
      expect(
        () => repo.executeInternalTransfer(
          tableId: table.tableId,
          callerUserId: player2Session.userId,
          fromPlayerId: player2Session.userId,
          toPlayerId: adminSession.userId,
          amountCents: 100,
          reason: 'Pago directo repetido por error de red',
          idempotencyKey: 'tr_valid_1',
        ),
        throwsA(isA<BankOperationException>()),
      );
    });

    test(
        'Ejecuta ciclo completo de cierre de partida de 4 jugadores, liquidación automática atómica y preparación de siguiente partida',
        () async {
      var table = await repo.createTable(
        adminUser: adminSession,
        tableName: 'Mesa Torneo',
        initialCreditsCents: 500, // $5.00 cada uno
      );
      table = await repo.joinTableByCode(
        user: player2Session,
        inviteCode: table.inviteCode,
      );
      table = await repo.joinTableByCode(
        user: player3Session,
        inviteCode: table.inviteCode,
      );
      table = await repo.joinTableByCode(
        user: player4Session,
        inviteCode: table.inviteCode,
      );

      // Iniciar Partida #1
      table = await repo.startNextRound(
        tableId: table.tableId,
        callerUserId: adminSession.userId,
      );
      expect(table.currentRound, isNotNull);
      expect(table.currentRound!.roundNumber, 1);

      // Registrar premios:
      // Ana (Admin): Ganadora ($0.50) + 2 Ases ($0.20) = 70c por rival
      // Beto: 1 Pata ($0.20) = 20c por rival
      // Carla: 1 K ($0.10) = 10c por rival
      // Diego: 0c por rival
      table = await repo.updatePlayerRoundPrizes(
        tableId: table.tableId,
        callerUserId: adminSession.userId,
        input: PlayerRoundInput(
          playerId: adminSession.userId,
          displayName: adminSession.displayName,
          isWinner: true,
          acesCount: 2,
        ),
      );
      table = await repo.updatePlayerRoundPrizes(
        tableId: table.tableId,
        callerUserId: player2Session.userId,
        input: PlayerRoundInput(
          playerId: player2Session.userId,
          displayName: player2Session.displayName,
          patasCount: 1,
        ),
      );
      table = await repo.updatePlayerRoundPrizes(
        tableId: table.tableId,
        callerUserId: player3Session.userId,
        input: PlayerRoundInput(
          playerId: player3Session.userId,
          displayName: player3Session.displayName,
          kingsCount: 1,
        ),
      );

      // Calcular partida
      table = await repo.calculateCurrentRound(
        tableId: table.tableId,
        callerUserId: adminSession.userId,
      );
      final round1Id = table.currentRound!.roundId;
      final calc = table.currentRound!.calculationResult!;

      // Verificar saldos netos de la partida:
      // Ana: 3*70 - (20+10+0) = 210 - 30 = +180c
      // Beto: 3*20 - (70+10+0) = 60 - 80 = -20c
      // Carla: 3*10 - (70+20+0) = 30 - 90 = -60c
      // Diego: 0 - (70+20+10) = -100c
      expect(calc.netBalancesByPlayerCents[adminSession.userId], 180);
      expect(calc.netBalancesByPlayerCents[player2Session.userId], -20);
      expect(calc.netBalancesByPlayerCents[player3Session.userId], -60);
      expect(calc.netBalancesByPlayerCents[player4Session.userId], -100);
      expect(calc.isZeroSumVerified, isTrue);

      // Ejecutar liquidación automática
      table = await repo.executeRoundSettlement(
        tableId: table.tableId,
        adminUserId: adminSession.userId,
        roundId: round1Id,
        allowPendingIfInsufficient: false,
      );

      // Verificar que los saldos disponibles y acumulados se actualizaron UNA SOLA VEZ:
      expect(
        table.participants[adminSession.userId]!.availableBalanceCents,
        680, // 500 + 180
      );
      expect(
        table.participants[adminSession.userId]!.accumulatedWinningsCents,
        180,
      );
      expect(
        table.participants[player4Session.userId]!.availableBalanceCents,
        400, // 500 - 100
      );
      expect(
        table.participants[player4Session.userId]!.accumulatedLossesCents,
        100,
      );

      // La suma de saldos netos de sesión de todos los participantes es 0
      expect(table.totalSessionNetSumCents, 0);
      // El total de créditos en circulación se conserva intacto (2000c = $20.00)
      expect(table.totalAvailableCreditsInCirculationCents, 2000);

      // La Partida #1 pasó a completedRounds y la Partida #2 ya está preparada automáticamente
      expect(table.completedRounds.length, 1);
      expect(table.completedRounds.first.roundId, round1Id);
      expect(table.currentRound, isNotNull);
      expect(table.currentRound!.roundNumber, 2);

      // Intentar liquidar de nuevo la Partida #1 es bloqueado por idempotencia
      expect(
        () => repo.executeRoundSettlement(
          tableId: table.tableId,
          adminUserId: adminSession.userId,
          roundId: round1Id,
          allowPendingIfInsufficient: false,
        ),
        throwsA(isA<BankOperationException>()),
      );
    });
  });
}
