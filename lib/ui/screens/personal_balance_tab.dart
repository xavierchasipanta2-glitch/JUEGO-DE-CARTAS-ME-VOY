import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/ledger_entry.dart';
import '../../models/player_account.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/legal_notice_banner.dart';
import '../widgets/money_badge.dart';

/// Pantalla 4: Saldo personal con desglose contable completo y transferencias internas.
class PersonalBalanceTab extends StatelessWidget {
  final AppController controller;
  final VoidCallback onGoToRecharge;

  const PersonalBalanceTab({
    super.key,
    required this.controller,
    required this.onGoToRecharge,
  });

  @override
  Widget build(BuildContext context) {
    final table = controller.activeTable!;
    final effectiveId = controller.effectivePlayerId;
    final player = table.participants[effectiveId] ??
        table.sortedParticipants.first;

    final personalMovements = table.ledgerEntries
        .where(
          (tx) =>
              tx.fromAccountId == player.playerId ||
              tx.toAccountId == player.playerId,
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Selector de perspectiva de jugador para inspección transparente
        if (table.participants.length > 1)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: MeVoyTheme.goldAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Cuenta consultada:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: player.playerId,
                        items: table.sortedParticipants.map((p) {
                          return DropdownMenuItem<String>(
                            value: p.playerId,
                            child: Text(
                              'Asiento ${p.seatNumber}: ${p.displayName} (${MoneyFormatter.formatCents(p.availableBalanceCents)})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            controller.setActingPlayerOverride(val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),

        // Alerta visual cuando el jugador tiene saldo insuficiente o deudas pendientes
        if (player.hasLowOrInsufficientBalance || player.hasPendingDebts) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MeVoyTheme.warningAmber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MeVoyTheme.warningAmber),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: MeVoyTheme.warningAmber,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.hasPendingDebts
                            ? 'Atención: Tienes deudas pendientes por ${MoneyFormatter.formatCents(player.pendingDebtsCents)}'
                            : 'Alerta: Saldo disponible bajo (${MoneyFormatter.formatCents(player.availableBalanceCents)})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: MeVoyTheme.goldSoft,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Solicita una recarga al Banco Virtual para cubrir futuras liquidaciones automáticas.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onGoToRecharge,
                  child: const Text('Recargar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Tarjeta Principal: SALDO DISPONIBLE vs SALDO NETO DE LA SESIÓN
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SALDO DISPONIBLE EN CRÉDITOS',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            MoneyFormatter.formatCents(
                              player.availableBalanceCents,
                            ),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: MeVoyTheme.goldAccent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Créditos internos utilizables para pagos en la mesa',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 68,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SALDO NETO DE LA SESIÓN',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          MoneyBadge(
                            cents: player.sessionNetBalanceCents,
                            showPlusSign: true,
                            fontSize: 22,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Resultado puro de juego (Ganancias − Pérdidas)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onGoToRecharge,
                        icon: const Icon(Icons.add_card_rounded, size: 18),
                        label: const Text('Solicitar Recarga'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: table.participants.length < 2
                            ? null
                            : () => _showDirectTransferDialog(context, player),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('Transferir Créditos'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Desglose de las 8 métricas contables separadas (Sección 7)
        const Text(
          'DESGLOSE CONTABLE AUDITABLE (CAPITAL VS. JUEGO)',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: MeVoyTheme.goldSoft,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.35,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _MetricCard(
              label: 'Créditos Iniciales',
              cents: player.initialCreditsCents,
              subtitle: 'Asignación al abrir cuenta',
              icon: Icons.flag_outlined,
            ),
            _MetricCard(
              label: 'Total de Recargas',
              cents: player.totalRechargesCents,
              subtitle: 'No cuenta como ganancia',
              icon: Icons.bolt_rounded,
            ),
            _MetricCard(
              label: 'Ganancias Acumuladas',
              cents: player.accumulatedWinningsCents,
              subtitle: 'Rondas con neto a favor',
              icon: Icons.trending_up_rounded,
              valueColor: MeVoyTheme.creditPositive,
            ),
            _MetricCard(
              label: 'Pérdidas Acumuladas',
              cents: player.accumulatedLossesCents,
              subtitle: 'Rondas con neto en contra',
              icon: Icons.trending_down_rounded,
              valueColor: player.accumulatedLossesCents > 0
                  ? MeVoyTheme.debtNegative
                  : Colors.white,
            ),
            _MetricCard(
              label: 'Deudas Pendientes',
              cents: player.pendingDebtsCents,
              subtitle: 'Obligaciones por saldar',
              icon: Icons.pending_actions_rounded,
              valueColor: player.pendingDebtsCents > 0
                  ? MeVoyTheme.debtNegative
                  : Colors.white70,
            ),
            _MetricCard(
              label: 'Premios por Cobrar',
              cents: player.pendingPrizesCents,
              subtitle: 'Pendientes de deudores',
              icon: Icons.redeem_rounded,
              valueColor: player.pendingPrizesCents > 0
                  ? MeVoyTheme.goldAccent
                  : Colors.white70,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const LegalNoticeBanner(compact: true),
        const SizedBox(height: 18),

        // Historial de movimientos de este jugador
        Text(
          'HISTORIAL DE MOVIMIENTOS DE ${player.displayName.toUpperCase()} (${personalMovements.length})',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: MeVoyTheme.goldSoft,
          ),
        ),
        const SizedBox(height: 8),
        if (personalMovements.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Aún no existen movimientos registrados para este jugador.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...personalMovements.map(
            (tx) => _PersonalMovementTile(
              entry: tx,
              perspectivePlayerId: player.playerId,
            ),
          ),
      ],
    );
  }

  Future<void> _showDirectTransferDialog(
    BuildContext context,
    PlayerAccount sender,
  ) async {
    final table = controller.activeTable!;
    final rivals = table.sortedParticipants
        .where((p) => p.playerId != sender.playerId)
        .toList();
    if (rivals.isEmpty) return;

    String selectedReceiverId = rivals.first.playerId;
    final amountCtrl = TextEditingController(text: '0.50');
    final reasonCtrl =
        TextEditingController(text: 'Transferencia voluntaria de créditos');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Transferir desde ${sender.displayName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Saldo disponible: ${MoneyFormatter.formatCents(sender.availableBalanceCents)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: MeVoyTheme.goldSoft,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReceiverId,
                    decoration: const InputDecoration(
                      labelText: 'Jugador Destino',
                    ),
                    items: rivals.map((r) {
                      return DropdownMenuItem<String>(
                        value: r.playerId,
                        child: Text('Asiento ${r.seatNumber}: ${r.displayName}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedReceiverId = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Importe a transferir (\$)',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motivo de la transferencia',
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
                    final cents =
                        MoneyFormatter.parseDollarsToCents(amountCtrl.text) ??
                            0;
                    Navigator.of(ctx).pop();
                    await controller.executeInternalTransfer(
                      fromPlayerId: sender.playerId,
                      toPlayerId: selectedReceiverId,
                      amountCents: cents,
                      reason: reasonCtrl.text,
                    );
                  },
                  child: const Text('Confirmar Transferencia'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int cents;
  final String subtitle;
  final IconData icon;
  final Color? valueColor;

  const _MetricCard({
    required this.label,
    required this.cents,
    required this.subtitle,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MeVoyTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: valueColor ?? MeVoyTheme.goldSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  MoneyFormatter.formatCents(cents),
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: valueColor ?? Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalMovementTile extends StatelessWidget {
  final LedgerEntry entry;
  final String perspectivePlayerId;

  const _PersonalMovementTile({
    required this.entry,
    required this.perspectivePlayerId,
  });

  @override
  Widget build(BuildContext context) {
    final isIncoming = entry.toAccountId == perspectivePlayerId;
    final signedCents = isIncoming ? entry.amountCents : -entry.amountCents;
    final dateFmt = DateFormat('dd/MM HH:mm:ss').format(entry.createdAt.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: isIncoming
              ? MeVoyTheme.creditPositive.withValues(alpha: 0.16)
              : MeVoyTheme.debtNegative.withValues(alpha: 0.16),
          child: Icon(
            isIncoming ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 18,
            color: isIncoming
                ? MeVoyTheme.creditPositive
                : MeVoyTheme.debtNegative,
          ),
        ),
        title: Text(
          '${entry.typeDisplayLabel} • ${entry.fromAccountName} → ${entry.toAccountName}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: Text(
          '${entry.reason}\n$dateFmt • ID: ${entry.entryId}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
        isThreeLine: true,
        trailing: MoneyBadge(
          cents: signedCents,
          showPlusSign: true,
          fontSize: 14,
        ),
      ),
    );
  }
}
