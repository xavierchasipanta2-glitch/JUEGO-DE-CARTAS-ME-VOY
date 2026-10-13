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
    apiKey: 'REEMPLAZAR_CON_TU_API_KEY_ANDROID',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: _placeholderProjectId,
    storageBucket: 'REEMPLAZAR_CON_TU_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REEMPLAZAR_CON_TU_API_KEY_WEB',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: _placeholderProjectId,
    authDomain: 'REEMPLAZAR_CON_TU_PROJECT_ID.firebaseapp.com',
    storageBucket: 'REEMPLAZAR_CON_TU_PROJECT_ID.appspot.com',
  );
}
