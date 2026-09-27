import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'l10n.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FaceIdApp());
}

class FaceIdApp extends StatefulWidget {
  const FaceIdApp({super.key});

  @override
  State<FaceIdApp> createState() => _FaceIdAppState();
}

class _FaceIdAppState extends State<FaceIdApp> {
  late final Future<AppState> _loading = AppState.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppState>(
      future: _loading,
      builder: (context, snap) {
        if (!snap.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            home: _Splash(error: snap.error),
          );
        }
        return AppScope(state: snap.data!, child: const _App());
      },
    );
  }
}

class _App extends StatefulWidget {
  const _App();

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  final _navigator = GlobalKey<NavigatorState>();
  bool _loggedIn = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final loggedIn = state.session != null;
    if (_loggedIn && !loggedIn) {
      // Logged out (possibly by the server): close every open screen.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _navigator.currentState?.popUntil((r) => r.isFirst),
      );
    }
    _loggedIn = loggedIn;
    return MaterialApp(
      navigatorKey: _navigator,
      title: 'FaceID École',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: Locale(state.lang.name),
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: loggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradient),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 96),
            const SizedBox(height: 20),
            const Text(
              'FaceID École',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 28),
            if (error == null)
              const CircularProgressIndicator(color: Colors.white)
            else
              Text(
                '${L10n(AppLang.fr).t('startup_error')}\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
