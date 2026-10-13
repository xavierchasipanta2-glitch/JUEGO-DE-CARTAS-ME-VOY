import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configuración de Firebase para «Me Voy — Banco Virtual Multijugador».
///
/// Para conectar con un proyecto Firebase propio en producción:
/// 1. Ejecute `flutterfire configure` en la raíz del proyecto, o
/// 2. Reemplace los valores de `apiKey`, `appId`, `messagingSenderId` y `projectId`
///    con los de su consola de Firebase (y agregue `android/app/google-services.json`).
class DefaultFirebaseOptions {
  static const String _placeholderProjectId = 'REEMPLAZAR_CON_TU_PROJECT_ID';

  /// Indica si las credenciales reales de Firebase han sido configuradas.
  static bool get isConfigured =>
      currentPlatform.projectId != _placeholderProjectId &&
      currentPlatform.apiKey.isNotEmpty &&
      !currentPlatform.apiKey.startsWith('REEMPLAZAR');

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC2rFjvmTH1f1yPcH0pd8ZEljN9tbumc1E',
    appId: '1:512002908776:android:c362a37f1571d7acff91dd',
    messagingSenderId: '512002908776',
    projectId: 'juego-de-cartas-me-voy-60501',
    storageBucket: 'juego-de-cartas-me-voy-60501.firebasestorage.app',
  );
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAiUWB8SOyOcM3elbN9q7t3uPcIIEAsfNE',
    appId: '1:512002908776:web:352abbf694f97cccff91dd',
    messagingSenderId: '512002908776',
    projectId: 'juego-de-cartas-me-voy-60501',
    authDomain: 'juego-de-cartas-me-voy-60501.firebaseapp.com',
    storageBucket: 'juego-de-cartas-me-voy-60501.firebasestorage.app',
  );
}
