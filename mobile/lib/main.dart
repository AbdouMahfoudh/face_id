import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';

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
    const seed = Color(0xFF3949AB);
    return MaterialApp(
      title: 'FaceID École',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      // Wrap the Navigator so every pushed route can reach AppScope.
      builder: (context, navigator) => FutureBuilder<AppState>(
        future: _loading,
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erreur au démarrage :\n${snap.error}',
                      textAlign: TextAlign.center),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return AppScope(state: snap.data!, child: navigator!);
        },
      ),
    );
  }
}
