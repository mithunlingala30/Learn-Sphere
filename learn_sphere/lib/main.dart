import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/mobile/mobile_shell.dart';
import 'screens/setup_required.dart';
import 'screens/web/web_shell.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/native_bridge.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/popup_host.dart';

bool _firebaseConfigured() {
  try {
    return !DefaultFirebaseOptions.currentPlatform.apiKey.startsWith('YOUR_');
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!_firebaseConfigured()) {
    runApp(const SetupRequiredApp());
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LearnSphereApp());
}

class LearnSphereApp extends StatelessWidget {
  const LearnSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<ApiService>(create: (_) => ApiService()),
        Provider<NativeBridge>(create: (_) => NativeBridge()),
        ChangeNotifierProvider<AppState>(
          create: (c) => AppState(
            auth: c.read<AuthService>(),
            firestore: c.read<FirestoreService>(),
            api: c.read<ApiService>(),
            native: c.read<NativeBridge>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Learn Sphere',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AuthGate(),
      ),
    );
  }
}

/// Splash -> sign-in -> the right shell for this screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.authReady) {
      return const Scaffold(
        backgroundColor: LS.space,
        body: Center(child: CircularProgressIndicator(color: LS.marigold)),
      );
    }
    if (app.user == null) return const AuthScreen();
    return const PopupHost(child: ResponsiveShell());
  }
}

/// Phones (and narrow browser windows) get the mobile app; wide browser
/// windows get the full dashboard.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) =>
            kIsWeb && box.maxWidth >= 900 ? const WebShell() : const MobileShell(),
      );
}
