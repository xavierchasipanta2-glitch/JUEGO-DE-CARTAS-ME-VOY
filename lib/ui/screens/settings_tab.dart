import 'package:flutter/material.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/money_badge.dart';

/// Pantalla 10: Configuración de tarifas de juego, reglas de partida y recuperación de estado.
class SettingsTab extends StatefulWidget {
  final AppController controller;

  const SettingsTab({super.key, required this.controller});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late TextEditingController _tableWinCtrl;
  late TextEditingController _aceCtrl;
  late TextEditingController _kingCtrl;
  late TextEditingController _rusoCtrl;
  late TextEditingController _patasCtrl;
  late TextEditingController _maxAcesCtrl;
  late TextEditingController _maxKingsCtrl;

  @override
  void initState() {
    super.initState();
    final t = widget.controller.activeTable!.currentTariffs;
    _tableWinCtrl = TextEditingController(
      text: (t.tableWinCents / 100).toStringAsFixed(2),
    );
    _aceCtrl = TextEditingController(
      text: (t.aceCents / 100).toStringAsFixed(2),
    );
    _kingCtrl = TextEditingController(
      text: (t.kingCents / 100).toStringAsFixed(2),
    );
    _rusoCtrl = TextEditingController(
      text: (t.rusoCents / 100).toStringAsFixed(2),
    );
    _patasCtrl = TextEditingController(
      text: (t.patasCents / 100).toStringAsFixed(2),
    );
    _maxAcesCtrl = TextEditingController(text: '${t.maxAcesPerRound}');
    _maxKingsCtrl = TextEditingController(text: '${t.maxKingsPerRound}');
  }

  @override
  void dispose() {
    _tableWinCtrl.dispose();
    _aceCtrl.dispose();
    _kingCtrl.dispose();
    _rusoCtrl.dispose();
    _patasCtrl.dispose();
    _maxAcesCtrl.dispose();
    _maxKingsCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveTariffs() async {
    final table = widget.controller.activeTable!;
    final current = table.currentTariffs;

    final updated = current.copyWith(
      tableWinCents: MoneyFormatter.parseDollarsToCents(_tableWinCtrl.text) ??
          current.tableWinCents,
      aceCents:
          MoneyFormatter.parseDollarsToCents(_aceCtrl.text) ?? current.aceCents,
      kingCents: MoneyFormatter.parseDollarsToCents(_kingCtrl.text) ??
          current.kingCents,
      rusoCents: MoneyFormatter.parseDollarsToCents(_rusoCtrl.text) ??
          current.rusoCents,
      patasCents: MoneyFormatter.parseDollarsToCents(_patasCtrl.text) ??
          current.patasCents,
      maxAcesPerRound:
          int.tryParse(_maxAcesCtrl.text) ?? current.maxAcesPerRound,
      maxKingsPerRound:
          int.tryParse(_maxKingsCtrl.text) ?? current.maxKingsPerRound,
      updatedAt: DateTime.now().toUtc(),
      updatedByUserId: table.adminUserId,
    );

    await widget.controller.updateTariffs(updated);
  }

  void _restoreDefaults() {
    setState(() {
      _tableWinCtrl.text = '0.50';
      _aceCtrl.text = '0.10';
      _kingCtrl.text = '0.10';
      _rusoCtrl.text = '0.10';
      _patasCtrl.text = '0.20';
      _maxAcesCtrl.text = '8';
      _maxKingsCtrl.text = '8';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final table = ctrl.activeTable!;
    final canEdit = ctrl.isCurrentUserTableAdmin;

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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.settings_suggest_rounded,
                          color: MeVoyTheme.goldAccent,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Panel de Tarifas de Juego',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (canEdit)
                      TextButton(
                        onPressed: _restoreDefaults,
                        child: const Text('Restaurar valores estándar'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Cada partida guarda una copia inmutable de las tarifas vigentes para que los cambios futuros jamás alteren resultados anteriores.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 16),

                _TariffInputField(
                  controller: _tableWinCtrl,
                  label: 'Mesa ganada (cobro a cada rival que perdió)',
                  helper: 'Valor estándar: \$0.50 por cada rival',
                  enabled: canEdit,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TariffInputField(
                        controller: _aceCtrl,
                        label: 'Cada As (\$ por rival)',
                        helper: 'Estándar: \$0.10',
                        enabled: canEdit,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TariffInputField(
                        controller: _kingCtrl,
                        label: 'Cada K (\$ por rival)',
                        helper: 'Estándar: \$0.10',
                        enabled: canEdit,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TariffInputField(
                        controller: _rusoCtrl,
                        label: 'Ruso (\$ por rival)',
                        helper: 'Estándar: \$0.10',
                        enabled: canEdit,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TariffInputField(
                        controller: _patasCtrl,
                        label: 'Patas (\$ por rival)',
                        helper: 'Estándar: \$0.20',
                        enabled: canEdit,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _maxAcesCtrl,
                        enabled: canEdit,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Máx. Ases en la partida',
                          helperText: 'Por defecto: 8 (doble mazo)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxKingsCtrl,
                        enabled: canEdit,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Máx. Reyes (K) en la partida',
                          helperText: 'Por defecto: 8 (doble mazo)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: (!canEdit || ctrl.isBusy) ? null : _saveTariffs,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Guardar Tarifas para Siguientes Partidas'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Seguridad, Sincronización y Recuperación de Sesión
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: MeVoyTheme.creditPositive,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Seguridad, Auditoría y Recuperación',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '• Identificador de Mesa: ${table.tableId}\n'
                  '• Código de Invitación: ${table.inviteCode}\n'
                  '• Versión Transaccional: v${table.version}\n'
                  '• Claves de Idempotencia Procesadas: ${table.processedIdempotencyKeys.length}\n'
                  '• Persistencia de Recuperación: Activa (recupera automáticamente la mesa tras cerrar o reiniciar el teléfono)',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: ctrl.leaveCurrentTableView,
                        icon: const Icon(Icons.meeting_room_outlined),
                        label: const Text('Cambiar de Mesa / Ir a Sala'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: ctrl.signOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Cerrar Sesión'),
                      ),
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
}

class _TariffInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String helper;
  final bool enabled;

  const _TariffInputField({
    required this.controller,
    required this.label,
    required this.helper,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: const Icon(Icons.attach_money_rounded),
      ),
    );
  }
}
