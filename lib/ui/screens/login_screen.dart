import 'package:flutter/material.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/legal_notice_banner.dart';

/// Pantalla 1: Inicio de sesión e identificación de jugadores.
class LoginScreen extends StatefulWidget {
  final AppController controller;

  const LoginScreen({super.key, required this.controller});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController(text: 'Jugador 1 (Admin)');
  final _emailController = TextEditingController(text: 'admin@mevoy.app');
  final _passwordController = TextEditingController(text: '123456');

  bool _isRegisterMode = false;
  bool _useEmailPasswordMode = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_useEmailPasswordMode) {
      await widget.controller.signInQuickProfile(
        displayName: name,
        email: email,
      );
      return;
    }

    if (_isRegisterMode) {
      await widget.controller.registerWithEmail(
        email: email,
        password: password,
        displayName: name,
      );
    } else {
      await widget.controller.signInWithEmail(
        email: email,
        password: password,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Encabezado e identidad visual
                  Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [MeVoyTheme.goldAccent, Color(0xFFD99B00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: MeVoyTheme.goldAccent.withValues(alpha: 0.3),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.style_rounded,
                        size: 46,
                        color: Color(0xFF1A1600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ME VOY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: MeVoyTheme.goldAccent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Banco Virtual Multijugador para Rummy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Indicador de motor de sincronización
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ctrl.isUsingCloudFirebase
                                ? Icons.cloud_done_rounded
                                : Icons.sync_lock_rounded,
                            size: 16,
                            color: MeVoyTheme.creditPositive,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              ctrl.isUsingCloudFirebase
                                  ? 'Conectado a Firebase Cloud'
                                  : 'Persistencia Transaccional Activa (Firebase Ready)',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

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
                            Icons.error_outline,
                            color: MeVoyTheme.debtNegative,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ctrl.errorMessage!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment<bool>(
                                value: false,
                                icon: Icon(Icons.flash_on_rounded, size: 18),
                                label: Text('Acceso Rápido'),
                              ),
                              ButtonSegment<bool>(
                                value: true,
                                icon: Icon(Icons.lock_outline_rounded, size: 18),
                                label: Text('Correo y Clave'),
                              ),
                            ],
                            selected: {_useEmailPasswordMode},
                            onSelectionChanged: (selection) {
                              setState(() {
                                _useEmailPasswordMode = selection.first;
                              });
                            },
                          ),
                          const SizedBox(height: 18),

                          if (!_useEmailPasswordMode || _isRegisterMode) ...[
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre o Alias del Jugador',
                                prefixIcon: Icon(Icons.person_outline),
                                hintText: 'Ej. Ana, Carlos, Banquero',
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo Electrónico Identificador',
                              prefixIcon: Icon(Icons.alternate_email),
                              hintText: 'jugador@mevoy.app',
                            ),
                          ),

                          if (_useEmailPasswordMode) ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: Icon(Icons.key_outlined),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: ctrl.isBusy ? null : _submit,
                            icon: ctrl.isBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              !_useEmailPasswordMode
                                  ? 'Ingresar a «Me Voy»'
                                  : (_isRegisterMode
                                      ? 'Crear Cuenta de Jugador'
                                      : 'Iniciar Sesión'),
                            ),
                          ),

                          if (_useEmailPasswordMode) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isRegisterMode = !_isRegisterMode;
                                });
                              },
                              child: Text(
                                _isRegisterMode
                                    ? '¿Ya tienes cuenta? Inicia sesión'
                                    : '¿Primera vez? Registra una cuenta nueva',
                              ),
                            ),
                          ],
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
