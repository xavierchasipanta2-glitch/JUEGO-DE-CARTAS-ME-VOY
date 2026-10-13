import 'package:flutter/material.dart';
import '../../engine/settlement_engine.dart';
import '../../models/player_account.dart';
import '../../models/round_models.dart';
import '../../models/tariff_config.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/money_badge.dart';

/// Pantalla 5: Registro de premios por jugador y validación de reglas de la partida.
class PrizeEntryTab extends StatelessWidget {
  final AppController controller;
  final VoidCallback onCalculatedSuccess;

  const PrizeEntryTab({
    super.key,
    required this.controller,
    required this.onCalculatedSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final table = controller.activeTable!;
    final round = table.currentRound;

    if (round == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.style_rounded,
                    size: 48,
                    color: MeVoyTheme.goldAccent,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No hay una partida en curso',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Inicia una nueva partida para capturar los premios de los jugadores.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: controller.isBusy
                        ? null
                        : () => controller.startNextRound(),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Iniciar Nueva Partida'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final tariffs = round.tariffSnapshot;
    final players = table.sortedParticipants;
    final rivalsCount = (players.length - 1).clamp(1, 3);
    final isLocked = round.status != RoundStatus.collectingPrizes;

    final orderedInputs = players.map((p) {
      return round.playerInputs[p.playerId] ??
          PlayerRoundInput(playerId: p.playerId, displayName: p.displayName);
    }).toList();

    final validationErrors = SettlementEngine.validateRoundInputs(
      inputs: orderedInputs,
      tariffs: tariffs,
    );

    final totalAces =
        orderedInputs.fold<int>(0, (sum, p) => sum + p.acesCount);
    final totalKings =
        orderedInputs.fold<int>(0, (sum, p) => sum + p.kingsCount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Encabezado con copia de tarifas congeladas de esta partida
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: MeVoyTheme.goldAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Partida #${round.roundNumber} — Registro de Premios',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isLocked
                            ? MeVoyTheme.warningAmber.withValues(alpha: 0.2)
                            : MeVoyTheme.creditPositive.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isLocked ? 'CALCULADA' : 'CAPTURA ACTIVA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isLocked
                              ? MeVoyTheme.warningAmber
                              : MeVoyTheme.creditPositive,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tarifas congeladas para esta partida (cada jugador cobra a sus $rivalsCount rivales): '
                  'Mesa ganada ${MoneyFormatter.formatCents(tariffs.tableWinCents)} • '
                  'As ${MoneyFormatter.formatCents(tariffs.aceCents)} • '
                  'K ${MoneyFormatter.formatCents(tariffs.kingCents)} • '
                  'Ruso ${MoneyFormatter.formatCents(tariffs.rusoCents)} • '
                  'Patas ${MoneyFormatter.formatCents(tariffs.patasCents)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _DeckCounterBadge(
                      label: 'Ases en mesa',
                      current: totalAces,
                      maxAllowed: tariffs.maxAcesPerRound,
                    ),
                    const SizedBox(width: 10),
                    _DeckCounterBadge(
                      label: 'Reyes (K) en mesa',
                      current: totalKings,
                      maxAllowed: tariffs.maxKingsPerRound,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Tarjetas de captura por cada participante
        ...players.map((player) {
          final input = round.playerInputs[player.playerId] ??
              PlayerRoundInput(
                playerId: player.playerId,
                displayName: player.displayName,
              );
          final canEdit = !isLocked &&
              (controller.isCurrentUserTableAdmin ||
                  controller.effectivePlayerId == player.playerId);

          return _PlayerPrizeInputCard(
            player: player,
            input: input,
            tariffs: tariffs,
            rivalsCount: rivalsCount,
            canEdit: canEdit,
            onChanged: (updatedInput) {
              controller.updatePlayerRoundPrizes(updatedInput);
            },
          );
        }),

        const SizedBox(height: 12),

        // Estado de validación de reglas de la partida
        if (validationErrors.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MeVoyTheme.warningAmber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: MeVoyTheme.warningAmber.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: MeVoyTheme.warningAmber,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Requisitos para calcular el cierre de la ronda:',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: MeVoyTheme.goldSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...validationErrors.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('• $e', style: const TextStyle(fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MeVoyTheme.creditPositive.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MeVoyTheme.creditPositive),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: MeVoyTheme.creditPositive,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Premios validados según las reglas de la partida. Listo para calcular compensaciones y liquidación.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        if (isLocked)
          Row(
            children: [
              if (controller.isCurrentUserTableAdmin &&
                  round.status == RoundStatus.awaitingConfirmation)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.isBusy
                        ? null
                        : () => controller.reopenCurrentRoundForEditing(),
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Reabrir Edición de Premios'),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCalculatedSuccess,
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Ir a Pantalla de Liquidación'),
                ),
              ),
            ],
          )
        else
          ElevatedButton.icon(
            onPressed: (validationErrors.isNotEmpty || controller.isBusy)
                ? null
                : () async {
                    final ok = await controller.calculateCurrentRound();
                    if (ok) {
                      onCalculatedSuccess();
                    }
                  },
            icon: const Icon(Icons.calculate_rounded),
            label: const Text(
              'Calcular Premios, Compensar Deudas y Generar Liquidación',
            ),
          ),
      ],
    );
  }
}

