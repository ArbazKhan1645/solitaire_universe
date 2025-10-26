import 'package:flutter/material.dart';
import 'package:solitaire_universe/model/playing_card.dart';
import 'dart:math' as math;

class CardWidget extends StatefulWidget {
  final PlayingCard card;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool isHighlighted;
  final bool isHinted;
  final double scale;
  final bool enableAnimation;

  const CardWidget({
    Key? key,
    required this.card,
    this.onTap,
    this.onDoubleTap,
    this.isHighlighted = false,
    this.isHinted = false,
    this.scale = 1.0,
    this.enableAnimation = true,
  }) : super(key: key);

  @override
  State<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends State<CardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    if (widget.card.isFaceUp) {
      _flipController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(CardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.card.isFaceUp != oldWidget.card.isFaceUp) {
      if (widget.card.isFaceUp) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * math.pi;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: angle >= math.pi / 2 ? _buildCardFront() : _buildCardBack(),
          );
        },
      ),
    );
  }

  Widget _buildCardFront() {
    return Transform(
      transform: Matrix4.identity()..rotateY(math.pi),
      alignment: Alignment.center,
      child: Container(
        width: 60 * widget.scale,
        height: 84 * widget.scale,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6 * widget.scale),
          border: Border.all(
            color: widget.isHighlighted
                ? Colors.yellow
                : widget.isHinted
                ? Colors.green
                : Colors.grey[300]!,
            width: widget.isHighlighted || widget.isHinted ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isHighlighted
                  ? Colors.yellow.withOpacity(0.5)
                  : Colors.black26,
              blurRadius: widget.isHighlighted ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top left corner
            Positioned(
              top: 4 * widget.scale,
              left: 4 * widget.scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.card.rankString,
                    style: TextStyle(
                      color: widget.card.color,
                      fontSize: 14 * widget.scale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.card.suitSymbol,
                    style: TextStyle(
                      color: widget.card.color,
                      fontSize: 14 * widget.scale,
                    ),
                  ),
                ],
              ),
            ),
            // Center symbol
            Center(
              child: Text(
                widget.card.suitSymbol,
                style: TextStyle(
                  color: widget.card.color,
                  fontSize: 32 * widget.scale,
                ),
              ),
            ),
            // Bottom right corner (rotated)
            Positioned(
              bottom: 4 * widget.scale,
              right: 4 * widget.scale,
              child: Transform.rotate(
                angle: math.pi,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.card.rankString,
                      style: TextStyle(
                        color: widget.card.color,
                        fontSize: 14 * widget.scale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.card.suitSymbol,
                      style: TextStyle(
                        color: widget.card.color,
                        fontSize: 14 * widget.scale,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: 60 * widget.scale,
      height: 84 * widget.scale,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[800]!, Colors.blue[600]!],
        ),
        borderRadius: BorderRadius.circular(6 * widget.scale),
        border: Border.all(color: Colors.blue[900]!, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.casino,
          color: Colors.white.withOpacity(0.3),
          size: 32 * widget.scale,
        ),
      ),
    );
  }
}

class EmptyCardSlot extends StatelessWidget {
  final String? label;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final double scale;

  const EmptyCardSlot({
    Key? key,
    this.label,
    this.isHighlighted = false,
    this.onTap,
    this.scale = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60 * scale,
        height: 84 * scale,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6 * scale),
          border: Border.all(
            color: isHighlighted ? Colors.yellow : Colors.white30,
            width: isHighlighted ? 3 : 2,
            style: BorderStyle.solid,
          ),
        ),
        child: label != null
            ? Center(
                child: Text(
                  label!,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
