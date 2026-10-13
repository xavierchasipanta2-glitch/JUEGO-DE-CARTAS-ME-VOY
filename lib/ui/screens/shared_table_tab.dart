import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_table.dart';
import '../../models/player_account.dart';
import '../../models/round_models.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/money_badge.dart';

/// Pantalla 3: Mesa compartida en tiempo real (hasta 4 jugadores).
class SharedTableTab extends StatelessWidget {
  final AppController controller;
  final ValueChanged<int> onNavigateToTab;

  const SharedTableTab({
    super.key,
    required this.controller,
    required this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    final table = controller.activeTable!;
    final players = table.sortedParticipants;
    final currentRound = table.currentRound;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Encabezado de Mesa y Código de Invitación Único
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: MeVoyTheme.goldAccent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.style_rounded,
                        color: MeVoyTheme.goldAccent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            table.tableName,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Admin: ${table.adminDisplayName} • ${players.length}/${table.maxPlayers} jugadores • Sincronización v${table.version}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Código de invitación con copia rápida
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: table.inviteCode),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Código "${table.inviteCode}" copiado al portapapeles.',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A241C),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: MeVoyTheme.goldAccent),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'CÓDIGO MESA',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: MeVoyTheme.goldSoft,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  table.inviteCode,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    color: MeVoyTheme.goldAccent,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: MeVoyTheme.goldSoft,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Barra de tarifas activas en la mesa
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TariffChip(
                      label: 'Mesa ganada',
                      cents: table.currentTariffs.tableWinCents,
                      suffix: '/rival',
                    ),
                    _TariffChip(
                      label: 'Cada As',
                      cents: table.currentTariffs.aceCents,
                    ),
                    _TariffChip(
                      label: 'Cada K',
                      cents: table.currentTariffs.kingCents,
                    ),
                    _TariffChip(
                      label: 'Ruso',
                      cents: table.currentTariffs.rusoCents,
                    ),
                    _TariffChip(
                      label: 'Patas',
                      cents: table.currentTariffs.patasCents,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Banner de estado de la Partida Actual y acciones rápidas
        _buildRoundStatusBanner(context, table, currentRound),
        const SizedBox(height: 14),

        // Título de los 4 asientos de la Mesa Compartida
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ASIENTOS DE LA MESA (TIEMPO REAL)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: MeVoyTheme.goldSoft,
              ),
            ),
            if (players.length < table.maxPlayers &&
                controller.isCurrentUserTableAdmin)
              TextButton.icon(
                onPressed: () => _showAddPlayerDialog(context),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Agregar Jugador'),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Cuadrícula de hasta 4 jugadores
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: table.maxPlayers,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            mainAxisExtent: 192,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final seatNum = index + 1;
            final player = players
                .where((p) => p.seatNumber == seatNum)
                .cast<PlayerAccount?>()
                .firstOrNull;

            if (player == null) {
              return _EmptySeatCard(
                seatNumber: seatNum,
                inviteCode: table.inviteCode,
                canAddByAdmin: controller.isCurrentUserTableAdmin,
                onAddTap: () => _showAddPlayerDialog(context),
              );
            }

            final isSelectedPerspective =
                controller.effectivePlayerId == player.playerId;

            return _PlayerSeatCard(
              player: player,
              isSelectedPerspective: isSelectedPerspective,
              onSelectPerspective: () {
                controller.setActingPlayerOverride(player.playerId);
              },
              onRequestRechargeTap: () {
                controller.setActingPlayerOverride(player.playerId);
                onNavigateToTab(4); // Pestaña Recarga
              },
            );
          },
        ),
        const SizedBox(height: 16),

        // Resumen de equilibrio contable de la mesa
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.balance_rounded,
                      color: MeVoyTheme.goldAccent,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Verificación Contable en Tiempo Real',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _SummaryMetricTile(
                      title: 'Créditos Emitidos (Banco)',
                      cents: table.totalBankIssuedCreditsCents,
                    ),
                    _SummaryMetricTile(
                      title: 'Créditos en Circulación',
                      cents: table.totalAvailableCreditsInCirculationCents,
                    ),
                    _SummaryMetricTile(
                      title: 'Suma Neta de Sesión (Debe ser \$0.00)',
                      cents: table.totalSessionNetSumCents,
                      highlightZeroSum: true,
                    ),
                    _SummaryMetricTile(
                      title: 'Partidas Cerradas',
                      customValue: '${table.completedRounds.length}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundStatusBanner(
    BuildContext context,
    GameTable table,
    GameRound? round,
  ) {
    if (round == null) {
      return Card(
        color: const Color(0xFF133A2E),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: MeVoyTheme.goldAccent,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sin partida activa en curso',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      table.participants.length < 2
                          ? 'Conecta al menos 2 jugadores para iniciar la primera partida.'
                          : 'Inicia la siguiente partida para capturar los premios de la ronda.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              if (table.participants.length >= 2 &&
                  table.status != TableStatus.closed)
                ElevatedButton(
                  onPressed: controller.isBusy
                      ? null
                      : () => controller.startNextRound(),
                  child: const Text('Iniciar Partida'),
                ),
            ],
          ),
        ),
      );
    }

    final isCollecting = round.status == RoundStatus.collectingPrizes;
    return Card(
      color: isCollecting ? const Color(0xFF144233) : const Color(0xFF332B10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isCollecting
                  ? Icons.edit_note_rounded
                  : Icons.receipt_long_rounded,
              color: MeVoyTheme.goldAccent,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Partida #${round.roundNumber} — ${isCollecting ? "Registro de Premios Abierto" : "Lista para Liquidar"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCollecting
                        ? 'Introduce el ganador de la mesa y las cartas premiadas (Ases, K, Ruso, Patas).'
                        : 'El motor determinista ya calculó las compensaciones y el plan de liquidación.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                onNavigateToTab(isCollecting ? 2 : 3);
              },
              icon: Icon(
                isCollecting
                    ? Icons.emoji_events_rounded
                    : Icons.payments_rounded,
                size: 18,
              ),
              label: Text(isCollecting ? 'Registrar Premios' : 'Ver Liquidación'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPlayerDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final creditsCtrl = TextEditingController(
      text: (controller.activeTable!.defaultInitialCreditsCents / 100)
          .toStringAsFixed(2),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Crear Cuenta de Jugador en la Mesa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Jugador',
                  hintText: 'Ej. Sofía',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correo (opcional)',
                  hintText: 'sofia@mevoy.app',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: creditsCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Créditos Iniciales (\$)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final cents =
                    MoneyFormatter.parseDollarsToCents(creditsCtrl.text) ?? 500;
                Navigator.of(ctx).pop();
                await controller.addParticipantAccountByAdmin(
                  displayName: name,
                  email: emailCtrl.text.trim().isEmpty
                      ? '${name.toLowerCase()}@mevoy.app'
                      : emailCtrl.text.trim(),
                  initialCreditsCents: cents,
                );
              },
              child: const Text('Crear y Sentar'),
            ),
          ],
        );
      },
    );
  }
}

