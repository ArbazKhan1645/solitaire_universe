import 'package:flutter/material.dart';

enum Suit { hearts, diamonds, clubs, spades }

enum Rank {
  ace,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
}

class PlayingCard {
  final Suit suit;
  final Rank rank;
  bool isFaceUp;
  bool isDragging;
  Offset position;

  PlayingCard({
    required this.suit,
    required this.rank,
    this.isFaceUp = false,
    this.isDragging = false,
    this.position = Offset.zero,
  });

  Color get color {
    return (suit == Suit.hearts || suit == Suit.diamonds)
        ? Colors.red
        : Colors.black;
  }

  String get suitSymbol {
    switch (suit) {
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
    }
  }

  String get rankString {
    switch (rank) {
      case Rank.ace:
        return 'A';
      case Rank.two:
        return '2';
      case Rank.three:
        return '3';
      case Rank.four:
        return '4';
      case Rank.five:
        return '5';
      case Rank.six:
        return '6';
      case Rank.seven:
        return '7';
      case Rank.eight:
        return '8';
      case Rank.nine:
        return '9';
      case Rank.ten:
        return '10';
      case Rank.jack:
        return 'J';
      case Rank.queen:
        return 'Q';
      case Rank.king:
        return 'K';
    }
  }

  int get value {
    return rank.index + 1;
  }

  bool get isRed => color == Colors.red;

  bool get isBlack => color == Colors.black;

  PlayingCard copyWith({
    Suit? suit,
    Rank? rank,
    bool? isFaceUp,
    bool? isDragging,
    Offset? position,
  }) {
    return PlayingCard(
      suit: suit ?? this.suit,
      rank: rank ?? this.rank,
      isFaceUp: isFaceUp ?? this.isFaceUp,
      isDragging: isDragging ?? this.isDragging,
      position: position ?? this.position,
    );
  }

  @override
  String toString() {
    return '$rankString$suitSymbol';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayingCard && other.suit == suit && other.rank == rank;
  }

  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;
}
