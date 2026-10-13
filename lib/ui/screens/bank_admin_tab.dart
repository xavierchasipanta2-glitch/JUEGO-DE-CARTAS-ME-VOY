import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_table.dart';
import '../../models/player_account.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/legal_notice_banner.dart';
import '../widgets/money_badge.dart';

/// Pantalla 9: Panel del Banco Virtual y del Administrador de la Mesa.
class BankAdminTab extends StatefulWidget {
  final AppController controller;

  const BankAdminTab({super.key, required this.controller});

  @override
  State<BankAdminTab> createState() => _BankAdminTabState();
}

class _BankAdminTabState extends State<BankAdminTab> {
  String? _selectedTargetPlayerId;
  final _amountController = TextEditingController(text: '2.00');
  final _reasonController = TextEditingController(
    text: 'Asignación / Ajuste autorizado por el Banco Virtual',
  );
  bool _isInitialAllocationType = true;
  bool _isNegativeAdjustment = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final table = ctrl.activeTable!;
    final players = table.sortedParticipants;
    final pendingRecharges =
        table.rechargeRequests.where((r) => r.isPending).toList();

    final targetId = (_selectedTargetPlayerId != null &&
            table.participants.containsKey(_selectedTargetPlayerId))
        ? _selectedTargetPlayerId!
        : players.first.playerId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Resumen Financiero Global del Banco Virtual
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_rounded,
                      color: MeVoyTheme.goldAccent,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Panel del Banco Virtual y Administración',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Administrador responsable: ${table.adminDisplayName} • Libro mayor inmutable (${table.ledgerEntries.length} registros)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showExportDialog(context),
                      icon: const Icon(Icons.ios_share_rounded, size: 16),
                      label: const Text('Exportar'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const LegalNoticeBanner(compact: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Solicitudes de Recarga Pendientes de Aprobación
        Card(
          color: pendingRecharges.isNotEmpty
              ? const Color(0xFF2E260D)
              : MeVoyTheme.cardSurface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      color: pendingRecharges.isNotEmpty
                          ? MeVoyTheme.warningAmber
                          : Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Solicitudes de Recarga Pendientes (${pendingRecharges.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (pendingRecharges.isEmpty)
                  Text(
                    'No hay solicitudes de recarga pendientes por aprobar.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  )
                else
                  ...pendingRecharges.map((req) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MeVoyTheme.warningAmber.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${req.playerName} solicita ${MoneyFormatter.formatCents(req.amountCents)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  req.note,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: (!ctrl.isCurrentUserTableAdmin ||
                                    ctrl.isBusy)
                                ? null
                                : () => ctrl.resolveRechargeRequest(
                                      requestId: req.requestId,
                                      approve: false,
                                      reason: 'Rechazada por el administrador',
                                    ),
                            child: const Text(
                              'Rechazar',
                              style: TextStyle(color: MeVoyTheme.debtNegative),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton.icon(
                            onPressed: (!ctrl.isCurrentUserTableAdmin ||
                                    ctrl.isBusy)
                                ? null
                                : () => ctrl.resolveRechargeRequest(
                                      requestId: req.requestId,
                                      approve: true,
                                      reason:
                                          'Recarga aprobada y acreditada por el banco',
                                    ),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Aprobar'),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Emisión de Créditos Iniciales o Ajustes Auditables
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.edit_document,
                      color: MeVoyTheme.goldAccent,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Asignar Créditos o Realizar Ajuste Auditable',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Ningún administrador puede borrar movimientos ya confirmados. Cualquier corrección se registra como un nuevo asiento auditable con fecha, importe, responsable y motivo.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.savings_outlined, size: 18),
                      label: Text('Asignar Créditos Iniciales'),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.tune_rounded, size: 18),
                      label: Text('Ajuste Correctivo (+/-)'),
                    ),
                  ],
                  selected: {_isInitialAllocationType},
                  onSelectionChanged: (sel) {
                    setState(() {
                      _isInitialAllocationType = sel.first;
                      if (_isInitialAllocationType) {
                        _isNegativeAdjustment = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: targetId,
                  decoration: const InputDecoration(
                    labelText: 'Jugador Destinatario',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: players.map((p) {
                    return DropdownMenuItem<String>(
                      value: p.playerId,
                      child: Text(
                        'Asiento ${p.seatNumber}: ${p.displayName} (Disp: ${MoneyFormatter.formatCents(p.availableBalanceCents)})',
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedTargetPlayerId = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (!_isInitialAllocationType) ...[
                  Row(
                    children: [
                      const Text(
                        'Sentido del ajuste:',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        selected: !_isNegativeAdjustment,
                        label: const Text('+ Sumar al saldo'),
                        onSelected: (_) =>
                            setState(() => _isNegativeAdjustment = false),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        selected: _isNegativeAdjustment,
                        label: const Text('− Descontar del saldo'),
                        onSelected: (_) =>
                            setState(() => _isNegativeAdjustment = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Importe (\$)',
                          prefixIcon: Icon(Icons.attach_money_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Motivo obligatorio de auditoría',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: (!ctrl.isCurrentUserTableAdmin || ctrl.isBusy)
                      ? null
                      : () async {
                          final rawCents = MoneyFormatter.parseDollarsToCents(
                                _amountController.text,
                              ) ??
                              0;
                          if (rawCents <= 0) return;
                          final delta = (!_isInitialAllocationType &&
                                  _isNegativeAdjustment)
                              ? -rawCents
                              : rawCents;
                          await ctrl.applyAdminCreditAdjustment(
                            targetPlayerId: targetId,
                            deltaCents: delta,
                            reason: _reasonController.text,
                            isInitialCreditAllocation: _isInitialAllocationType,
                          );
                        },
                  icon: const Icon(Icons.verified_user_rounded),
                  label: Text(
                    _isInitialAllocationType
                        ? 'Registrar Asignación de Créditos en Libro Mayor'
                        : 'Ejecutar Ajuste Auditable en Libro Mayor',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 4. Tabla de Cuentas de Jugadores y Cierre de Mesa
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Estado de Cuentas de Participantes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...players.map((p) => _BankAccountRow(player: p)),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        table.status == TableStatus.closed
                            ? 'Esta mesa se encuentra cerrada.'
                            : 'Cerrar la mesa bloquea nuevas partidas y conserva todo el historial para exportación.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (table.status != TableStatus.closed &&
                        ctrl.isCurrentUserTableAdmin)
                      OutlinedButton.icon(
                        onPressed: ctrl.isBusy
                            ? null
                            : () => ctrl.closeTableSession(),
                        icon: const Icon(Icons.lock_outline_rounded, size: 18),
                        label: const Text('Cerrar Mesa'),
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

  Future<void> _showExportDialog(BuildContext context) async {
    final textReport = widget.controller.buildExportReportText();
    final jsonReport = widget.controller.buildExportJson();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Exportar Resultados y Auditoría Contable'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                textReport,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonReport));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('JSON completo copiado al portapapeles.'),
                  ),
                );
              },
              icon: const Icon(Icons.data_object_rounded, size: 18),
              label: const Text('Copiar JSON'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: textReport));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Reporte auditable copiado al portapapeles.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              label: const Text('Copiar Reporte'),
            ),
          ],
        );
      },
    );
  }
}

class _BankAccountRow extends StatelessWidget {
  final PlayerAccount player;

  const _BankAccountRow({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white12,
            child: Text(
              '${player.seatNumber}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Inicial: ${MoneyFormatter.formatCents(player.initialCreditsCents)} • '
                  'Recargas: ${MoneyFormatter.formatCents(player.totalRechargesCents)} • '
                  'Ajustes: ${MoneyFormatter.formatCents(player.adminAdjustmentsCents)} • '
                  'Ganancias: ${MoneyFormatter.formatCents(player.accumulatedWinningsCents)} • '
                  'Pérdidas: ${MoneyFormatter.formatCents(player.accumulatedLossesCents)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Disp: ${MoneyFormatter.formatCents(player.availableBalanceCents)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: MeVoyTheme.goldAccent,
                ),
              ),
              Text(
                'Neto: ${MoneyFormatter.formatCents(player.sessionNetBalanceCents, showPlusSign: true)}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: player.sessionNetBalanceCents >= 0
                      ? MeVoyTheme.creditPositive
                      : MeVoyTheme.debtNegative,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
