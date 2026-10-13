# ME VOY — Banco Virtual Multijugador para Rummy

Aplicación Android desarrollada en **Flutter + Firebase** para administrar créditos contables internos, calcular premios de cartas, compensar deudas opuestas entre parejas y ejecutar planes de liquidación atómica en tiempo real entre 2 y 4 jugadores.

---

## 1. Arquitectura y Estructura del Proyecto

```text
me_voy/
├── firebase.json                        # Configuración de Firestore, Cloud Functions y Emulators
├── firestore.rules                      # Reglas de seguridad de Firestore (libro mayor append-only)
├── firestore.indexes.json               # Índices compuestos para búsqueda por código y auditoría
├── functions/
│   ├── package.json                     # Dependencias Node.js de Firebase Cloud Functions
│   └── index.js                         # Validación financiera en servidor y liquidación atómica
├── lib/
│   ├── main.dart                        # Inicialización, recuperación automática de sesión y ruteo
│   ├── firebase_options.dart            # Configuración de credenciales de Firebase
│   ├── models/
│   │   ├── tariff_config.dart           # Tarifas configurables e instantánea congelada por partida
│   │   ├── player_account.dart          # Cuenta individual (separa capital, ganancias/pérdidas y pendientes)
│   │   ├── round_models.dart            # Premios brutos, obligaciones, compensación bilateral y liquidación
│   │   ├── ledger_entry.dart            # Libro mayor inmutable (identificador, motivo, cálculo origen)
│   │   ├── recharge_request.dart        # Solicitudes de recarga con flujo de aprobación/rechazo
│   │   └── game_table.dart              # Fuente única de datos de la mesa compartida
│   ├── engine/
│   │   └── settlement_engine.dart       # Motor determinista (sin IA, en centavos enteros)
│   ├── services/
│   │   ├── backend_repository.dart      # Contrato y procesador transaccional (TransactionalTableProcessor)
│   │   ├── firebase_repository.dart     # Sincronización real en Cloud Firestore + Firebase Auth
│   │   └── local_synced_repository.dart # Persistencia transaccional local con recuperación de estado
│   ├── state/
│   │   └── app_controller.dart          # Estado reactivo, suscripciones en tiempo real y exportación
│   └── ui/
│       ├── theme/app_theme.dart         # Tema visual de paño de Rummy de alto contraste
│       ├── widgets/                     # Formato monetario a 2 decimales y avisos normativos
│       └── screens/                     # 10 pantallas completas de operación
└── test/
    ├── settlement_engine_test.dart      # Pruebas unitarias deterministas del motor de cálculo
    ├── bank_and_table_test.dart         # Pruebas funcionales de 4 jugadores, banco e idempotencia
    └── widget_test.dart                 # Prueba funcional de flujo de interfaz
```

---

## 2. Instrucciones para Configurar Firebase

1. **Crear proyecto en Firebase Console**:
   - Ingrese a [Firebase Console](https://console.firebase.google.com/) y cree un proyecto nuevo.
   - Habilite **Authentication** (proveedores: *Correo electrónico/Contraseña* y *Anónimo*).
   - Habilite **Cloud Firestore** en modo producción.

2. **Vincular la aplicación Flutter con Firebase**:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Esto actualizará automáticamente `lib/firebase_options.dart` y colocará `android/app/google-services.json`.

3. **Desplegar Reglas de Seguridad, Índices y Cloud Functions**:
   ```bash
   cd functions
   npm install
   cd ..
   firebase deploy --only firestore:rules,firestore:indexes,functions
   ```

> **Nota de ejecución inmediata**: Mientras `lib/firebase_options.dart` conserve las claves de marcador, la aplicación activa automáticamente `LocalSyncedGameRepository`, que persiste todas las transacciones localmente en el dispositivo y permite probar las 4 cuentas de jugadores, el banco virtual y el motor de liquidación de inmediato.

---

## 3. Instrucciones para Generar el APK Instalable

Desde el directorio del proyecto (`C:\Users\Usuario\.gemini\antigravity\scratch\me_voy`), ejecute:

```bash
# 1. Descargar dependencias
flutter pub get

# 2. Ejecutar análisis estático y pruebas automatizadas
flutter analyze
flutter test

# 3. Compilar el APK de producción (Release)
flutter build apk --release
```

El archivo APK instalable se generará en:
`build/app/outputs/flutter-apk/app-release.apk`

Para un APK dividido por arquitectura (menor tamaño de descarga):
```bash
flutter build apk --split-per-abi --release
```

---

## 4. Seguridad, Idempotencia y Recuperación ante Fallos

- **Precisión en centavos enteros**: Todos los importes se almacenan y calculan como enteros en centavos (`int`), eliminando errores de coma flotante.
- **Idempotencia**: Cada asignación inicial (`init_<tableId>_<userId>`), solicitud/resolución de recarga (`resolve_recharge_<requestId>`), transferencia (`tr_<uuid>`) y liquidación de ronda (`stl_<roundId>`) registra su clave en `processedIdempotencyKeys`. Si una petición se repite por reconexión, es rechazada sin duplicar cargos.
- **Libro mayor Append-Only**: Las reglas de Firestore (`isLedgerAppendOnly`) y el procesador transaccional impiden encoger o borrar entradas confirmadas en `ledgerEntries`. Las correcciones administrativas se registran mediante asientos `adminAdjustment` con motivo y responsable.
- **Recuperación tras reinicio**: Al abrir la aplicación, `AppController.initialize()` restaura la sesión del usuario y vuelve a suscribirse en tiempo real a la mesa activa almacenada.
