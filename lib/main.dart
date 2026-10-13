import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/backend_repository.dart';
import 'services/firebase_repository.dart';
import 'services/local_synced_repository.dart';
import 'state/app_controller.dart';
import 'ui/screens/home_shell_screen.dart';
import 'ui/screens/lobby_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  GameBackendRepository repository;
  if (DefaultFirebaseOptions.isConfigured) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      repository = FirebaseGameRepository();
    } catch (_) {
      repository = LocalSyncedGameRepository();
    }
  } else {
    repository = LocalSyncedGameRepository();
  }

  final controller = AppController(repository: repository);
  await controller.initialize();

  runApp(MeVoyApp(controller: controller));
}

class MeVoyApp extends StatelessWidget {
  final AppController controller;

  const MeVoyApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Me Voy — Banco Virtual Rummy',
      debugShowCheckedModeBanner: false,
      theme: MeVoyTheme.darkTheme,
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isInitializing) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (controller.currentUser == null) {
            return LoginScreen(controller: controller);
          }

          if (controller.activeTable == null) {
            return LobbyScreen(controller: controller);
          }

          return HomeShellScreen(controller: controller);
        },
      ),
    );
  }
}
