import 'package:flutter/material.dart';
import 'package:solitaire_universe/theme/app_theme.dart';

enum GameMode { klondike, spider, freecell, pyramid, tripeaks }

class GameModeConfig {
  final GameMode mode;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final IconData icon;
  final String description;
  final List<Color> backgroundGradient;

  const GameModeConfig({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.icon,
    required this.description,
    required this.backgroundGradient,
  });

  static const klondike = GameModeConfig(
    mode: GameMode.klondike,
    title: 'Klondike',
    subtitle: 'Classic Solitaire',
    primaryColor: AppTheme.klondikeBlue,
    icon: Icons.ac_unit,
    description: 'Standard Solitaire with smooth card animations',
    backgroundGradient: [Color(0xFF4A90E2), Color(0xFF50C9E9)],
  );

  static const spider = GameModeConfig(
    mode: GameMode.spider,
    title: 'Spider',
    subtitle: 'Spider Galaxy',
    primaryColor: AppTheme.spiderPurple,
    icon: Icons.blur_circular,
    description: 'Assemble sequences in descending order',
    backgroundGradient: [Color(0xFF6B46C1), Color(0xFF9B4DCA)],
  );

  static const freecell = GameModeConfig(
    mode: GameMode.freecell,
    title: 'FreeCell',
    subtitle: 'FreeCell Royale',
    primaryColor: AppTheme.freecellRed,
    icon: Icons.casino,
    description: 'Strategy-based play with free cells',
    backgroundGradient: [Color(0xFFC62828), Color(0xFFE53935)],
  );

  static const pyramid = GameModeConfig(
    mode: GameMode.pyramid,
    title: 'Pyramid',
    subtitle: 'Pyramid Quest',
    primaryColor: AppTheme.pyramidOrange,
    icon: Icons.terrain,
    description: 'Match pairs summing to 13',
    backgroundGradient: [Color(0xFFE65100), Color(0xFFF57C00)],
  );

  static const tripeaks = GameModeConfig(
    mode: GameMode.tripeaks,
    title: 'TriPeaks',
    subtitle: 'TriPeaks Adventure',
    primaryColor: AppTheme.tripeaksGreen,
    icon: Icons.landscape,
    description: 'Clear the tableau with cascading chains',
    backgroundGradient: [Color(0xFF2E7D32), Color(0xFF43A047)],
  );

  static List<GameModeConfig> get allModes => [
    klondike,
    spider,
    // freecell,
    // pyramid,
    tripeaks,
  ];

  static GameModeConfig fromMode(GameMode mode) {
    switch (mode) {
      case GameMode.klondike:
        return klondike;
      case GameMode.spider:
        return spider;
      case GameMode.freecell:
        return freecell;
      case GameMode.pyramid:
        return pyramid;
      case GameMode.tripeaks:
        return tripeaks;
    }
  }
}
