import 'package:flutter/material.dart';
import 'package:solitaire_universe/controller/game_state.dart';
import 'package:solitaire_universe/manager/deck_manager.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:solitaire_universe/model/game_mode.dart';
import 'package:solitaire_universe/model/playing_card.dart';
import 'package:solitaire_universe/service/audio_service.dart';

class TriPeaksGameScreen extends StatefulWidget {
  final GameModeConfig config;
  final GameState gameState;

  const TriPeaksGameScreen({
    Key? key,
    required this.config,
    required this.gameState,
  }) : super(key: key);

  @override
  State<TriPeaksGameScreen> createState() => _TriPeaksGameScreenState();
}

class _TriPeaksGameScreenState extends State<TriPeaksGameScreen>
    with TickerProviderStateMixin {
  Map<int, PlayingCard?> cardPositions = {};
  List<PlayingCard> stock = [];
  List<PlayingCard> waste = [];

  int moves = 0;
  int score = 0;
  int streak = 0;
  late Timer _timer;
  int _seconds = 0;
  bool _isGameWon = false;
  int? _hintPosition;

  late AnimationController _moveController;
  late AnimationController _flipController;
  Animation<Offset>? _moveAnimation;

  int? _animatingPosition;
  GlobalKey? _animatingCardKey;
  Offset? _startPosition;
  Offset? _endPosition;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _startGame();
  }

  @override
  void dispose() {
    _timer.cancel();
    _moveController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      cardPositions = {};
      moves = 0;
      score = 0;
      streak = 0;
      _seconds = 0;
      _isGameWon = false;
      _hintPosition = null;
      _animatingPosition = null;
    });

    List<PlayingCard> deck = DeckManager.createStandardDeck();
    deck = DeckManager.shuffle(deck, seed: DeckManager.generateSeed());

    for (int i = 0; i < 28 && i < deck.length; i++) {
      PlayingCard card = deck[i];
      card.isFaceUp = _isBottomRow(i);
      cardPositions[i] = card;
    }

    stock = deck.sublist(28);

    if (stock.isNotEmpty) {
      PlayingCard firstCard = stock.removeLast();
      firstCard.isFaceUp = true;
      waste.add(firstCard);
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isGameWon) setState(() => _seconds++);
    });
  }

  bool _isBottomRow(int position) {
    return [6, 7, 8, 15, 16, 17, 24, 25, 26, 27].contains(position);
  }

  List<int> _getCoveringCards(int position) {
    Map<int, List<int>> coveringMap = {
      0: [1, 2],
      1: [3, 4],
      2: [4, 5],
      3: [6, 7],
      4: [7, 8],
      5: [8, 15],
      9: [10, 11],
      10: [12, 13],
      11: [13, 14],
      12: [15, 16],
      13: [16, 17],
      14: [17, 24],
      18: [19, 20],
      19: [21, 22],
      20: [22, 23],
      21: [24, 25],
      22: [25, 26],
      23: [26, 27],
    };
    return coveringMap[position] ?? [];
  }

  bool _isCardAccessible(int position) {
    if (cardPositions[position] == null) return false;
    List<int> coveringPositions = _getCoveringCards(position);
    for (int pos in coveringPositions) {
      if (cardPositions[pos] != null) return false;
    }
    return true;
  }

  bool _canPlaceCard(PlayingCard card) {
    if (waste.isEmpty) return false;
    PlayingCard wasteCard = waste.last;
    int diff = (card.value - wasteCard.value).abs();
    return diff == 1 || diff == 12;
  }

  void _placeCard(int position) async {
    PlayingCard? card = cardPositions[position];
    if (card == null || !card.isFaceUp || !_isCardAccessible(position)) return;
    if (!_canPlaceCard(card)) {
      _showMessage('Must be one rank up or down!');
      return;
    }

    // Get card position for animation
    final cardKey = GlobalKey();
    setState(() {
      _animatingPosition = position;
      _animatingCardKey = cardKey;
    });

    // Wait for next frame to get positions
    await Future.delayed(const Duration(milliseconds: 50));

    // Start animation
    _moveController.forward(from: 0).then((_) {
      setState(() {
        AudioService.instance.playSoundEffect('sounds/collect.mp3');
        waste.add(card);
        cardPositions[position] = null;
        _animatingPosition = null;

        streak++;
        score += 10 + (streak * 5);
        moves++;

        _unlockCards();
        _checkWin();
      });
    });
  }

  void _unlockCards() async {
    for (int pos in cardPositions.keys) {
      PlayingCard? card = cardPositions[pos];
      if (card != null && !card.isFaceUp && _isCardAccessible(pos)) {
        await _flipController.forward(from: 0);
        setState(() {
          card.isFaceUp = true;
        });
      }
    }
  }

  void _drawFromStock() async {
    if (stock.isEmpty) {
      _showMessage('No more cards!');
      return;
    }

    setState(() {
      PlayingCard card = stock.removeLast();
      card.isFaceUp = true;
      waste.add(card);
      moves++;
      streak = 0;
      _hintPosition = null;
      AudioService.instance.playSoundEffect('sounds/collect.mp3');
    });
  }

  void _showHint() {
    for (int pos in cardPositions.keys) {
      PlayingCard? card = cardPositions[pos];
      if (card != null &&
          card.isFaceUp &&
          _isCardAccessible(pos) &&
          _canPlaceCard(card)) {
        setState(() => _hintPosition = pos);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _hintPosition = null);
        });
        return;
      }
    }
    _showMessage(stock.isNotEmpty ? 'Try drawing from stock!' : 'No moves!');
  }

  void _checkWin() {
    if (cardPositions.values.every((card) => card == null)) {
      setState(() => _isGameWon = true);
      _timer.cancel();
      score += stock.length * 15;
      widget.gameState.recordWin(
        widget.config.mode,
        moves: moves,
        timeInSeconds: _seconds,
        level: 1,
      );
      AudioService.instance.playSoundEffect('sounds/levelup.mp3');
      _showWinDialog();
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF303F9F)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
                offset: Offset(0, 10),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Stack(
            children: [
              // Background decoration
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withOpacity(0.1),
                  ),
                ),
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with confetti effect
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.celebration, color: Colors.amber, size: 32),
                        SizedBox(width: 12),
                        Text(
                          'Victory!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.celebration, color: Colors.amber, size: 32),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      children: [
                        // Trophy icon
                        Container(
                          margin: EdgeInsets.only(bottom: 20),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.amber, Colors.orange],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.emoji_events,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),

                        // Congratulations message
                        Text(
                          'Congratulations!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'All 8 sets completed successfully!',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 25),

                        // Stats container
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildStatRow(
                                Icons.timer,
                                'Time',
                                _formatTime(_seconds),
                                Colors.blueAccent,
                              ),
                              SizedBox(height: 12),
                              _buildStatRow(
                                Icons.directions_run,
                                'Moves',
                                '$moves',
                                Colors.greenAccent,
                              ),
                              SizedBox(height: 12),
                              _buildStatRow(
                                Icons.star,
                                'Score',
                                '$score',
                                Colors.amber,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 30),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                'Play Again',
                                Icons.refresh,
                                Colors.greenAccent,
                                () {
                                  Navigator.pop(context);
                                  _startGame();
                                },
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                'Main Menu',
                                Icons.home,
                                Colors.blueAccent,
                                () {
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _formatTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2e842e),
              Color(0xFF2D5A3D),
            ], // Microsoft dark green
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 100),
                            _buildPyramid(constraints),
                            const SizedBox(height: 50),
                            _buildStockWaste(constraints),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.black.withOpacity(0.4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            'Score: $score',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            _formatTime(_seconds),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPyramid(BoxConstraints constraints) {
    // Microsoft-style: Perfect fit in mobile width
    double screenWidth = constraints.maxWidth;
    double cardW =
        (screenWidth) / 11; // Perfect calculation for 10 cards + spacing
    cardW = cardW.clamp(32.0, 55.0);
    double cardH = cardW * 1.6;

    return Column(
      children: [
        // Row 0 - 3 peaks
        _buildRow([0, 9, 18], cardW, cardH, 5.0),
        const SizedBox(height: 3),
        // Row 1 - 6 cards
        _buildRow([1, 2, 10, 11, 19, 20], cardW, cardH, 4.0),
        const SizedBox(height: 3),
        // Row 2 - 9 cards
        _buildRow([3, 4, 5, 12, 13, 14, 21, 22, 23], cardW, cardH, 3.0),
        const SizedBox(height: 3),
        // Row 3 - 10 cards (bottom) - Microsoft style with minimal spacing
        _buildRow([6, 7, 8, 15, 16, 17, 24, 25, 26, 27], cardW, cardH, 2.5),
      ],
    );
  }

  Widget _buildRow(List<int> positions, double w, double h, double indent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // SizedBox(width: w * indent),
        ...positions.map((p) => _buildCard(p, w, h)),
      ],
    );
  }

  Widget _buildCard(int pos, double w, double h) {
    PlayingCard? card = cardPositions[pos];
    if (card == null) return SizedBox(width: w, height: h);

    bool accessible = _isCardAccessible(pos);
    bool canPlace = accessible && card.isFaceUp && _canPlaceCard(card);
    bool isHint = _hintPosition == pos;
    bool isAnimating = _animatingPosition == pos;

    if (isAnimating) {
      return AnimatedBuilder(
        animation: _moveController,
        builder: (context, child) {
          // Flip and move animation
          double flipAngle = _moveController.value * math.pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(flipAngle),
            child: Opacity(
              opacity: 1.0 - (_moveController.value * 0.5),
              child: Container(
                width: w,
                height: h,
                child: flipAngle < math.pi / 2
                    ? _buildCardFront(card, w, h)
                    : _buildCardBack(w, h),
              ),
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.5),
      child: GestureDetector(
        onTap: () => _placeCard(pos),
        child: Transform.scale(
          scale: isHint ? 1.12 : 1.0,
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                if (isHint)
                  BoxShadow(
                    color: Colors.yellowAccent,
                    blurRadius: isHint ? 18 : 12,
                    spreadRadius: isHint ? 4 : 2,
                  ),
              ],
              border: isHint
                  ? Border.all(color: Colors.yellowAccent, width: 2.5)
                  : null,
            ),
            child: card.isFaceUp
                ? _buildCardFront(card, w, h)
                : _buildCardBack(w, h),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFront(PlayingCard card, double w, double h) {
    double fontSize = w * 0.22;
    double iconSize = w * 0.45;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey[400]!, width: 0.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 1,
            left: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.rankString,
                  style: TextStyle(
                    color: card.color,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    height: 0.9,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  card.suitSymbol,
                  style: TextStyle(
                    color: card.color,
                    fontSize: fontSize,
                    height: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Text(
              card.suitSymbol,
              style: TextStyle(color: card.color, fontSize: iconSize),
            ),
          ),
          Positioned(
            bottom: 1,
            right: 2,
            child: Transform.rotate(
              angle: math.pi,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.rankString,
                    style: TextStyle(
                      color: card.color,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      height: 0.9,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    card.suitSymbol,
                    style: TextStyle(
                      color: card.color,
                      fontSize: fontSize,
                      height: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(double w, double h) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF0d49be), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CustomPaint(painter: MicrosoftCardBackPainter()),
      ),
    );
  }

  Widget _buildStockWaste(BoxConstraints constraints) {
    double cardW = math.min(constraints.maxWidth / 4.5, 85) - 10;
    double cardH = cardW * 1.2;

    return Container(
      color: Color(0xff184115),
      padding: EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Stock pile - Microsoft style with stacked cards
          GestureDetector(
            onTap: _drawFromStock,
            child: Container(
              width: cardW,
              height: cardH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (stock.length > 4)
                    Positioned(
                      left: -14,
                      top: 2,
                      child: Container(
                        width: cardW - 8,
                        height: cardH - 4,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF0D47A1),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(5),
                          color: const Color(0xFF1565C0),
                        ),
                      ),
                    ),
                  if (stock.length > 3)
                    Positioned(
                      left: -10,
                      top: 2,
                      child: Container(
                        width: cardW - 8,
                        height: cardH - 4,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF0D47A1),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(5),
                          color: const Color(0xFF1565C0),
                        ),
                      ),
                    ),
                  // Background stacked cards effect (Microsoft style)
                  if (stock.length > 2)
                    Positioned(
                      left: -6,
                      top: 2,
                      child: Container(
                        width: cardW - 8,
                        height: cardH - 4,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF0D47A1),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(5),
                          color: const Color(0xFF1565C0),
                        ),
                      ),
                    ),
                  if (stock.length > 1)
                    Positioned(
                      left: -3,
                      top: 1,
                      child: Container(
                        width: cardW - 4,
                        height: cardH - 2,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF0D47A1),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(5),
                          color: const Color(0xFF1976D2),
                        ),
                      ),
                    ),
                  // Top card
                  if (stock.isNotEmpty)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: cardW,
                        height: cardH,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color(0xFF0D47A1),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CustomPaint(
                            painter: MicrosoftCardBackPainter(),
                          ),
                        ),
                      ),
                    ),
                  // Empty stock indicator
                  if (stock.isEmpty)
                    Container(
                      width: cardW,
                      height: cardH,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.white30, width: 2),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.close,
                          color: Colors.white30,
                          size: cardW * 0.4,
                        ),
                      ),
                    ),
                  // Stock count badge
                  if (stock.isNotEmpty)
                    Positioned(
                      bottom: 3,
                      right: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${stock.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Waste pile - Microsoft style with yellow border
          Container(
            width: cardW,
            height: cardH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFFFD700), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: waste.isEmpty
                ? Center(
                    child: Icon(
                      Icons.help_outline,
                      color: Colors.white38,
                      size: cardW * 0.5,
                    ),
                  )
                : _buildCardFront(waste.last, cardW, cardH),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildButton(
            Icons.add_circle_outline,
            'New',
            Colors.lightBlueAccent,
            _startGame,
          ),

          _buildButton(
            Icons.lightbulb_outline,
            'Hint',
            Colors.yellowAccent,
            _showHint,
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class MicrosoftCardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Microsoft-style blue gradient pattern
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF0d49be),
          const Color(0xFF0d49be),
          const Color(0xFF1E88E5),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(4),
      ),
      bgPaint,
    );

    // Decorative pattern - Microsoft style
    final patternPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    // Diamond pattern
    for (int i = 0; i < 6; i++) {
      for (int j = 0; j < 9; j++) {
        double x = (i + 0.5) * size.width / 6;
        double y = (j + 0.5) * size.height / 9;

        // Small diamond shape
        Path diamond = Path()
          ..moveTo(x, y - 2)
          ..lineTo(x + 2, y)
          ..lineTo(x, y + 2)
          ..lineTo(x - 2, y)
          ..close();

        canvas.drawPath(diamond, patternPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
