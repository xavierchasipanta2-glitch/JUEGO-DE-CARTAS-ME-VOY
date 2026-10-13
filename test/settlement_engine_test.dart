import 'package:flutter_test/flutter_test.dart';
import 'package:me_voy/engine/settlement_engine.dart';
import 'package:me_voy/models/round_models.dart';
import 'package:me_voy/models/tariff_config.dart';

void main() {
  group('Motor de Cálculo Determinista — SettlementEngine', () {
    late TariffConfig standardTariffs;

    setUp(() {
      standardTariffs = TariffConfig.defaultStandard(adminUserId: 'admin_1');
    });

    test(
        'Calcula premios brutos, obligaciones por pareja, compensaciones bilaterales y plan óptimo en ronda de 4 jugadores',
        () {
      // Tarifas estándar:
      // Mesa ganada = 50c ($0.50), As = 10c, K = 10c, Ruso = 10c, Patas = 20c
      //
      // Jugador 1 (Ana - Ganadora): Mesa(50) + 2 Ases(20) + 1 Pata(20) = 90c por rival -> Bruto total = 270c ($2.70)
      // Jugador 2 (Beto): 1 As(10) + 2 K(20) + 1 Ruso(10) = 40c por rival -> Bruto total = 120c ($1.20)
      // Jugador 3 (Carla): 1 Pata(20) = 20c por rival -> Bruto total = 60c ($0.60)
      // Jugador 4 (Diego): Sin premios = 0c por rival -> Bruto total = 0c ($0.00)
      final inputs = [
        const PlayerRoundInput(
          playerId: 'p1',
          displayName: 'Ana',
          isWinner: true,
          acesCount: 2,
          kingsCount: 0,
          rusosCount: 0,
          patasCount: 1,
        ),
        const PlayerRoundInput(
          playerId: 'p2',
          displayName: 'Beto',
          isWinner: false,
          acesCount: 1,
          kingsCount: 2,
          rusosCount: 1,
          patasCount: 0,
        ),
        const PlayerRoundInput(
          playerId: 'p3',
          displayName: 'Carla',
          isWinner: false,
          acesCount: 0,
          kingsCount: 0,
          rusosCount: 0,
          patasCount: 1,
        ),
        const PlayerRoundInput(
          playerId: 'p4',
          displayName: 'Diego',
          isWinner: false,
          acesCount: 0,
          kingsCount: 0,
          rusosCount: 0,
          patasCount: 0,
        ),
      ];

      final result = SettlementEngine.calculateRound(
        roundId: 'r_001',
        roundNumber: 1,
        tariffs: standardTariffs,
        inputs: inputs,
        timestamp: DateTime.utc(2026, 10, 12, 18, 0),
      );

      // 1. Verificar premios brutos
      final grossMap = {
        for (final g in result.grossBreakdowns) g.playerId: g,
      };
      expect(grossMap['p1']!.cardPrizePerRivalCents, 40);
      expect(grossMap['p1']!.tablePrizePerRivalCents, 50);
      expect(grossMap['p1']!.totalClaimPerRivalCents, 90);
      expect(grossMap['p1']!.grossTotalCents, 270); // $2.70

      expect(grossMap['p2']!.totalClaimPerRivalCents, 40);
      expect(grossMap['p2']!.grossTotalCents, 120); // $1.20

      expect(grossMap['p3']!.totalClaimPerRivalCents, 20);
      expect(grossMap['p3']!.grossTotalCents, 60); // $0.60

      expect(grossMap['p4']!.totalClaimPerRivalCents, 0);
      expect(grossMap['p4']!.grossTotalCents, 0); // $0.00

      // 2. Verificar 12 obligaciones dirigidas (4 * 3) y 6 compensaciones bilaterales
      expect(result.rawPairwiseObligations.length, 12);
      expect(result.bilateralCompensations.length, 6);

      // Compensación entre Ana (p1: cobra 90) y Beto (p2: cobra 40):
      // Beto debe 90 a Ana, Ana debe 40 a Beto -> Compensan 40, Beto queda debiendo 50 a Ana.
      final compP1P2 = result.bilateralCompensations.firstWhere(
        (c) => c.playerAId == 'p1' && c.playerBId == 'p2',
      );
      expect(compP1P2.obligationAToBCents, 40);
      expect(compP1P2.obligationBToACents, 90);
      expect(compP1P2.compensatedCents, 40);
      expect(compP1P2.netDebtorId, 'p2');
      expect(compP1P2.netCreditorId, 'p1');
      expect(compP1P2.netAmountCents, 50);

      // 3. Verificar saldos netos individuales:
      // Ana (p1): Cobra 270 - Paga (40 + 20 + 0) = +210c (+$2.10)
      // Beto (p2): Cobra 120 - Paga (90 + 20 + 0) = +10c (+$0.10)
      // Carla (p3): Cobra 60 - Paga (90 + 40 + 0) = -70c (-$0.70)
      // Diego (p4): Cobra 0 - Paga (90 + 40 + 20) = -150c (-$1.50)
      expect(result.netBalancesByPlayerCents['p1'], 210);
      expect(result.netBalancesByPlayerCents['p2'], 10);
      expect(result.netBalancesByPlayerCents['p3'], -70);
      expect(result.netBalancesByPlayerCents['p4'], -150);

      // 4. Suma cero estricta
      expect(result.sumOfNetBalancesCents, 0);
      expect(result.isZeroSumVerified, isTrue);

      // 5. Plan de liquidación optimizado:
      // En lugar de 9 pagos brutos o 5 pagos bilaterales, solo se requieren 3 transferencias:
      // Diego (-150) -> Ana (+210): 150c
      // Carla (-70) -> Ana (+60 restantes): 60c
      // Carla (-10 restantes) -> Beto (+10): 10c
      expect(result.optimizedSettlementPlan.length, 3);
      expect(result.totalOptimizedTransferVolumeCents, 220);
      expect(result.paymentsReducedCount, greaterThan(0));
    });

    test(
        'Optimiza pares exactos en 2 transferencias cuando dos deudores empatan exactamente con dos acreedores',
        () {
      // Queremos que dos jugadores tengan +40 y +20, y otros dos -40 y -20, o similar.
      // Probemos cuando dos jugadores cobran exactamente lo mismo y otros dos menos:
      // p1 (Ganador): Mesa(50) = 50c por rival
      // p2: 5 Ases(50) = 50c por rival
      // p3: 1 Pata(20) = 20c por rival
      // p4: 1Pata(20) = 20c por rival
      // Netos:
      // p1: 3*50 - (50+20+20) = 150 - 90 = +60c
      // p2: 3*50 - (50+20+20) = 150 - 90 = +60c
      // p3: 3*20 - (50+50+20) = 60 - 120 = -60c
      // p4: 3*20 - (50+50+20) = 60 - 120 = -60c
      // ¡Dos deudores de -60c y dos acreedores de +60c!
      // El plan óptimo debe resolverlo en SOLO 2 transferencias directas de 60c.
      final inputs = [
        const PlayerRoundInput(
          playerId: 'p1',
          displayName: 'Ana',
          isWinner: true,
        ),
        const PlayerRoundInput(
          playerId: 'p2',
          displayName: 'Beto',
          isWinner: false,
          acesCount: 5,
        ),
        const PlayerRoundInput(
          playerId: 'p3',
          displayName: 'Carla',
          isWinner: false,
          patasCount: 1,
        ),
        const PlayerRoundInput(
          playerId: 'p4',
          displayName: 'Diego',
          isWinner: false,
          patasCount: 1,
        ),
      ];

      final result = SettlementEngine.calculateRound(
        roundId: 'r_002',
        roundNumber: 2,
        tariffs: standardTariffs,
        inputs: inputs,
      );

      expect(result.netBalancesByPlayerCents['p1'], 60);
      expect(result.netBalancesByPlayerCents['p2'], 60);
      expect(result.netBalancesByPlayerCents['p3'], -60);
      expect(result.netBalancesByPlayerCents['p4'], -60);
      expect(result.isZeroSumVerified, isTrue);
      expect(result.optimizedSettlementPlan.length, 2);
      expect(result.optimizedSettlementPlan[0].amountCents, 60);
      expect(result.optimizedSettlementPlan[1].amountCents, 60);
    });

    test(
        'Genera 0 transferencias cuando todas las deudas se compensan exactamente a cero',
        () {
      // Todos cobran 50c por rival:
      // p1: Ganador (50c)
      // p2: 5 Ases (50c)
      // p3: 5 K (50c)
      // p4: 2 Patas (40c) + 1 Ruso (10c) = 50c
      final inputs = [
        const PlayerRoundInput(
          playerId: 'p1',
          displayName: 'Ana',
          isWinner: true,
        ),
        const PlayerRoundInput(
          playerId: 'p2',
          displayName: 'Beto',
          acesCount: 5,
        ),
        const PlayerRoundInput(
          playerId: 'p3',
          displayName: 'Carla',
          kingsCount: 5,
        ),
        const PlayerRoundInput(
          playerId: 'p4',
          displayName: 'Diego',
          patasCount: 2,
          rusosCount: 1,
        ),
      ];

      final result = SettlementEngine.calculateRound(
        roundId: 'r_003',
        roundNumber: 3,
        tariffs: standardTariffs,
        inputs: inputs,
      );

      for (final net in result.netBalancesByPlayerCents.values) {
        expect(net, 0);
      }
      expect(result.optimizedSettlementPlan, isEmpty);
      expect(result.totalRawObligationsVolumeCents, 600); // $6.00 compensados a $0.00
      expect(result.totalOptimizedTransferVolumeCents, 0);
    });

    test(
        'Conserva instantánea inmutable de tarifas y produce checksum determinista',
        () {
      final inputs = [
        const PlayerRoundInput(
          playerId: 'p1',
          displayName: 'Ana',
          isWinner: true,
          acesCount: 1,
        ),
        const PlayerRoundInput(
          playerId: 'p2',
          displayName: 'Beto',
          kingsCount: 1,
        ),
      ];

      final r1 = SettlementEngine.calculateRound(
        roundId: 'r_det',
        roundNumber: 1,
        tariffs: standardTariffs,
        inputs: inputs,
      );
      final r2 = SettlementEngine.calculateRound(
        roundId: 'r_det',
        roundNumber: 1,
        tariffs: standardTariffs,
        inputs: inputs,
      );

      expect(r1.auditChecksum, equals(r2.auditChecksum));
      expect(r1.calculationId, equals(r2.calculationId));

      // Si cambiamos las tarifas después para rondas futuras, r1 conserva su snapshot
      final futureTariffs = standardTariffs.copyWith(tableWinCents: 100);
      expect(r1.tariffSnapshot.tableWinCents, 50);
      expect(futureTariffs.tableWinCents, 100);
    });

    test('Valida reglas de la partida y rechaza entradas inválidas', () {
      // Sin ganador
      final noWinnerInputs = [
        const PlayerRoundInput(playerId: 'p1', displayName: 'Ana'),
        const PlayerRoundInput(playerId: 'p2', displayName: 'Beto'),
      ];
      expect(
        () => SettlementEngine.calculateRound(
          roundId: 'r_err1',
          roundNumber: 1,
          tariffs: standardTariffs,
          inputs: noWinnerInputs,
        ),
        throwsA(isA<RoundValidationException>()),
      );

      // Dos ganadores
      final twoWinnersInputs = [
        const PlayerRoundInput(
          playerId: 'p1',
          displayName: 'Ana',
          isWinner: true,
        ),
        const PlayerRoundInput(
          playerId: 'p2',
          displayName: 'Beto',
          isWinner: true,
        ),
      ];
      expect(
        () => SettlementEngine.calculateRound(
          roundId: 'r_err2',
          roundNumber: 1,
          tariffs: standardTariffs,
          inputs: twoWinnersInputs,
        ),
        throwsA(isA<RoundValidationException>()),
      );

      // Exceso de Ases en el mazo (> 8)
      final tooManyAcesInputs = [
        const PlayerRoundInput(
          playerId: 'p1',
          displayName: 'Ana',
          isWinner: true,
          acesCount: 5,
        ),
        const PlayerRoundInput(
          playerId: 'p2',
          displayName: 'Beto',
          acesCount: 5,
        ),
      ];
      expect(
        () => SettlementEngine.calculateRound(
          roundId: 'r_err3',
          roundNumber: 1,
          tariffs: standardTariffs,
          inputs: tooManyAcesInputs,
        ),
        throwsA(isA<RoundValidationException>()),
      );
    });
  });
}
