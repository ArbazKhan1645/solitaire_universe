import 'dart:math';

import 'package:solitaire_universe/model/playing_card.dart';

class DeckManager {
  static List<PlayingCard> createStandardDeck({bool faceUp = false}) {
    List<PlayingCard> deck = [];

    for (var suit in Suit.values) {
      for (var rank in Rank.values) {
        deck.add(PlayingCard(suit: suit, rank: rank, isFaceUp: faceUp));
      }
    }

    return deck;
  }

  static List<PlayingCard> createMultipleDecks(
    int count, {
    bool faceUp = false,
  }) {
    List<PlayingCard> allCards = [];

    for (int i = 0; i < count; i++) {
      allCards.addAll(createStandardDeck(faceUp: faceUp));
    }

    return allCards;
  }

  static List<PlayingCard> shuffle(List<PlayingCard> deck, {int? seed}) {
    List<PlayingCard> shuffled = List.from(deck);
    Random random = seed != null ? Random(seed) : Random();

    for (int i = shuffled.length - 1; i > 0; i--) {
      int j = random.nextInt(i + 1);
      var temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }

    return shuffled;
  }

  static int generateSeed() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  static bool canPlaceOn(
    PlayingCard card,
    PlayingCard target, {
    bool alternateColors = true,
  }) {
    if (alternateColors) {
      // Klondike-style: must be opposite color and one rank lower
      return card.color != target.color && card.value == target.value - 1;
    } else {
      // Just check rank
      return card.value == target.value - 1;
    }
  }

  static bool isValidFoundationPlacement(
    PlayingCard card,
    List<PlayingCard> foundation,
  ) {
    if (foundation.isEmpty) {
      return card.rank == Rank.ace;
    }

    PlayingCard topCard = foundation.last;
    return card.suit == topCard.suit && card.value == topCard.value + 1;
  }

  static bool isSequence(
    List<PlayingCard> cards, {
    bool alternateColors = true,
  }) {
    if (cards.length <= 1) return true;

    for (int i = 0; i < cards.length - 1; i++) {
      PlayingCard current = cards[i];
      PlayingCard next = cards[i + 1];

      if (alternateColors && current.color == next.color) {
        return false;
      }

      if (current.value != next.value + 1) {
        return false;
      }
    }

    return true;
  }

  static List<PlayingCard> dealKlondike(List<PlayingCard> deck) {
    // Deal 7 piles with increasing cards
    List<PlayingCard> dealtCards = [];
    int cardIndex = 0;

    for (int pile = 0; pile < 7; pile++) {
      for (int card = 0; card <= pile; card++) {
        if (cardIndex < deck.length) {
          PlayingCard cardToDeal = deck[cardIndex];
          // Face up if it's the last card in the pile
          cardToDeal.isFaceUp = (card == pile);
          dealtCards.add(cardToDeal);
          cardIndex++;
        }
      }
    }

    return dealtCards;
  }

  static bool hasMovesAvailable(
    List<List<PlayingCard>> tableau,
    List<PlayingCard> stock,
    List<PlayingCard> waste,
  ) {
    // Check if any tableau card can be moved to another pile
    for (int i = 0; i < tableau.length; i++) {
      if (tableau[i].isEmpty) continue;

      List<PlayingCard> faceUpCards = tableau[i]
          .where((c) => c.isFaceUp)
          .toList();
      if (faceUpCards.isEmpty) continue;

      for (int j = 0; j < tableau.length; j++) {
        if (i == j) continue;

        if (tableau[j].isEmpty) {
          // Can move King to empty space
          if (faceUpCards.first.rank == Rank.king) return true;
        } else {
          PlayingCard target = tableau[j].last;
          if (canPlaceOn(faceUpCards.first, target)) return true;
        }
      }
    }

    // Check waste card
    if (waste.isNotEmpty) {
      PlayingCard wasteCard = waste.last;
      for (var pile in tableau) {
        if (pile.isEmpty) {
          if (wasteCard.rank == Rank.king) return true;
        } else {
          if (canPlaceOn(wasteCard, pile.last)) return true;
        }
      }
    }

    // If stock is not empty, there are still moves
    if (stock.isNotEmpty) return true;

    return false;
  }

  static List<int> findHint(
    List<List<PlayingCard>> tableau,
    List<PlayingCard> waste,
    List<List<PlayingCard>> foundations,
  ) {
    // Returns [sourceType, sourceIndex, destType, destIndex]
    // sourceType/destType: 0=tableau, 1=waste, 2=foundation

    // Try moving to foundation first (highest priority)
    for (int i = 0; i < tableau.length; i++) {
      if (tableau[i].isEmpty || !tableau[i].last.isFaceUp) continue;

      for (int j = 0; j < foundations.length; j++) {
        if (isValidFoundationPlacement(tableau[i].last, foundations[j])) {
          return [0, i, 2, j];
        }
      }
    }

    if (waste.isNotEmpty) {
      for (int j = 0; j < foundations.length; j++) {
        if (isValidFoundationPlacement(waste.last, foundations[j])) {
          return [1, 0, 2, j];
        }
      }
    }

    // Try tableau to tableau moves
    for (int i = 0; i < tableau.length; i++) {
      if (tableau[i].isEmpty) continue;

      List<PlayingCard> faceUpCards = tableau[i]
          .where((c) => c.isFaceUp)
          .toList();
      if (faceUpCards.isEmpty) continue;

      for (int j = 0; j < tableau.length; j++) {
        if (i == j) continue;

        if (tableau[j].isEmpty) {
          if (faceUpCards.first.rank == Rank.king &&
              faceUpCards.length < tableau[i].length) {
            return [0, i, 0, j];
          }
        } else {
          if (canPlaceOn(faceUpCards.first, tableau[j].last)) {
            return [0, i, 0, j];
          }
        }
      }
    }

    // Try waste to tableau
    if (waste.isNotEmpty) {
      for (int j = 0; j < tableau.length; j++) {
        if (tableau[j].isEmpty) {
          if (waste.last.rank == Rank.king) {
            return [1, 0, 0, j];
          }
        } else {
          if (canPlaceOn(waste.last, tableau[j].last)) {
            return [1, 0, 0, j];
          }
        }
      }
    }

    return [];
  }
}
