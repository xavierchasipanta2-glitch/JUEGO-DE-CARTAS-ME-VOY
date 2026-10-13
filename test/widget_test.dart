import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_voy/main.dart';
import 'package:me_voy/services/local_synced_repository.dart';
import 'package:me_voy/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'Flujo completo de interfaz: Inicio de sesión -> Sala -> Crear Mesa de 4 jugadores',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalSyncedGameRepository();
    final controller = AppController(repository: repo);
    await controller.initialize();

    await tester.pumpWidget(MeVoyApp(controller: controller));
    await tester.pumpAndSettle();

    // 1. Verificar pantalla de inicio de sesión
    expect(find.text('ME VOY'), findsOneWidget);
    expect(find.text('Ingresar a «Me Voy»'), findsOneWidget);

    // Ingresar con el perfil rápido
    await tester.tap(find.text('Ingresar a «Me Voy»'));
    await tester.pumpAndSettle();

    // 2. Verificar pantalla de Sala de Mesas (Lobby)
    expect(find.text('Crear Nueva Mesa y Banco Virtual'), findsOneWidget);
    expect(find.text('Unirse a una Mesa con Código'), findsOneWidget);

    // Crear mesa con 4 jugadores listos
    final createBtn = find.text('Crear Mesa y Obtener Código Único');
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    // 3. Verificar que entramos a la Mesa Compartida con los 4 asientos y el código único
    expect(find.text('Mesa (4/4)'), findsOneWidget);
    expect(find.text('ASIENTOS DE LA MESA (TIEMPO REAL)'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });
}