class _TariffChip extends StatelessWidget {
  final String label;
  final int cents;
  final String suffix;

  const _TariffChip({
    required this.label,
    required this.cents,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: ${MoneyFormatter.formatCents(cents)}$suffix',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PlayerSeatCard extends StatelessWidget {
  final PlayerAccount player;
  final bool isSelectedPerspective;
  final VoidCallback onSelectPerspective;
  final VoidCallback onRequestRechargeTap;

  const _PlayerSeatCard({
    required this.player,
    required this.isSelectedPerspective,
    required this.onSelectPerspective,
    required this.onRequestRechargeTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAlert =
        player.hasPendingDebts || player.hasLowOrInsufficientBalance;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onSelectPerspective,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MeVoyTheme.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelectedPerspective
                ? MeVoyTheme.goldAccent
                : (hasAlert
                    ? MeVoyTheme.warningAmber.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.12)),
            width: isSelectedPerspective ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: isSelectedPerspective
                      ? MeVoyTheme.goldAccent
                      : Colors.white.withValues(alpha: 0.14),
                  foregroundColor: isSelectedPerspective
                      ? const Color(0xFF1A1600)
                      : Colors.white,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              player.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (player.isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: MeVoyTheme.goldAccent
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'BANCO',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: MeVoyTheme.goldAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Mesas ganadas: ${player.roundsWon}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasAlert)
                  Tooltip(
                    message: player.hasPendingDebts
                        ? 'Tiene deudas pendientes por saldar'
                        : 'Saldo disponible bajo (< \$1.00)',
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: MeVoyTheme.warningAmber,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SALDO DISPONIBLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      MoneyFormatter.formatCents(player.availableBalanceCents),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: player.hasLowOrInsufficientBalance
                            ? MeVoyTheme.warningAmber
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'NETO SESIÓN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 2),
                    MoneyBadge(
                      cents: player.sessionNetBalanceCents,
                      showPlusSign: true,
                      fontSize: 13.5,
                    ),
                  ],
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    player.hasPendingDebts
                        ? 'Deuda pend.: ${MoneyFormatter.formatCents(player.pendingDebtsCents)}'
                        : (player.hasPendingPrizes
                            ? 'Por cobrar: ${MoneyFormatter.formatCents(player.pendingPrizesCents)}'
                            : 'Inicial: ${MoneyFormatter.formatCents(player.initialCreditsCents)} | Rec: ${MoneyFormatter.formatCents(player.totalRechargesCents)}'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: player.hasPendingDebts
                          ? MeVoyTheme.debtNegative
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                if (player.hasLowOrInsufficientBalance)
                  InkWell(
                    onTap: onRequestRechargeTap,
                    child: const Text(
                      '+ Recargar',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: MeVoyTheme.goldAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySeatCard extends StatelessWidget {
  final int seatNumber;
  final String inviteCode;
  final bool canAddByAdmin;
  final VoidCallback onAddTap;

  const _EmptySeatCard({
    required this.seatNumber,
    required this.inviteCode,
    required this.canAddByAdmin,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_seat_outlined,
            color: Colors.white.withValues(alpha: 0.4),
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            'Asiento $seatNumber Libre',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Código: $inviteCode',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          if (canAddByAdmin) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Asignar Jugador'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  final String title;
  final int? cents;
  final String? customValue;
  final bool highlightZeroSum;

  const _SummaryMetricTile({
    required this.title,
    this.cents,
    this.customValue,
    this.highlightZeroSum = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          if (customValue != null)
            Text(
              customValue!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            )
          else if (cents != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  MoneyFormatter.formatCents(cents!),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: highlightZeroSum && cents == 0
                        ? MeVoyTheme.creditPositive
                        : Colors.white,
                  ),
                ),
                if (highlightZeroSum && cents == 0) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: MeVoyTheme.creditPositive,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
