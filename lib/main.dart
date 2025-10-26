import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solitaire_universe/apps_standard/splash_screen.dart';
import 'package:solitaire_universe/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const SolitaireUniverseApp());
}

class SolitaireUniverseApp extends StatelessWidget {
  const SolitaireUniverseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solitaire Universe',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
