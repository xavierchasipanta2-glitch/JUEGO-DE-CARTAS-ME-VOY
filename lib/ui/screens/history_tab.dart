import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/ledger_entry.dart';
import '../../models/round_models.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/money_badge.dart';

/// Pantalla 8: Historial de partidas cerradas y libro mayor de movimientos auditables.
class HistoryTab extends StatefulWidget {
  final AppController controller;

  const HistoryTab({super.key, required this.controller});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  bool _showMovementsLedger = false;
  LedgerMovementType? _filterType;

  @override
  Widget build(BuildContext context) {
    final table = widget.controller.activeTable!;
    final rounds = table.completedRounds;
    final allMovements = table.ledgerEntries;
    final filteredMovements = _filterType == null
        ? allMovements
        : allMovements.where((m) => m.type == _filterType).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment<bool>(
              value: false,
              icon: const Icon(Icons.history_edu_rounded, size: 18),
              label: Text('Partidas Cerradas (${rounds.length})'),
            ),
            ButtonSegment<bool>(
              value: true,
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: Text('Libro Mayor (${allMovements.length})'),
            ),
          ],
          selected: {_showMovementsLedger},
          onSelectionChanged: (sel) {
            setState(() {
              _showMovementsLedger = sel.first;
            });
          },
        ),
        const SizedBox(height: 14),

        if (!_showMovementsLedger) ...[
          if (rounds.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no se han cerrado partidas en esta sesión. Cuando se liquide una ronda, aparecerá aquí con su copia congelada de tarifas y su plan de liquidación.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...rounds.map((r) => _CompletedRoundHistoryCard(round: r)),
        ] else ...[
          // Filtros por tipo de movimiento contable
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  selected: _filterType == null,
                  label: const Text('Todos'),
                  onSelected: (_) => setState(() => _filterType = null),
                ),
                const SizedBox(width: 8),
                ...LedgerMovementType.values.map((t) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _filterType == t,
                      label: Text(_labelForType(t)),
                      onSelected: (_) {
                        setState(() {
                          _filterType = _filterType == t ? null : t;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (filteredMovements.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay movimientos que coincidan con el filtro seleccionado.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...filteredMovements.map((tx) => _LedgerAuditCard(entry: tx)),
        ],
      ],
    );
  }

  String _labelForType(LedgerMovementType t) {
    switch (t) {
      case LedgerMovementType.initialAllocation:
        return 'Asignación inicial';
      case LedgerMovementType.approvedRecharge:
        return 'Recargas';
      case LedgerMovementType.roundSettlementTransfer:
        return 'Liquidaciones';
      case LedgerMovementType.externalPaymentVerified:
        return 'Pagos externos';
      case LedgerMovementType.directPeerTransfer:
        return 'Transferencias';
      case LedgerMovementType.adminAdjustment:
        return 'Ajustes';
    }
  }
}

class _CompletedRoundHistoryCard extends StatelessWidget {
  final GameRound round;

  const _CompletedRoundHistoryCard({required this.round});

  @override
  Widget build(BuildContext context) {
    final calc = round.calculationResult;
    final winner = round.playerInputs.values
        .where((p) => p.isWinner)
        .map((p) => p.displayName)
        .firstOrNull;
    final closedFmt = round.closedAt != null
        ? DateFormat('dd/MM/yyyy HH:mm:ss').format(round.closedAt!.toLocal())
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: MeVoyTheme.goldAccent.withValues(alpha: 0.2),
          foregroundColor: MeVoyTheme.goldAccent,
          child: Text(
            '#${round.roundNumber}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        title: Text(
          'Partida #${round.roundNumber} — Ganador: ${winner ?? "N/A"}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Cerrada: $closedFmt • Liquidación: ${round.settlementId ?? "N/A"}',
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          Text(
            'Tarifas utilizadas en esta partida (Copia inmutable): '
            'Mesa ${MoneyFormatter.formatCents(round.tariffSnapshot.tableWinCents)} | '
            'As ${MoneyFormatter.formatCents(round.tariffSnapshot.aceCents)} | '
            'K ${MoneyFormatter.formatCents(round.tariffSnapshot.kingCents)} | '
            'Ruso ${MoneyFormatter.formatCents(round.tariffSnapshot.rusoCents)} | '
            'Patas ${MoneyFormatter.formatCents(round.tariffSnapshot.patasCents)}',
            style: const TextStyle(
              fontSize: 11.5,
              color: MeVoyTheme.goldSoft,
            ),
          ),
          const SizedBox(height: 8),
          if (calc != null) ...[
            ...calc.grossBreakdowns.map((g) {
              final net = calc.netBalancesByPlayerCents[g.playerId] ?? 0;
              final pInput = round.playerInputs[g.playerId];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${g.displayName}: ${pInput?.isWinner == true ? "[GANÓ MESA] " : ""}'
                        'As:${pInput?.acesCount ?? 0} K:${pInput?.kingsCount ?? 0} '
                        'Ruso:${pInput?.rusosCount ?? 0} Patas:${pInput?.patasCount ?? 0} '
                        '(Bruto: ${MoneyFormatter.formatCents(g.grossTotalCents)})',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    MoneyBadge(
                      cents: net,
                      showPlusSign: true,
                      fontSize: 13,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            const Text(
              'Plan de liquidación ejecutado:',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
            const SizedBox(height: 4),
            ...calc.optimizedSettlementPlan.map(
              (tr) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• ${tr.fromPlayerName} → ${tr.toPlayerName}: ${MoneyFormatter.formatCents(tr.amountCents)} (Ref: ${tr.ledgerTransactionId ?? tr.itemId})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LedgerAuditCard extends StatelessWidget {
  final LedgerEntry entry;

  const _LedgerAuditCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final fmtDate =
        DateFormat('dd/MM/yyyy HH:mm:ss').format(entry.createdAt.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: MeVoyTheme.goldAccent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.typeDisplayLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: MeVoyTheme.goldAccent,
                    ),
                  ),
                ),
                MoneyBadge(
                  cents: entry.amountCents,
                  fontSize: 14.5,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Origen: ${entry.fromAccountName}  →  Destino: ${entry.toAccountName}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Motivo: ${entry.reason}',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${entry.entryId} • Fecha: $fmtDate • Autorizado por: ${entry.authorizedByUserName}'
              '${entry.roundNumber != null ? " • Partida #${entry.roundNumber}" : ""}'
              '${entry.calculationReferenceId != null ? " • Ref: ${entry.calculationReferenceId}" : ""}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
