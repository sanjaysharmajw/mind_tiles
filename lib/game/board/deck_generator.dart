import 'dart:math';

import 'game_symbol.dart';

/// Thrown when a deck violates the "exactly two of each symbol" invariant.
class InvalidDeckException implements Exception {
  InvalidDeckException(this.message);
  final String message;
  @override
  String toString() => 'InvalidDeckException: $message';
}

/// Builds shuffled, validated decks of symbol pairs.
class DeckGenerator {
  const DeckGenerator._();

  /// Maximum number of pairs supported by the symbol catalogue.
  static int get maxPairs => GameSymbol.values.length;

  /// Picks [pairs] distinct symbols (preferring tiers <= [maxTier]), doubles
  /// them and shuffles with [random].
  ///
  /// To keep boards interesting the shuffle is retried (up to a bound) when
  /// too many pairs end up side by side; the result is always validated.
  static List<GameSymbol> generate({
    required int pairs,
    required Random random,
    int maxTier = GameSymbol.maxTier,
    int? columns,
  }) {
    if (pairs < 1 || pairs > maxPairs) {
      throw ArgumentError.value(pairs, 'pairs', 'must be 1..$maxPairs');
    }
    final symbols = pickSymbols(pairs: pairs, random: random, maxTier: maxTier);
    final deck = <GameSymbol>[...symbols, ...symbols];
    final cols = columns ?? _guessColumns(deck.length);
    final maxAdjacent = max(1, pairs ~/ 4);
    for (var attempt = 0; attempt < 12; attempt++) {
      shuffle(deck, random);
      if (adjacentPairCount(deck, cols) <= maxAdjacent) break;
    }
    validate(deck);
    return deck;
  }

  /// Chooses the distinct symbols for a board. Lower tiers are always used
  /// first; if they are not sufficient the next tier is mixed in.
  static List<GameSymbol> pickSymbols({
    required int pairs,
    required Random random,
    int maxTier = GameSymbol.maxTier,
  }) {
    var tier = maxTier.clamp(1, GameSymbol.maxTier);
    var pool = GameSymbol.upToTier(tier);
    while (pool.length < pairs && tier < GameSymbol.maxTier) {
      tier++;
      pool = GameSymbol.upToTier(tier);
    }
    final candidates = List<GameSymbol>.of(pool);
    shuffle(candidates, random);
    return candidates.take(pairs).toList(growable: false);
  }

  /// In-place Fisher–Yates shuffle.
  static void shuffle<T>(List<T> list, Random random) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  /// Number of matching pairs that are horizontally or vertically adjacent.
  static int adjacentPairCount(List<GameSymbol> deck, int columns) {
    var count = 0;
    for (var i = 0; i < deck.length; i++) {
      final right = i + 1;
      if (right % columns != 0 &&
          right < deck.length &&
          deck[right] == deck[i]) {
        count++;
      }
      final below = i + columns;
      if (below < deck.length && deck[below] == deck[i]) count++;
    }
    return count;
  }

  /// Throws [InvalidDeckException] unless every symbol appears exactly twice.
  static void validate(List<GameSymbol> deck) {
    if (deck.isEmpty || deck.length.isOdd) {
      throw InvalidDeckException(
        'deck size ${deck.length} must be even and > 0',
      );
    }
    final counts = <GameSymbol, int>{};
    for (final s in deck) {
      counts[s] = (counts[s] ?? 0) + 1;
    }
    for (final entry in counts.entries) {
      if (entry.value != 2) {
        throw InvalidDeckException(
          '${entry.key.name} appears ${entry.value} times (expected 2)',
        );
      }
    }
  }

  static bool isValid(List<GameSymbol> deck) {
    try {
      validate(deck);
      return true;
    } on InvalidDeckException {
      return false;
    }
  }

  static int _guessColumns(int length) {
    var c = sqrt(length).floor();
    while (c > 1 && length % c != 0) {
      c--;
    }
    return max(1, c);
  }
}
