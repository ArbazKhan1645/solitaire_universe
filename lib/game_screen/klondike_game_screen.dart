import 'package:flutter/material.dart';
import 'package:solitaire_universe/controller/game_state.dart';
import 'package:solitaire_universe/manager/deck_manager.dart';
import 'package:solitaire_universe/model/game_mode.dart';
import 'package:solitaire_universe/model/playing_card.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:solitaire_universe/service/audio_service.dart';

class KlondikeGameScreen extends StatefulWidget {
  final GameModeConfig config;
  final GameState gameState;

  const KlondikeGameScreen({
    Key? key,
    required this.config,
    required this.gameState,
  }) : super(key: key);

  @override
  State<KlondikeGameScreen> createState() => _KlondikeGameScreenState();
}

class _KlondikeGameScreenState extends State<KlondikeGameScreen>
    with TickerProviderStateMixin {
  // 7 tableau columns
  List<List<PlayingCard>> tableau = List.generate(7, (_) => []);
  // 4 foundation piles (A→K same suit)
  List<List<PlayingCard>> foundations = List.generate(4, (_) => []);
  // Stock (face-down deck)
  List<PlayingCard> stock = [];
  // Waste (face-up from stock)
  List<PlayingCard> waste = [];

  int moves = 0;
  int score = 0;
  late Timer _timer;
  int _seconds = 0;
  bool _isGameWon = false;

  late AnimationController _flipController;
  late AnimationController _winController;

  int? _hintFromTableau;
  int? _hintFromCard;
  int? _hintToTableau;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _winController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _startGame();
  }

  @override
  void dispose() {
    _timer.cancel();
    _hintTimer?.cancel();
    _flipController.dispose();
    _winController.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      tableau = List.generate(7, (_) => <PlayingCard>[]);
      foundations = List.generate(4, (_) => <PlayingCard>[]);
      stock = [];
      waste = [];
      moves = 0;
      score = 0;
      _seconds = 0;
      _isGameWon = false;
      _hintFromTableau = null;
      _hintFromCard = null;
      _hintToTableau = null;
    });

    List<PlayingCard> deck = DeckManager.createStandardDeck();
    deck = DeckManager.shuffle(deck, seed: DeckManager.generateSeed());

    // Deal to tableau: 1, 2, 3, 4, 5, 6, 7 cards (28 total)
    int cardIndex = 0;
    for (int col = 0; col < 7; col++) {
      for (int row = 0; row <= col; row++) {
        PlayingCard card = deck[cardIndex++];
        card.isFaceUp = (row == col); // Only top card face up
        tableau[col].add(card);
      }
    }

    // Rest to stock (24 cards)
    stock = deck.sublist(cardIndex);
    for (var card in stock) {
      card.isFaceUp = false;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isGameWon) setState(() => _seconds++);
    });
  }

  // CRITICAL: Klondike drag rules
  bool _canPlaceOnTableau(PlayingCard movingCard, PlayingCard? targetCard) {
    if (targetCard == null) {
      // Empty space: Only King
      return movingCard.value == 13;
    }

    // Must alternate colors AND be one rank lower
    bool differentColor = movingCard.color != targetCard.color;
    bool oneRankLower = movingCard.value == targetCard.value - 1;

    return differentColor && oneRankLower;
  }

  bool _canPlaceOnFoundation(PlayingCard card, List<PlayingCard> foundation) {
    if (foundation.isEmpty) {
      // Must start with Ace
      return card.value == 1;
    }

    PlayingCard topCard = foundation.last;
    // Same suit AND one rank higher
    return card.suit == topCard.suit && card.value == topCard.value + 1;
  }

  List<PlayingCard> _getDraggableSequence(int tableauIndex, int startIndex) {
    List<PlayingCard> column = tableau[tableauIndex];
    if (startIndex >= column.length) return [];

    PlayingCard startCard = column[startIndex];
    if (!startCard.isFaceUp) return [];

    List<PlayingCard> sequence = [startCard];

    // Build sequence downward - must alternate colors
    for (int i = startIndex + 1; i < column.length; i++) {
      PlayingCard prev = column[i - 1];
      PlayingCard curr = column[i];

      // Check alternating color and descending
      if (curr.color != prev.color && curr.value == prev.value - 1) {
        sequence.add(curr);
      } else {
        break; // Sequence broken
      }
    }

    return sequence;
  }

  void _drawFromStock() async {
    if (stock.isEmpty) {
      // Recycle waste back to stock
      if (waste.isEmpty) return;

      setState(() {
        stock = waste.reversed.toList();
        for (var card in stock) {
          card.isFaceUp = false;
        }
        waste.clear();
      });
      return;
    }

    // Draw one card (or three for hard mode)
    PlayingCard card = stock.removeLast();

    // Flip animation
    await _flipController.forward(from: 0);

    setState(() {
      card.isFaceUp = true;
      waste.add(card);
      moves++;
    });
  }

  void _autoMoveToFoundation() {
    bool moved = false;

    // Try from waste
    if (waste.isNotEmpty) {
      PlayingCard topCard = waste.last;
      for (int i = 0; i < 4; i++) {
        if (_canPlaceOnFoundation(topCard, foundations[i])) {
          setState(() {
            foundations[i].add(waste.removeLast());
            score += 10;
            moved = true;
          });
          break;
        }
      }
    }

    // Try from tableau
    if (!moved) {
      for (int col = 0; col < 7; col++) {
        if (tableau[col].isEmpty) continue;
        PlayingCard topCard = tableau[col].last;
        if (!topCard.isFaceUp) continue;

        for (int f = 0; f < 4; f++) {
          if (_canPlaceOnFoundation(topCard, foundations[f])) {
            setState(() {
              foundations[f].add(tableau[col].removeLast());

              // Flip next card if exists
              if (tableau[col].isNotEmpty && !tableau[col].last.isFaceUp) {
                tableau[col].last.isFaceUp = true;
              }

              score += 10;
              moved = true;
            });

            _checkWin();
            return;
          }
        }
      }
    }

    if (moved) {
      _checkWin();
    }
  }

  void _showHint() {
    _clearHint();

    // Find valid moves
    Map<String, dynamic>? hint = _findBestMove();

    if (hint != null) {
      setState(() {
        _hintFromTableau = hint['fromTableau'];
        _hintFromCard = hint['fromCard'];
        _hintToTableau = hint['toTableau'];
      });

      _hintTimer = Timer(const Duration(seconds: 4), _clearHint);
      _showMessage('💡 ${hint['message']}');
    } else {
      _showMessage('💡 Try drawing from stock!');
    }
  }

  Map<String, dynamic>? _findBestMove() {
    // Look for moves from tableau
    for (int fromCol = 0; fromCol < 7; fromCol++) {
      if (tableau[fromCol].isEmpty) continue;

      for (int cardIdx = 0; cardIdx < tableau[fromCol].length; cardIdx++) {
        PlayingCard card = tableau[fromCol][cardIdx];
        if (!card.isFaceUp) continue;

        List<PlayingCard> sequence = _getDraggableSequence(fromCol, cardIdx);
        if (sequence.isEmpty) continue;

        // Try on other tableau columns
        for (int toCol = 0; toCol < 7; toCol++) {
          if (toCol == fromCol) continue;

          PlayingCard? targetCard = tableau[toCol].isEmpty
              ? null
              : tableau[toCol].last;

          if (_canPlaceOnTableau(sequence.first, targetCard)) {
            return {
              'fromTableau': fromCol,
              'fromCard': cardIdx,
              'toTableau': toCol,
              'message':
                  'Move ${card.rankString}${card.suitSymbol} to column ${toCol + 1}',
            };
          }
        }
      }
    }

    // Check waste card
    if (waste.isNotEmpty) {
      PlayingCard wasteCard = waste.last;
      for (int toCol = 0; toCol < 7; toCol++) {
        PlayingCard? targetCard = tableau[toCol].isEmpty
            ? null
            : tableau[toCol].last;
        if (_canPlaceOnTableau(wasteCard, targetCard)) {
          return {'message': 'Move waste card to column ${toCol + 1}'};
        }
      }
    }

    return null;
  }

  void _clearHint() {
    _hintTimer?.cancel();
    setState(() {
      _hintFromTableau = null;
      _hintFromCard = null;
      _hintToTableau = null;
    });
  }

  void _checkWin() {
    int totalCards = foundations.fold(0, (sum, f) => sum + f.length);
    if (totalCards == 52) {
      setState(() => _isGameWon = true);
      _timer.cancel();
      _winController.forward();
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
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildFoundationsAndStock(constraints),
                          const SizedBox(height: 16),
                          _buildTableau(constraints),
                        ],
                      ),
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
            'Klondike',
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

  Widget _buildFoundationsAndStock(BoxConstraints constraints) {
    double cardW = math.min((constraints.maxWidth - 40) / 7, 70);
    double cardH = cardW * 1.4;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          // Stock
          GestureDetector(
            onTap: _drawFromStock,
            child: Container(
              width: cardW,
              height: cardH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: stock.isEmpty ? Colors.white24 : Colors.white54,
                  width: 2,
                ),
              ),
              child: stock.isEmpty
                  ? Icon(
                      Icons.refresh,
                      color: Colors.white30,
                      size: cardW * 0.4,
                    )
                  : _buildCardBack(cardW, cardH),
            ),
          ),
          const SizedBox(width: 8),
          // Waste
          GestureDetector(
            onTap: () {
              if (waste.isNotEmpty) {
                _tryAutoPlace(waste.last, fromWaste: true);
              }
            },
            child: Container(
              width: cardW,
              height: cardH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: waste.isEmpty
                  ? null
                  : Draggable<Map<String, dynamic>>(
                      data: {'fromWaste': true, 'card': waste.last},
                      feedback: Material(
                        color: Colors.transparent,
                        child: Opacity(
                          opacity: 0.8,
                          child: _buildCardFront(waste.last, cardW, cardH),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _buildCardFront(waste.last, cardW, cardH),
                      ),
                      onDragStarted: _clearHint,
                      child: _buildCardFront(waste.last, cardW, cardH),
                    ),
            ),
          ),
          const Spacer(),
          // 4 Foundations
          ...List.generate(4, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildFoundation(index, cardW, cardH),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFoundation(int index, double w, double h) {
    List<PlayingCard> foundation = foundations[index];

    return DragTarget<Map<String, dynamic>>(
      onWillAccept: (data) {
        if (data == null) return false;
        PlayingCard card;
        if (data['fromWaste'] == true) {
          card = data['card'];
        } else {
          List<PlayingCard> sequence = data['sequence'] ?? [];
          if (sequence.length != 1)
            return false; // Only single cards to foundation
          card = sequence.first;
        }
        return _canPlaceOnFoundation(card, foundation);
      },
      onAccept: (data) {
        PlayingCard card;
        if (data['fromWaste'] == true) {
          card = waste.removeLast();
        } else {
          int fromTableau = data['fromTableau'];
          card = tableau[fromTableau].removeLast();
          if (tableau[fromTableau].isNotEmpty &&
              !tableau[fromTableau].last.isFaceUp) {
            tableau[fromTableau].last.isFaceUp = true;
          }
        }

        setState(() {
          foundations[index].add(card);
          score += 10;
          moves++;
          AudioService.instance.playSoundEffect('sounds/collect.mp3');
        });

        _clearHint();
        _checkWin();
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: candidateData.isNotEmpty
                  ? Colors.yellowAccent
                  : Colors.white24,
              width: candidateData.isNotEmpty ? 2 : 1,
            ),
          ),
          child: foundation.isEmpty
              ? Center(
                  child: Icon(
                    [
                      Icons.favorite,
                      Icons.diamond,
                      Icons.class_,
                      Icons.spa,
                    ][index],
                    color: Colors.white24,
                    size: w * 0.4,
                  ),
                )
              : _buildCardFront(foundation.last, w, h),
        );
      },
    );
  }

  Widget _buildTableau(BoxConstraints constraints) {
    double cardW = math.min((constraints.maxWidth - 40) / 7, 70);
    double cardH = cardW * 1.4;
    double overlap = 25.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(7, (colIndex) {
          return Expanded(
            child: _buildTableauColumn(colIndex, cardW, cardH, overlap),
          );
        }),
      ),
    );
  }

  Widget _buildTableauColumn(
    int colIndex,
    double cardW,
    double cardH,
    double overlap,
  ) {
    List<PlayingCard> column = tableau[colIndex];
    bool isHintTarget = _hintToTableau == colIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: DragTarget<Map<String, dynamic>>(
        onWillAccept: (data) {
          if (data == null) return false;
          PlayingCard card;

          if (data['fromWaste'] == true) {
            card = data['card'];
          } else {
            List<PlayingCard> sequence = data['sequence'] ?? [];
            if (sequence.isEmpty) return false;
            card = sequence.first;

            // Don't allow same column
            if (data['fromTableau'] == colIndex) return false;
          }

          PlayingCard? targetCard = column.isEmpty ? null : column.last;
          return _canPlaceOnTableau(card, targetCard);
        },
        onAccept: (data) {
          _clearHint();

          List<PlayingCard> cardsToMove = [];

          if (data['fromWaste'] == true) {
            cardsToMove = [waste.removeLast()];
          } else {
            int fromTableau = data['fromTableau'];
            int fromIndex = data['fromIndex'];
            cardsToMove = tableau[fromTableau].sublist(fromIndex);
            tableau[fromTableau].removeRange(
              fromIndex,
              tableau[fromTableau].length,
            );

            // Flip top card if exists
            if (tableau[fromTableau].isNotEmpty &&
                !tableau[fromTableau].last.isFaceUp) {
              tableau[fromTableau].last.isFaceUp = true;
            }
          }

          setState(() {
            tableau[colIndex].addAll(cardsToMove);
            moves++;
            score += 5;
            AudioService.instance.playSoundEffect('sounds/collect.mp3');
          });
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isHintTarget
                    ? Colors.amber
                    : candidateData.isNotEmpty
                    ? Colors.yellowAccent
                    : Colors.white12,
                width: isHintTarget ? 3 : (candidateData.isNotEmpty ? 2 : 1),
              ),
              boxShadow: isHintTarget
                  ? [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: column.isEmpty
                ? SizedBox(width: cardW, height: cardH)
                : SizedBox(
                    width: cardW,
                    height: cardH + (column.length - 1) * overlap,
                    child: Stack(
                      children: List.generate(column.length, (cardIdx) {
                        return _buildTableauCard(
                          colIndex,
                          cardIdx,
                          cardW,
                          cardH,
                          overlap,
                        );
                      }),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildTableauCard(
    int colIndex,
    int cardIdx,
    double cardW,
    double cardH,
    double overlap,
  ) {
    PlayingCard card = tableau[colIndex][cardIdx];
    bool isHintCard = _hintFromTableau == colIndex && _hintFromCard == cardIdx;

    Widget cardWidget = Positioned(
      top: cardIdx * overlap,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: card.isFaceUp
            ? () =>
                  _tryAutoPlace(card, fromTableau: colIndex, cardIndex: cardIdx)
            : null,
        child: _buildCard(card, cardW, cardH, isHintCard),
      ),
    );

    if (card.isFaceUp) {
      List<PlayingCard> sequence = _getDraggableSequence(colIndex, cardIdx);

      if (sequence.isNotEmpty) {
        return Positioned(
          top: cardIdx * overlap,
          left: 0,
          right: 0,
          child: Draggable<Map<String, dynamic>>(
            data: {
              'fromTableau': colIndex,
              'fromIndex': cardIdx,
              'sequence': sequence,
            },
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: cardW,
                height: cardH + (sequence.length - 1) * overlap,
                child: Stack(
                  children: List.generate(
                    sequence.length,
                    (i) => Positioned(
                      top: i * overlap,
                      child: Opacity(
                        opacity: 0.8,
                        child: _buildCard(sequence[i], cardW, cardH, false),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _buildCard(card, cardW, cardH, false),
            ),
            onDragStarted: _clearHint,
            child: _buildCard(card, cardW, cardH, isHintCard),
          ),
        );
      }
    }

    return cardWidget;
  }

  void _tryAutoPlace(
    PlayingCard card, {
    bool fromWaste = false,
    int? fromTableau,
    int? cardIndex,
  }) {
    // Try foundations first
    for (int i = 0; i < 4; i++) {
      if (_canPlaceOnFoundation(card, foundations[i])) {
        setState(() {
          if (fromWaste) {
            waste.removeLast();
          } else if (fromTableau != null) {
            tableau[fromTableau].removeLast();
            if (tableau[fromTableau].isNotEmpty &&
                !tableau[fromTableau].last.isFaceUp) {
              tableau[fromTableau].last.isFaceUp = true;
            }
          }
          foundations[i].add(card);
          score += 10;
          moves++;
        });
        _checkWin();
        return;
      }
    }
  }

  Widget _buildCard(PlayingCard card, double w, double h, bool isHint) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: w,
      height: h,
      transform: Matrix4.identity()..scale(isHint ? 1.05 : 1.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: isHint ? Colors.amber : Colors.black26,
            blurRadius: isHint ? 8 : 3,
            spreadRadius: isHint ? 2 : 0,
          ),
        ],
      ),
      child: card.isFaceUp ? _buildCardFront(card, w, h) : _buildCardBack(w, h),
    );
  }

  Widget _buildCardFront(PlayingCard card, double w, double h) {
    double fontSize = w * 0.22;
    double iconSize = w * 0.50;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 2,
            left: 4,
            child: Column(
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
                Text(
                  card.suitSymbol,
                  style: TextStyle(
                    color: card.color,
                    fontSize: fontSize * 0.9,
                    height: 0.9,
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
            bottom: 2,
            right: 4,
            child: Transform.rotate(
              angle: math.pi,
              child: Column(
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
                  Text(
                    card.suitSymbol,
                    style: TextStyle(
                      color: card.color,
                      fontSize: fontSize * 0.9,
                      height: 0.9,
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
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: CustomPaint(painter: CardBackPainter()),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.black.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildButton(
            Icons.refresh,
            'New',
            Colors.lightBlueAccent,
            _startGame,
          ),
          _buildButton(
            Icons.lightbulb_outline,
            'Hint',
            Colors.amber,
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

class CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.2);
    for (int i = 0; i < 6; i++) {
      for (int j = 0; j < 10; j++) {
        canvas.drawCircle(
          Offset((i + 0.5) * size.width / 6, (j + 0.5) * size.height / 10),
          1.5,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
