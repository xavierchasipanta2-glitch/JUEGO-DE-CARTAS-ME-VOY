import 'package:flutter/material.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/legal_notice_banner.dart';
import '../widgets/money_badge.dart';

/// Pantalla 2: Crear mesa de juego como Administrador o unirse mediante código de invitación único.
class LobbyScreen extends StatefulWidget {
  final AppController controller;

  const LobbyScreen({super.key, required this.controller});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _tableNameController =
      TextEditingController(text: 'Mesa Rummy Entre Amigos');
  final _initialCreditsController = TextEditingController(text: '5.00');
  final _inviteCodeController = TextEditingController();
  bool _autoCreateFourPlayers = true;

  @override
  void dispose() {
    _tableNameController.dispose();
    _initialCreditsController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateTable() async {
    final cents =
        MoneyFormatter.parseDollarsToCents(_initialCreditsController.text) ??
            500;
    await widget.controller.createTable(
      tableName: _tableNameController.text,
      initialCreditsCents: cents,
      autoCreateDemoPlayers: _autoCreateFourPlayers,
    );
  }

  Future<void> _handleJoinByCode() async {
    final code = _inviteCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    await widget.controller.joinTableByCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final user = ctrl.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ME VOY — Sala de Mesas',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Chip(
                avatar: const Icon(Icons.person, size: 16),
                label: Text(user.displayName),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: ctrl.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ctrl.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MeVoyTheme.debtNegative.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MeVoyTheme.debtNegative),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: MeVoyTheme.debtNegative,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(ctrl.errorMessage!)),
                          IconButton(
                            onPressed: ctrl.clearMessages,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // SECCIÓN A: UNIRSE A UNA MESA MEDIANTE CÓDIGO ÚNICO
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.qr_code_scanner_rounded,
                                color: MeVoyTheme.goldAccent,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Unirse a una Mesa con Código',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ingresa el código de invitación de 6 caracteres compartido por el administrador de la mesa.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _inviteCodeController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Código de invitación',
                                    hintText: 'EJ: MV84K9',
                                    prefixIcon: Icon(Icons.vpn_key_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed:
                                    ctrl.isBusy ? null : _handleJoinByCode,
                                icon: const Icon(Icons.meeting_room_rounded),
                                label: const Text('Unirse'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SECCIÓN B: CREAR UNA MESA NUEVA COMO ADMINISTRADOR Y BANCO
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.account_balance_rounded,
                                color: MeVoyTheme.goldAccent,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Crear Nueva Mesa y Banco Virtual',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Serás el administrador de la mesa y del Banco Virtual. Obtendrás un código único para conectar hasta 4 jugadores en tiempo real.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _tableNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la Mesa',
                              prefixIcon: Icon(Icons.table_restaurant_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _initialCreditsController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText:
                                  'Créditos Iniciales por Jugador (USD \$)',
                              prefixIcon: Icon(Icons.attach_money_rounded),
                              helperText:
                                  'Se registrará como asignación inicial auditable (distinta de las ganancias).',
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _autoCreateFourPlayers,
                            activeThumbColor: MeVoyTheme.goldAccent,
                            onChanged: (val) {
                              setState(() {
                                _autoCreateFourPlayers = val;
                              });
                            },
                            title: const Text(
                              'Inicializar con los 4 asientos listos',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              _autoCreateFourPlayers
                                  ? 'Crea las 4 cuentas en la mesa de inmediato (puedes alternar entre los 4 jugadores o conectar otros teléfonos con el código).'
                                  : 'Inicia solo con tu asiento de Administrador y espera a que los demás ingresen con el código.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tarifas Iniciales Estándar (Configurables en la mesa):',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: MeVoyTheme.goldSoft,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '• Mesa ganada: \$0.50 por rival  • Cada As: \$0.10  • Cada K: \$0.10  • Ruso: \$0.10  • Patas: \$0.20',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: ctrl.isBusy ? null : _handleCreateTable,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            label: const Text(
                              'Crear Mesa y Obtener Código Único',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const LegalNoticeBanner(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
