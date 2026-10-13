import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/recharge_request.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/legal_notice_banner.dart';
import '../widgets/money_badge.dart';

/// Pantalla 7: Solicitud de recarga de créditos internos al Banco Virtual.
class RechargeTab extends StatefulWidget {
  final AppController controller;

  const RechargeTab({super.key, required this.controller});

  @override
  State<RechargeTab> createState() => _RechargeTabState();
}

class _RechargeTabState extends State<RechargeTab> {
  final _amountController = TextEditingController(text: '2.00');
  final _noteController =
      TextEditingController(text: 'Recarga de créditos para continuar jugando');

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitRecharge() async {
    final cents = MoneyFormatter.parseDollarsToCents(_amountController.text);
    if (cents == null || cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese un importe válido mayor a \$0.00'),
        ),
      );
      return;
    }

    await widget.controller.requestRecharge(
      amountCents: cents,
      note: _noteController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final table = ctrl.activeTable!;
    final player = table.participants[ctrl.effectivePlayerId] ??
        table.sortedParticipants.first;

    final playerRequests = table.rechargeRequests
        .where((r) => r.playerId == player.playerId)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.add_card_rounded,
                      color: MeVoyTheme.goldAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Solicitar Recarga — ${player.displayName}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Saldo disponible actual: ${MoneyFormatter.formatCents(player.availableBalanceCents)} • Total recargas: ${MoneyFormatter.formatCents(player.totalRechargesCents)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Importes rápidos:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [100, 200, 500, 1000].map((presetCents) {
                    return ActionChip(
                      label: Text(
                        '+${MoneyFormatter.formatCents(presetCents)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onPressed: () {
                        setState(() {
                          _amountController.text =
                              (presetCents / 100).toStringAsFixed(2);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Importe de recarga (\$)',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo / Nota para el Administrador del Banco',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: ctrl.isBusy ? null : _submitRecharge,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text(
                    'Enviar Solicitud de Recarga al Banco Virtual',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const LegalNoticeBanner(),
        const SizedBox(height: 18),

        Text(
          'MIS SOLICITUDES DE RECARGA (${playerRequests.length})',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: MeVoyTheme.goldSoft,
          ),
        ),
        const SizedBox(height: 8),
        if (playerRequests.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No has realizado solicitudes de recarga en esta sesión.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...playerRequests.map((req) {
            final fmtDate =
                DateFormat('dd/MM HH:mm:ss').format(req.requestedAt.toLocal());
            Color statusColor;
            String statusText;
            switch (req.status) {
              case RechargeRequestStatus.pending:
                statusColor = MeVoyTheme.warningAmber;
                statusText = 'PENDIENTE DE APROBACIÓN';
              case RechargeRequestStatus.approved:
                statusColor = MeVoyTheme.creditPositive;
                statusText = 'APROBADA';
              case RechargeRequestStatus.rejected:
                statusColor = MeVoyTheme.debtNegative;
                statusText = 'RECHAZADA';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  req.isPending
                      ? Icons.hourglass_top_rounded
                      : (req.status == RechargeRequestStatus.approved
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded),
                  color: statusColor,
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      MoneyFormatter.formatCents(req.amountCents),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '${req.note}\nSolicitada: $fmtDate ${req.resolutionReason != null && req.resolutionReason!.isNotEmpty ? "• Respuesta: ${req.resolutionReason}" : ""}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                isThreeLine: true,
              ),
            );
          }),
      ],
    );
  }
}