class _DeckCounterBadge extends StatelessWidget {
  final String label;
  final int current;
  final int maxAllowed;

  const _DeckCounterBadge({
    required this.label,
    required this.current,
    required this.maxAllowed,
  });

  @override
  Widget build(BuildContext context) {
    final exceeded = current > maxAllowed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: exceeded
            ? MeVoyTheme.debtNegative.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: exceeded ? MeVoyTheme.debtNegative : Colors.white24,
        ),
      ),
      child: Text(
        '$label: $current / $maxAllowed',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: exceeded ? MeVoyTheme.debtNegative : Colors.white,
        ),
      ),
    );
  }
}

class _PlayerPrizeInputCard extends StatelessWidget {
  final PlayerAccount player;
  final PlayerRoundInput input;
  final TariffConfig tariffs;
  final int rivalsCount;
  final bool canEdit;
  final ValueChanged<PlayerRoundInput> onChanged;

  const _PlayerPrizeInputCard({
    required this.player,
    required this.input,
    required this.tariffs,
    required this.rivalsCount,
    required this.canEdit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cardUnitCents = (input.acesCount * tariffs.aceCents) +
        (input.kingsCount * tariffs.kingCents) +
        (input.rusosCount * tariffs.rusoCents) +
        (input.patasCount * tariffs.patasCents);
    final winUnitCents = input.isWinner ? tariffs.tableWinCents : 0;
    final perRivalCents = cardUnitCents + winUnitCents;
    final grossTotalCents = perRivalCents * rivalsCount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: input.isWinner
              ? MeVoyTheme.goldAccent
              : Colors.white.withValues(alpha: 0.1),
          width: input.isWinner ? 2.0 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera del jugador y botón de Ganador de Mesa ("¡ME VOY!")
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: input.isWinner
                      ? MeVoyTheme.goldAccent
                      : Colors.white.withValues(alpha: 0.12),
                  foregroundColor:
                      input.isWinner ? const Color(0xFF1A1600) : Colors.white,
                  child: Text(
                    '${player.seatNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Cobra ${MoneyFormatter.formatCents(perRivalCents)} a cada rival • Bruto: ${MoneyFormatter.formatCents(grossTotalCents)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                ChoiceChip(
                  selected: input.isWinner,
                  selectedColor: MeVoyTheme.goldAccent,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: input.isWinner
                        ? const Color(0xFF1A1600)
                        : Colors.white,
                  ),
                  avatar: Icon(
                    Icons.emoji_events_rounded,
                    size: 17,
                    color: input.isWinner
                        ? const Color(0xFF1A1600)
                        : MeVoyTheme.goldAccent,
                  ),
                  label: Text(
                    input.isWinner
                        ? '¡GANÓ MESA! (+${MoneyFormatter.formatCents(tariffs.tableWinCents)})'
                        : 'Ganó Mesa',
                  ),
                  onSelected: canEdit
                      ? (selected) {
                          onChanged(input.copyWith(isWinner: selected));
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Contadores rápidos de premios de cartas
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _PrizeCounterControl(
                  title: 'Cada As',
                  unitRateLabel: MoneyFormatter.formatCents(tariffs.aceCents),
                  count: input.acesCount,
                  enabled: canEdit,
                  onChanged: (v) => onChanged(input.copyWith(acesCount: v)),
                ),
                _PrizeCounterControl(
                  title: 'Cada K',
                  unitRateLabel: MoneyFormatter.formatCents(tariffs.kingCents),
                  count: input.kingsCount,
                  enabled: canEdit,
                  onChanged: (v) => onChanged(input.copyWith(kingsCount: v)),
                ),
                _PrizeCounterControl(
                  title: 'Ruso',
                  unitRateLabel: MoneyFormatter.formatCents(tariffs.rusoCents),
                  count: input.rusosCount,
                  enabled: canEdit,
                  onChanged: (v) => onChanged(input.copyWith(rusosCount: v)),
                ),
                _PrizeCounterControl(
                  title: 'Patas',
                  unitRateLabel: MoneyFormatter.formatCents(tariffs.patasCents),
                  count: input.patasCount,
                  enabled: canEdit,
                  onChanged: (v) => onChanged(input.copyWith(patasCount: v)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrizeCounterControl extends StatelessWidget {
  final String title;
  final String unitRateLabel;
  final int count;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _PrizeCounterControl({
    required this.title,
    required this.unitRateLabel,
    required this.count,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = count > 0;
    return Container(
      width: 152,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? MeVoyTheme.goldAccent.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? MeVoyTheme.goldAccent.withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              Text(
                unitRateLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed:
                    (enabled && count > 0) ? () => onChanged(count - 1) : null,
                icon: const Icon(Icons.remove_circle_outline, size: 22),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isActive ? MeVoyTheme.goldAccent : Colors.white70,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: enabled ? () => onChanged(count + 1) : null,
                icon: const Icon(Icons.add_circle_outline, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
