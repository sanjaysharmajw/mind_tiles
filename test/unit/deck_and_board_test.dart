import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_tiles_game/game/board/board_controller.dart';
import 'package:mind_tiles_game/game/board/deck_generator.dart';
import 'package:mind_tiles_game/game/board/game_symbol.dart';
import 'package:mind_tiles_game/game/systems/seeded_random.dart';

import '../helpers.dart';

void main() {
  group('DeckGenerator', () {
    test('every board size has exactly two copies of each symbol', () {
      for (var pairs = 1; pairs <= DeckGenerator.maxPairs; pairs++) {
        for (var seed = 0; seed < 5; seed++) {
          final deck = DeckGenerator.generate(
            pairs: pairs,
            random: SeededRandom(seed),
          );
          expect(deck.length, pairs * 2);
          final counts = <GameSymbol, int>{};
          for (final s in deck) {
            counts[s] = (counts[s] ?? 0) + 1;
          }
          expect(counts.length, pairs);
          expect(counts.values.every((c) => c == 2), isTrue);
        }
      }
    });

    test('rejects invalid pair counts', () {
      expect(
        () => DeckGenerator.generate(pairs: 0, random: Random()),
        throwsArgumentError,
      );
      expect(
        () => DeckGenerator.generate(
          pairs: DeckGenerator.maxPairs + 1,
          random: Random(),
        ),
        throwsArgumentError,
      );
    });

    test('validate detects broken decks', () {
      expect(DeckGenerator.isValid([GameSymbol.star, GameSymbol.star]), isTrue);
      expect(
        DeckGenerator.isValid([GameSymbol.star, GameSymbol.heart]),
        isFalse,
      );
      expect(
        DeckGenerator.isValid([
          GameSymbol.star,
          GameSymbol.star,
          GameSymbol.star,
          GameSymbol.star,
        ]),
        isFalse,
      );
      expect(DeckGenerator.isValid([GameSymbol.star]), isFalse);
      expect(DeckGenerator.isValid(const []), isFalse);
    });

    test('same seed gives same deck; different seeds differ', () {
      final a = DeckGenerator.generate(
        pairs: 18,
        random: SeededRandom(42),
        columns: 6,
      );
      final b = DeckGenerator.generate(
        pairs: 18,
        random: SeededRandom(42),
        columns: 6,
      );
      final c = DeckGenerator.generate(
        pairs: 18,
        random: SeededRandom(43),
        columns: 6,
      );
      expect(a, b);
      expect(a, isNot(c));
    });

    test('shuffle is not trivially ordered and positions are spread', () {
      // Over many shuffles, symbol #0 should land in many different positions.
      final positions = <int>{};
      for (var seed = 0; seed < 200; seed++) {
        final deck = DeckGenerator.generate(
          pairs: 8,
          random: SeededRandom(seed),
          maxTier: 1,
          columns: 4,
        );
        final first = deck.first;
        positions.add(deck.lastIndexOf(first));
      }
      expect(positions.length, greaterThan(8));
    });

    test('lower tiers are preferred when sufficient', () {
      final symbols = DeckGenerator.pickSymbols(
        pairs: 8,
        random: SeededRandom(1),
        maxTier: 1,
      );
      expect(symbols.every((s) => s.tier == 1), isTrue);
      final many = DeckGenerator.pickSymbols(
        pairs: 20,
        random: SeededRandom(1),
        maxTier: 1,
      );
      expect(many.toSet().length, 20); // falls back to tier 2 to reach 20
    });

    test('adjacent pairs are limited', () {
      for (var seed = 0; seed < 50; seed++) {
        final deck = DeckGenerator.generate(
          pairs: 18,
          random: SeededRandom(seed),
          columns: 6,
        );
        expect(
          DeckGenerator.adjacentPairCount(deck, 6),
          lessThanOrEqualTo(18 ~/ 4),
        );
      }
    });
  });

  group('BoardController', () {
    late BoardController board;
    setUp(() {
      board = BoardController(
        DeckGenerator.generate(pairs: 8, random: SeededRandom(3), columns: 4),
      );
    });

    test('correct match keeps both tiles matched and counts one move', () {
      final pair = pairIndices(board).first;
      expect(board.select(pair[0]), SelectionResult.firstRevealed);
      expect(board.moves, 0);
      expect(board.select(pair[1]), SelectionResult.matched);
      expect(board.moves, 1);
      expect(board.tiles[pair[0]].isMatched, isTrue);
      expect(board.tiles[pair[1]].isMatched, isTrue);
      expect(board.matchedPairs, 1);
    });

    test('incorrect match locks input until resolved, then hides both', () {
      final m = mismatchedPair(board);
      board.select(m[0]);
      expect(board.select(m[1]), SelectionResult.mismatched);
      expect(board.isResolving, isTrue);
      expect(board.moves, 1);
      final other = board.tiles.firstWhere((t) => !m.contains(t.index)).index;
      expect(board.select(other), SelectionResult.ignoredBusy);
      board.resolveMismatch();
      expect(board.isResolving, isFalse);
      expect(board.tiles[m[0]].isHidden, isTrue);
      expect(board.tiles[m[1]].isHidden, isTrue);
      expect(board.combo, 0);
      expect(board.mismatches, 1);
    });

    test('tapping the same revealed tile twice is ignored and not a move', () {
      board.select(0);
      expect(board.select(0), SelectionResult.ignoredRevealed);
      expect(board.moves, 0);
    });

    test('matched tiles cannot be selected again', () {
      final pair = pairIndices(board).first;
      board.select(pair[0]);
      board.select(pair[1]);
      expect(board.select(pair[0]), SelectionResult.ignoredMatched);
      expect(board.select(pair[1]), SelectionResult.ignoredMatched);
      expect(board.moves, 1);
    });

    test('out of range indices are ignored', () {
      expect(board.select(-1), SelectionResult.ignoredInvalid);
      expect(board.select(16), SelectionResult.ignoredInvalid);
    });

    test('win detection after all pairs matched; combo tracked', () {
      final pairs = pairIndices(board);
      SelectionResult? last;
      for (final p in pairs) {
        board.select(p[0]);
        last = board.select(p[1]);
      }
      expect(last, SelectionResult.completed);
      expect(board.isComplete, isTrue);
      expect(board.moves, 8);
      expect(board.bestCombo, 8);
      expect(board.select(0), SelectionResult.ignoredMatched);
    });

    test(
      'hint finds partner of first revealed tile, else any unmatched pair',
      () {
        final pair = pairIndices(board)[2];
        final h = board.findHintPair()!;
        expect(board.tiles[h[0]].symbol, board.tiles[h[1]].symbol);
        board.select(pair[0]);
        expect(board.findHintPair(), [pair[0], pair[1]]);
      },
    );

    test('constructor rejects invalid decks', () {
      expect(
        () => BoardController([GameSymbol.star, GameSymbol.heart]),
        throwsA(isA<InvalidDeckException>()),
      );
    });

    test('restore drops inconsistent singletons', () {
      final pair = pairIndices(board).first;
      board.restore(
        matchedIndices: {pair[0], pair[1], pairIndices(board)[1][0]},
        moves: 4,
        mismatches: 3,
        combo: 1,
        bestCombo: 1,
      );
      expect(board.matchedPairs, 1);
      expect(board.tiles.where((t) => t.isMatched).length, 2);
      expect(board.moves, 4);
    });
  });
}
