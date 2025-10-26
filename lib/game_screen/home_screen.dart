import 'package:flutter/material.dart';
import 'package:solitaire_universe/apps_standard/setting_screen.dart';
import 'package:solitaire_universe/controller/game_state.dart';
import 'package:solitaire_universe/model/game_mode.dart';
import 'package:solitaire_universe/game_screen/klondike_game_screen.dart';
import 'package:solitaire_universe/game_screen/spider_game.dart';
import 'package:solitaire_universe/game_screen/tri_peak_game_screen.dart';
import 'package:solitaire_universe/service/audio_service.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final GameState _gameState = GameState();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Start background music when home screen loads
    AudioService.instance.playBackgroundMusic();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1B2A),
              Color(0xFF1B263B),
              Color(0xFF415A77),
              Color(0xFF1B263B),
              Color(0xFF0D1B2A),
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return CustomPaint(
              painter: StarfieldPainter(_animationController.value),
              child: child,
            );
          },
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildWelcomeSection(),
                          const SizedBox(height: 40),
                          _buildGameModesSection(),
                          const SizedBox(height: 30),
                          _buildFooterInfo(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A90E2).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.style, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solitaire',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  Text(
                    'Universe',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '♠️ ♥️ ♣️ ♦️',
            style: TextStyle(
              fontSize: 32,
              letterSpacing: 8,
              shadows: [
                Shadow(color: Colors.white.withOpacity(0.5), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose Your Game',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select from classic solitaire variations',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameModesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 20),
          child: Text(
            'Game Modes',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10),
              ],
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: GameModeConfig.allModes.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildGameModeCard(GameModeConfig.allModes[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGameModeCard(GameModeConfig config) {
    int currentLevel = _gameState.getLevelForMode(config.mode);

    return GestureDetector(
      onTap: () => _launchGame(config),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: config.backgroundGradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: config.primaryColor.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Animated background pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: CardPatternPainter(
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              // Decorative icon
              Positioned(
                bottom: -30,
                right: -30,
                child: Icon(
                  config.icon,
                  size: 150,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Icon container
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(config.icon, color: Colors.white, size: 40),
                    ),
                    const SizedBox(width: 20),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            config.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            config.subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Level $currentLevel',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Play arrow
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events,
            color: Colors.amber,
            size: 32,
            shadows: [
              Shadow(color: Colors.amber.withOpacity(0.5), blurRadius: 10),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Play classic solitaire games',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Challenge yourself with different variations',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _launchGame(GameModeConfig config) {
    // Stop background music when launching a game
    AudioService.instance.stopBackgroundMusic();

    Widget gameScreen;

    // Launch appropriate game based on mode
    if (config.mode == GameMode.tripeaks) {
      gameScreen = TriPeaksGameScreen(config: config, gameState: _gameState);
    } else if (config.mode == GameMode.spider) {
      gameScreen = SpiderGameScreen(config: config, gameState: _gameState);
    } else {
      gameScreen = KlondikeGameScreen(config: config, gameState: _gameState);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => gameScreen),
    ).then((_) {
      // Resume background music when returning to home screen
      AudioService.instance.playBackgroundMusic();
    });
  }
}

class StarfieldPainter extends CustomPainter {
  final double animationValue;
  final List<Star> stars = [];

  StarfieldPainter(this.animationValue) {
    final random = math.Random(42);
    for (int i = 0; i < 150; i++) {
      stars.add(
        Star(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 2.5 + 0.5,
          speed: random.nextDouble() * 0.3 + 0.2,
        ),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (var star in stars) {
      final x = star.x * size.width;
      final y =
          (star.y * size.height + animationValue * star.speed * size.height) %
          size.height;
      final opacity =
          (math.sin(animationValue * math.pi * 2 + star.x * 10) + 1) / 2;

      paint.color = Colors.white.withOpacity(opacity * 0.6);
      canvas.drawCircle(Offset(x, y), star.size, paint);
    }
  }

  @override
  bool shouldRepaint(StarfieldPainter oldDelegate) => true;
}

class Star {
  final double x;
  final double y;
  final double size;
  final double speed;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
  });
}

class CardPatternPainter extends CustomPainter {
  final Color color;

  CardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const spacing = 30.0;
    for (double i = 0; i < size.width; i += spacing) {
      for (double j = 0; j < size.height; j += spacing) {
        canvas.drawRect(Rect.fromLTWH(i, j, 20, 28), paint);
      }
    }
  }

  @override
  bool shouldRepaint(CardPatternPainter oldDelegate) => false;
}
