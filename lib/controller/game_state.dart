import 'package:flutter/foundation.dart';
import 'package:solitaire_universe/model/game_mode.dart';

class GameState extends ChangeNotifier {
  int _totalXP = 0;
  int _coins = 0;
  Map<GameMode, int> _levelProgress = {};
  Map<GameMode, int> _xpPerMode = {};
  List<String> _achievements = [];
  int _dailyChallengesCompleted = 0;
  int _winStreak = 0;
  DateTime? _lastPlayed;

  GameState() {
    _initializeProgress();
  }

  void _initializeProgress() {
    for (var mode in GameMode.values) {
      _levelProgress[mode] = 1;
      _xpPerMode[mode] = 0;
    }
  }

  // Getters
  int get totalXP => _totalXP;
  int get coins => _coins;
  int get winStreak => _winStreak;
  int get dailyChallengesCompleted => _dailyChallengesCompleted;
  List<String> get achievements => List.unmodifiable(_achievements);

  int getLevelForMode(GameMode mode) => _levelProgress[mode] ?? 1;
  int getXPForMode(GameMode mode) => _xpPerMode[mode] ?? 0;

  // Calculate difficulty for a level
  double calculateDifficulty(GameMode mode, int level) {
    const basedifficulty = 1.0;
    return basedifficulty + (level * 0.15) + (0.05 + (level % 10) * 0.01);
  }

  // Add XP and check for level up
  void addXP(GameMode mode, int xp, {int? coinsEarned}) {
    _totalXP += xp;
    _xpPerMode[mode] = (_xpPerMode[mode] ?? 0) + xp;

    if (coinsEarned != null) {
      _coins += coinsEarned;
    }

    // Check for level up (100 XP per level)
    int currentLevel = _levelProgress[mode] ?? 1;
    int modeXP = _xpPerMode[mode] ?? 0;
    int xpNeededForNextLevel = currentLevel * 100;

    if (modeXP >= xpNeededForNextLevel) {
      _levelProgress[mode] = currentLevel + 1;
      _xpPerMode[mode] = modeXP - xpNeededForNextLevel;

      // Bonus coins for level up
      _coins += 50;
    }

    _lastPlayed = DateTime.now();
    notifyListeners();
  }

  // Record a win
  void recordWin(
    GameMode mode, {
    required int moves,
    required int timeInSeconds,
    required int level,
  }) {
    _winStreak++;

    // Calculate score and XP
    int timeBonus = timeInSeconds < 60
        ? 50
        : timeInSeconds < 120
        ? 30
        : 10;
    int moveBonus = moves < 50
        ? 30
        : moves < 100
        ? 20
        : 10;
    int baseXP = level * 5;

    int totalXP = baseXP + timeBonus + moveBonus;
    int coinsEarned = (totalXP / 10).round();

    addXP(mode, totalXP, coinsEarned: coinsEarned);

    // Check for achievements
    _checkAchievements(mode, moves, timeInSeconds);

    notifyListeners();
  }

  // Record a loss
  void recordLoss() {
    _winStreak = 0;
    notifyListeners();
  }

  // Complete daily challenge
  void completeDailyChallenge() {
    _dailyChallengesCompleted++;
    _coins += 100;
    addXP(GameMode.klondike, 50);
    notifyListeners();
  }

  // Check and award achievements
  void _checkAchievements(GameMode mode, int moves, int timeInSeconds) {
    // Fast win achievement
    if (timeInSeconds < 60 && !_achievements.contains('speed_demon')) {
      _achievements.add('speed_demon');
      _coins += 200;
    }

    // Efficient win achievement
    if (moves < 30 && !_achievements.contains('efficiency_expert')) {
      _achievements.add('efficiency_expert');
      _coins += 150;
    }

    // Win streak achievements
    if (_winStreak == 5 && !_achievements.contains('streak_5')) {
      _achievements.add('streak_5');
      _coins += 100;
    }
    if (_winStreak == 10 && !_achievements.contains('streak_10')) {
      _achievements.add('streak_10');
      _coins += 250;
    }
    if (_winStreak == 25 && !_achievements.contains('streak_25')) {
      _achievements.add('streak_25');
      _coins += 500;
    }

    // Mode master achievements
    int level = getLevelForMode(mode);
    if (level >= 10 && !_achievements.contains('${mode.name}_level_10')) {
      _achievements.add('${mode.name}_level_10');
      _coins += 300;
    }
  }

  // Spend coins
  bool spendCoins(int amount) {
    if (_coins >= amount) {
      _coins -= amount;
      notifyListeners();
      return true;
    }
    return false;
  }

  // Reset progress for a mode
  void resetMode(GameMode mode) {
    _levelProgress[mode] = 1;
    _xpPerMode[mode] = 0;
    notifyListeners();
  }

  // Save and load state
  Map<String, dynamic> toJson() {
    return {
      'totalXP': _totalXP,
      'coins': _coins,
      'levelProgress': _levelProgress.map((k, v) => MapEntry(k.name, v)),
      'xpPerMode': _xpPerMode.map((k, v) => MapEntry(k.name, v)),
      'achievements': _achievements,
      'dailyChallengesCompleted': _dailyChallengesCompleted,
      'winStreak': _winStreak,
      'lastPlayed': _lastPlayed?.toIso8601String(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    _totalXP = json['totalXP'] ?? 0;
    _coins = json['coins'] ?? 0;

    if (json['levelProgress'] != null) {
      _levelProgress = (json['levelProgress'] as Map<String, dynamic>).map(
        (k, v) =>
            MapEntry(GameMode.values.firstWhere((m) => m.name == k), v as int),
      );
    }

    if (json['xpPerMode'] != null) {
      _xpPerMode = (json['xpPerMode'] as Map<String, dynamic>).map(
        (k, v) =>
            MapEntry(GameMode.values.firstWhere((m) => m.name == k), v as int),
      );
    }

    _achievements = List<String>.from(json['achievements'] ?? []);
    _dailyChallengesCompleted = json['dailyChallengesCompleted'] ?? 0;
    _winStreak = json['winStreak'] ?? 0;

    if (json['lastPlayed'] != null) {
      _lastPlayed = DateTime.parse(json['lastPlayed']);
    }

    notifyListeners();
  }
}
