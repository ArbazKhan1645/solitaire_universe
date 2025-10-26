import 'package:flutter/material.dart';
import 'package:solitaire_universe/controller/game_state.dart';
import 'package:solitaire_universe/manager/deck_manager.dart';
import 'package:solitaire_universe/model/game_mode.dart';
import 'package:solitaire_universe/model/playing_card.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:solitaire_universe/service/audio_service.dart';

class SpiderGameScreen extends StatefulWidget {
  final GameModeConfig config;
  final GameState gameState;

  const SpiderGameScreen({
    Key? key,
    required this.config,
    required this.gameState,
  }) : super(key: key);

  @override
  State<SpiderGameScreen> createState() => _SpiderGameScreenState();
}

class _SpiderGameScreenState extends State<SpiderGameScreen>
    with TickerProviderStateMixin {
  List<List<PlayingCard>> columns = List.generate(10, (_) => []);
  List<PlayingCard> stock = [];
  List<List<PlayingCard>> completedSets = [];

  int moves = 0;
  int score = 500;
  late Timer _timer;
  int _seconds = 0;
  bool _isGameWon = false;

  late AnimationController _completeSetController;

  // Stock deal animation
  List<AnimationController> _dealAnimations = [];
  List<Offset> _dealStartPositions = [];
  List<Offset> _dealEndPositions = [];
  List<PlayingCard> _dealingCards = [];
  bool _isDealing = false;

  int? _hintFromColumn;
  int? _hintFromCardIndex;
  int? _hintToColumn;
  Timer? _hintTimer;

  // Keys for animation positions
  final GlobalKey _stockKey = GlobalKey();
  final List<GlobalKey> _columnKeys = List.generate(10, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _completeSetController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _startGame();
  }

  @override
  void dispose() {
    _timer.cancel();
    _hintTimer?.cancel();
    _completeSetController.dispose();
    for (var anim in _dealAnimations) {
      anim.dispose();
    }
    super.dispose();
  }

  void _startGame() {
    setState(() {
      columns = List.generate(10, (_) => <PlayingCard>[]);
      stock = [];
      completedSets = [];
      moves = 0;
      score = 500;
      _seconds = 0;
      _isGameWon = false;
      _hintFromColumn = null;
      _hintFromCardIndex = null;
      _hintToColumn = null;
      _isDealing = false;
    });

    List<PlayingCard> deck = [];
    for (int i = 0; i < 8; i++) {
      for (Rank rank in Rank.values) {
        deck.add(PlayingCard(suit: Suit.spades, rank: rank));
      }
    }

    deck = DeckManager.shuffle(deck, seed: DeckManager.generateSeed());

    int cardIndex = 0;
    for (int col = 0; col < 10; col++) {
      int cardsInColumn = col < 4 ? 6 : 5;
      for (int i = 0; i < cardsInColumn; i++) {
        if (cardIndex < deck.length) {
          PlayingCard card = deck[cardIndex++];
          card.isFaceUp = (i == cardsInColumn - 1);
          columns[col].add(card);
        }
      }
    }

    stock = deck.sublist(cardIndex);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isGameWon) setState(() => _seconds++);
    });
  }

  bool _canPlaceCard(PlayingCard movingCard, PlayingCard? targetCard) {
    if (targetCard == null) return true;
    return movingCard.value == targetCard.value - 1;
  }

  // CORRECT Spider Rules: Check BELOW, not above!
  List<PlayingCard> _getDraggableSequence(int columnIndex, int cardIndex) {
    List<PlayingCard> column = columns[columnIndex];
    if (cardIndex >= column.length) return [];

    PlayingCard currentCard = column[cardIndex];

    // Rule 1: Last card is ALWAYS draggable (freely)
    if (cardIndex == column.length - 1) {
      return [currentCard];
    }

    // Rule 2: Check BELOW - must be continuous sequence below
    List<PlayingCard> sequence = [currentCard];

    for (int i = cardIndex + 1; i < column.length; i++) {
      PlayingCard prev = column[i - 1];
      PlayingCard curr = column[i];

      // Check if continuous (same suit, descending by 1)
      if (curr.suit == prev.suit && curr.value == prev.value - 1) {
        sequence.add(curr);
      } else {
        // Break found below! Can't drag this card
        return [];
      }
    }

    // All cards below are continuous - can drag the sequence
    return sequence;
  }

  void _checkAndCompleteSet(int columnIndex) async {
    List<PlayingCard> column = columns[columnIndex];
    if (column.length < 13) return;

    for (int startIdx = 0; startIdx <= column.length - 13; startIdx++) {
      List<PlayingCard> potentialSet = column.sublist(startIdx, startIdx + 13);

      if (_isCompleteSet(potentialSet)) {
        await _completeSetController.forward(from: 0);

        setState(() {
          completedSets.add(List.from(potentialSet));
          columns[columnIndex].removeRange(startIdx, startIdx + 13);

          if (columns[columnIndex].isNotEmpty &&
              !columns[columnIndex].last.isFaceUp) {
            columns[columnIndex].last.isFaceUp = true;
          }

          score += 100;
        });

        AudioService.instance.playSoundEffect('sounds/levelup.mp3');

        _checkWin();
        return;
      }
    }
  }

  bool _isCompleteSet(List<PlayingCard> cards) {
    if (cards.length != 13) return false;

    Suit? setSuit = cards[0].suit;
    if (cards[0].value != 13) return false;

    for (int i = 0; i < 13; i++) {
      int expectedValue = 13 - i;
      if (cards[i].value != expectedValue) return false;
      if (cards[i].suit != setSuit) return false;
    }

    return true;
  }

  void _dealFromStock() async {
    if (_isDealing) return;

    if (stock.length < 10) {
      _showMessage('Not enough cards in stock!');
      return;
    }

    bool hasEmptyColumns = columns.any((col) => col.isEmpty);
    if (hasEmptyColumns) {
      _showMessage('Fill all empty columns first!');
      return;
    }

    setState(() => _isDealing = true);

    await Future.delayed(const Duration(milliseconds: 50));

    // Get stock position
    RenderBox? stockBox =
        _stockKey.currentContext?.findRenderObject() as RenderBox?;
    if (stockBox == null) {
      setState(() => _isDealing = false);
      return;
    }

    Offset stockPos = stockBox.localToGlobal(Offset.zero);
    stockPos = Offset(
      stockPos.dx + stockBox.size.width / 2,
      stockPos.dy + stockBox.size.height / 2,
    );

    _dealingCards = [];
    _dealStartPositions = [];
    _dealEndPositions = [];
    _dealAnimations = [];

    for (int i = 0; i < 10 && stock.isNotEmpty; i++) {
      PlayingCard card = stock.removeLast();
      card.isFaceUp = false;
      _dealingCards.add(card);

      RenderBox? columnBox =
          _columnKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (columnBox != null) {
        Offset columnPos = columnBox.localToGlobal(Offset.zero);
        double cardW = columnBox.size.width;
        double cardOffset = columns[i].length * 25.0;
        columnPos = Offset(
          columnPos.dx + cardW / 2,
          columnPos.dy + cardOffset + 35,
        );

        _dealStartPositions.add(stockPos);
        _dealEndPositions.add(columnPos);
      } else {
        _dealStartPositions.add(stockPos);
        _dealEndPositions.add(stockPos);
      }

      AnimationController controller = AnimationController(
        duration: Duration(milliseconds: 600 + (i * 30)),
        vsync: this,
      );
      _dealAnimations.add(controller);
    }

    setState(() {});

    for (int i = 0; i < _dealAnimations.length; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        if (mounted && i < _dealAnimations.length) {
          _dealAnimations[i].forward();
        }
      });
    }
    AudioService.instance.playSoundEffect('sounds/collect.mp3');

    await Future.delayed(
      Duration(milliseconds: 800 + (_dealAnimations.length * 60)),
    );

    setState(() {
      for (int i = 0; i < _dealingCards.length && i < columns.length; i++) {
        _dealingCards[i].isFaceUp = true;
        columns[i].add(_dealingCards[i]);
      }
      _dealingCards.clear();
      _dealStartPositions.clear();
      _dealEndPositions.clear();
      _isDealing = false;
      moves++;
    });

    for (var anim in _dealAnimations) {
      anim.dispose();
    }
    _dealAnimations.clear();

    for (int i = 0; i < 10; i++) {
      _checkAndCompleteSet(i);
    }
  }

  void _showHint() {
    _clearHint();

    Map<String, dynamic>? hint = _findBestMove();

    if (hint != null) {
      setState(() {
        _hintFromColumn = hint['fromColumn'];
        _hintFromCardIndex = hint['fromCardIndex'];
        _hintToColumn = hint['toColumn'];
      });

      _hintTimer = Timer(const Duration(seconds: 4), () {
        _clearHint();
      });

      _showMessage(
        '💡 Move ${hint['cardName']} to column ${hint['toColumn'] + 1}',
      );
    } else {
      if (stock.length >= 10) {
        _showMessage('💡 No moves available. Use stock!');
      } else {
        _showMessage('⚠️ No moves available!');
      }
    }
  }

  // Find best move for hint
  Map<String, dynamic>? _findBestMove() {
    for (int fromCol = 0; fromCol < 10; fromCol++) {
      if (columns[fromCol].isEmpty) continue;

      for (int cardIdx = 0; cardIdx < columns[fromCol].length; cardIdx++) {
        PlayingCard card = columns[fromCol][cardIdx];
        if (!card.isFaceUp) continue;

        List<PlayingCard> sequence = _getDraggableSequence(fromCol, cardIdx);
        if (sequence.isEmpty) continue;

        for (int toCol = 0; toCol < 10; toCol++) {
          if (toCol == fromCol) continue;

          PlayingCard? targetCard = columns[toCol].isEmpty
              ? null
              : columns[toCol].last;

          if (_canPlaceCard(sequence.first, targetCard)) {
            return {
              'fromColumn': fromCol,
              'fromCardIndex': cardIdx,
              'toColumn': toCol,
              'cardName': '${card.rankString}${card.suitSymbol}',
            };
          }
        }
      }
    }

    return null;
  }

  void _clearHint() {
    _hintTimer?.cancel();
    setState(() {
      _hintFromColumn = null;
      _hintFromCardIndex = null;
      _hintToColumn = null;
    });
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('Spider Solitaire Rules'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection(
                '🎯 Objective',
                'Complete 8 sets K→A same suit',
              ),
              const SizedBox(height: 12),
              _buildInfoSection(
                '🃏 Moving',
                '• One rank lower\n• Continuous sequences only',
              ),
              const SizedBox(height: 12),
              _buildInfoSection('✨ Sets', '• K→A auto-removed\n• +100 points'),
              const SizedBox(height: 12),
              _buildInfoSection(
                '📦 Stock',
                '• 10 cards per deal\n• Fill empties first',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got It!'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
        ),
      ],
    );
  }

  void _checkWin() {
    if (completedSets.length == 8) {
      setState(() => _isGameWon = true);
      _timer.cancel();
      widget.gameState.recordWin(
        widget.config.mode,
        moves: moves,
        timeInSeconds: _seconds,
        level: 1,
      );
      AudioService.instance.playSoundEffect('sounds/collect.mp3');
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
                              child: _buildActionButtons(
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
                              child: _buildActionButtons(
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

  Widget _buildActionButtons(
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
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(child: _buildGameArea(constraints)),
                            _buildBottomArea(constraints),
                          ],
                        ),
                        if (_isDealing) ..._buildDealingCards(constraints),
                      ],
                    );
                  },
                ),
              ),
              _buildActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDealingCards(BoxConstraints constraints) {
    List<Widget> widgets = [];

    for (int i = 0; i < _dealAnimations.length; i++) {
      if (i >= _dealingCards.length) continue;

      widgets.add(
        AnimatedBuilder(
          animation: _dealAnimations[i],
          builder: (context, child) {
            double t = _dealAnimations[i].value;

            Offset currentPos = Offset.lerp(
              _dealStartPositions[i],
              _dealEndPositions[i],
              t,
            )!;

            // Flip animation
            double rotation = t < 0.5 ? t * 2 * math.pi : (1 - t) * 2 * math.pi;
            bool showFront = t >= 0.5;

            return Positioned(
              left: currentPos.dx - 25,
              top: currentPos.dy - 15,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(1, 2, 0.001)
                  ..rotateY(rotation),
                child: Container(
                  width: 50,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: showFront
                      ? _buildCardFront(_dealingCards[i], 50, 70)
                      : _buildCardBack(50, 70),
                ),
              ),
            );
          },
        ),
      );
    }

    return widgets;
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.black.withOpacity(0.4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'Easy',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const Spacer(),
          Text(
            'Score: $score',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatTime(_seconds),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea(BoxConstraints constraints) {
    double cardWidth = (constraints.maxWidth - 22) / 10;
    cardWidth = cardWidth.clamp(30.0, 60.0);
    double cardHeight = cardWidth * 1.4;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(10, (colIndex) {
            return _buildColumn(colIndex, cardWidth, cardHeight);
          }),
        ),
      ),
    );
  }

  Widget _buildColumn(int columnIndex, double cardWidth, double cardHeight) {
    List<PlayingCard> column = columns[columnIndex];
    bool isHintToColumn = _hintToColumn == columnIndex;
    double overlapOffset = 25.0;

    return Expanded(
      child: Container(
        key: _columnKeys[columnIndex],
        margin: const EdgeInsets.symmetric(horizontal: 1),
        child: DragTarget<Map<String, dynamic>>(
          onWillAccept: (data) {
            if (data == null) return false;
            int fromCol = data['fromColumn'];
            if (fromCol == columnIndex) return false;

            List<PlayingCard> sequence = data['sequence'] ?? [];
            if (sequence.isEmpty) return false;

            if (column.isEmpty) return true;

            PlayingCard topCard = column.last;
            return _canPlaceCard(sequence.first, topCard);
          },
          onAccept: (data) {
            int fromCol = data['fromColumn'];
            int fromIndex = data['fromIndex'];
            List<PlayingCard> sequence = data['sequence'];

            _clearHint();

            setState(() {
              columns[fromCol].removeRange(fromIndex, columns[fromCol].length);

              if (columns[fromCol].isNotEmpty &&
                  !columns[fromCol].last.isFaceUp) {
                columns[fromCol].last.isFaceUp = true;
              }

              columns[columnIndex].addAll(sequence);
              moves++;
              AudioService.instance.playSoundEffect('sounds/collect.mp3');
            });

            _checkAndCompleteSet(columnIndex);
            _checkAndCompleteSet(fromCol);
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isHintToColumn
                      ? Colors.amber
                      : candidateData.isNotEmpty
                      ? Colors.yellowAccent
                      : Colors.white12,
                  width: isHintToColumn
                      ? 3
                      : (candidateData.isNotEmpty ? 2 : 1),
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: isHintToColumn
                    ? [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: column.isEmpty
                  ? SizedBox(width: cardWidth, height: cardHeight)
                  : SizedBox(
                      width: cardWidth,
                      height: cardHeight + (column.length - 1) * overlapOffset,
                      child: Stack(
                        children: List.generate(column.length, (cardIndex) {
                          PlayingCard card = column[cardIndex];
                          bool isHintCard =
                              _hintFromColumn == columnIndex &&
                              _hintFromCardIndex == cardIndex;

                          Widget cardWidget = Positioned(
                            top: cardIndex * overlapOffset,
                            left: 0,
                            right: 0,
                            child: _buildCardWidget(
                              card,
                              cardWidth,
                              cardHeight,
                              isHintCard,
                            ),
                          );

                          if (card.isFaceUp) {
                            List<PlayingCard> draggableSeq =
                                _getDraggableSequence(columnIndex, cardIndex);

                            if (draggableSeq.isNotEmpty) {
                              return Positioned(
                                top: cardIndex * overlapOffset,
                                left: 0,
                                right: 0,
                                child: Draggable<Map<String, dynamic>>(
                                  data: {
                                    'fromColumn': columnIndex,
                                    'fromIndex': cardIndex,
                                    'sequence': draggableSeq,
                                  },
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(
                                      width: cardWidth,
                                      height:
                                          cardHeight +
                                          (draggableSeq.length - 1) *
                                              overlapOffset,
                                      child: Stack(
                                        children: List.generate(
                                          draggableSeq.length,
                                          (i) => Positioned(
                                            top: i * overlapOffset,
                                            left: 0,
                                            child: Opacity(
                                              opacity: 0.8,
                                              child: _buildCardWidget(
                                                draggableSeq[i],
                                                cardWidth,
                                                cardHeight,
                                                false,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.3,
                                    child: _buildCardWidget(
                                      card,
                                      cardWidth,
                                      cardHeight,
                                      false,
                                    ),
                                  ),
                                  onDragStarted: _clearHint,
                                  child: _buildCardWidget(
                                    card,
                                    cardWidth,
                                    cardHeight,
                                    isHintCard,
                                  ),
                                ),
                              );
                            }
                          }

                          return cardWidget;
                        }),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardWidget(
    PlayingCard card,
    double width,
    double height,
    bool isHint,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      transform: Matrix4.identity()..scale(isHint ? 1.05 : 1.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: isHint ? Colors.amber : Colors.black26,
            blurRadius: isHint ? 8 : 3,
            offset: const Offset(0, 1),
            spreadRadius: isHint ? 2 : 0,
          ),
        ],
      ),
      child: card.isFaceUp
          ? _buildCardFront(card, width, height)
          : _buildCardBack(width, height),
    );
  }

  Widget _buildCardFront(PlayingCard card, double w, double h) {
    double fontSize = w * 0.20;
    double cornerIconSize = w * 0.25;
    double centerIconSize = w * 0.45;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[400]!, width: 0.5),
      ),
      child: Stack(
        children: [
          // Corner rank and suit (top-left)
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
                // Text(
                //   card.suitSymbol,
                //   style: TextStyle(
                //     color: card.color,
                //     fontSize: cornerIconSize,
                //     height: 0.8,
                //   ),
                // ),
              ],
            ),
          ),

          // Center design based on card rank
          Center(child: _buildCenterDesign(card, w, h)),

          // Corner rank and suit (bottom-right, rotated)
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
                  // Text(
                  //   card.suitSymbol,
                  //   style: TextStyle(
                  //     color: card.color,
                  //     fontSize: cornerIconSize,
                  //     height: 0.8,
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterDesign(PlayingCard card, double w, double h) {
    double centerIconSize = w * 0.45;

    switch (card.rank) {
      case Rank.king:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '♔',
              style: TextStyle(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );

      case Rank.queen:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '♕',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );

      case Rank.jack:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '♘',
              style: TextStyle(
                color: Colors.green,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );

      case Rank.ace:
        return Container(
          width: w * 0.7,
          height: h * 0.7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: card.color, width: 2),
          ),
          child: Center(
            child: Text(
              card.suitSymbol,
              style: TextStyle(
                color: card.color,
                fontSize: centerIconSize * 0.8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );

      default:
        // Number cards (2-10) - display suit symbols in pattern
        return _buildNumberCardPattern(card, w, h);
    }
  }

  Widget _buildNumberCardPattern(PlayingCard card, double w, double h) {
    int value = card.value;
    double symbolSize = w * 0.25;

    // Different patterns based on card value
    List<Widget> symbols = [];

    switch (value) {
      case 2:
        symbols = [
          Positioned(
            top: h * 0.3,
            left: w * 0.5 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.3,
            right: w * 0.5 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
        ];
        break;

      case 3:
        symbols = [
          Positioned(
            top: h * 0.2,
            left: w * 0.5 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.5 - symbolSize / 2,
            left: w * 0.5 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.2,
            right: w * 0.5 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
        ];
        break;

      case 4:
        symbols = [
          Positioned(
            top: h * 0.25,
            left: w * 0.25 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.25,
            right: w * 0.25 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.25,
            left: w * 0.25 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.25,
            right: w * 0.25 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
        ];
        break;

      case 5:
        symbols = [
          Positioned(
            top: h * 0.2,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.2,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.5 - symbolSize / 2,
            left: w * 0.5 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.2,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.2,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
        ];
        break;

      case 6:
        symbols = [
          Positioned(
            top: h * 0.2,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.2,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.5 - symbolSize / 2,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.5 - symbolSize / 2,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.2,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.2,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
        ];
        break;

      case 7:
        symbols = [
          Positioned(
            top: h * 0.15,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.15,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.35,
            left: w * 0.5 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.55 - symbolSize / 2,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.55 - symbolSize / 2,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.15,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.15,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
        ];
        break;

      case 8:
        symbols = [
          Positioned(
            top: h * 0.15,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.15,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.35,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.35,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.55 - symbolSize / 2,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.55 - symbolSize / 2,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.15,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.15,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
        ];
        break;

      case 9:
        symbols = [
          Positioned(
            top: h * 0.1,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.1,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.3,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.3,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.5 - symbolSize / 2,
            left: w * 0.5 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.7 - symbolSize / 2,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.7 - symbolSize / 2,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.1,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.1,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
        ];
        break;

      case 10:
        symbols = [
          Positioned(
            top: h * 0.1,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.1,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.3,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.3,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.5 - symbolSize / 2,
            left: w * 0.35 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.5 - symbolSize / 2,
            right: w * 0.35 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.7 - symbolSize / 2,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            top: h * 0.7 - symbolSize / 2,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.1,
            left: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
          Positioned(
            bottom: h * 0.1,
            right: w * 0.2 - symbolSize / 2,
            child: _buildSuitSymbol(card, symbolSize),
          ),
        ];
        break;

      default:
        return Text(
          card.suitSymbol,
          style: TextStyle(color: card.color, fontSize: 12),
        );
    }

    return SizedBox(
      width: w,
      height: h,
      child: Stack(children: symbols),
    );
  }

  Widget _buildSuitSymbol(PlayingCard card, double size) {
    return Text(
      card.suitSymbol,
      style: TextStyle(color: card.color, fontSize: size),
    );
  }

  Widget _buildCardBack(double w, double h) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF0D47A1), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: CustomPaint(painter: SpiderCardBackPainter()),
      ),
    );
  }

  Widget _buildBottomArea(BoxConstraints constraints) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: Colors.black.withOpacity(0.3),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(completedSets.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      width: 45,
                      height: 63,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: _buildCardFront(completedSets[index][0], 45, 63),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 15),
          _buildStockWidget(),
        ],
      ),
    );
  }

  Widget _buildStockWidget() {
    int stockPiles = (stock.length / 10).ceil();

    return GestureDetector(
      key: _stockKey,
      onTap: _dealFromStock,
      child: Container(
        width: 75,
        height: 105,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (stockPiles > 2)
              Positioned(left: 6, top: 4, child: _buildStockCard(69, 101)),
            if (stockPiles > 1)
              Positioned(left: 3, top: 2, child: _buildStockCard(72, 103)),
            if (stock.isNotEmpty)
              Positioned(left: 0, top: 0, child: _buildStockCard(75, 105)),
            if (stock.isEmpty)
              Container(
                width: 75,
                height: 105,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white30, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.close, color: Colors.white30, size: 35),
              ),
            if (stock.isNotEmpty)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '${stock.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockCard(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Color(0xFF0D47A1), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CustomPaint(painter: SpiderCardBackPainter()),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            Icons.refresh,
            'New',
            Colors.lightBlueAccent,
            _startGame,
          ),
          _buildActionButton(
            Icons.info_outline,
            'Info',
            Colors.blueAccent,
            _showInfoDialog,
          ),
          _buildActionButton(
            Icons.lightbulb_outline,
            'Hint',
            Colors.amber,
            _showHint,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpiderCardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF1E88E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(4),
      ),
      bgPaint,
    );

    final patternPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 8; j++) {
        double x = (i + 0.5) * size.width / 5;
        double y = (j + 0.5) * size.height / 8;
        canvas.drawCircle(Offset(x, y), 1.5, patternPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
