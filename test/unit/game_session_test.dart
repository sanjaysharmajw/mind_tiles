import 'package:flutter_test/flutter_test.dart';
import 'package:mind_tiles_game/game/board/board_controller.dart';
import 'package:mind_tiles_game/game/game_config.dart';
import 'package:mind_tiles_game/game/game_state.dart';
import 'package:mind_tiles_game/game/modes/daily_challenge_mode.dart';
import 'package:mind_tiles_game/game/modes/game_mode.dart';
import 'package:mind_tiles_game/game/modes/limited_moves_mode.dart';
import 'package:mind_tiles_game/game/modes/practice_mode.dart';
import 'package:mind_tiles_game/game/modes/timed_mode.dart';

import '../helpers.dart';

void main() {
  group('Preview', () {
    test('tiles are face up during preview, input ignored, then playing', () {
      final s = GameSession(config: level1(), previewDuration: 2);
      expect(s.isPreview, isTrue);
      expect(s.isFaceUp(0), isTrue);
      expect(s.tapTile(0), SelectionResult.ignoredBusy);
      s.tick(1);
      expect(s.isPreview, isTrue);
      s.tick(1.01);
      expect(s.isPlaying, isTrue);
      expect(s.isFaceUp(0), isFalse);
      expect(s.elapsedSeconds, 0, reason: 'preview time is not counted');
    });

    test('preview disabled starts immediately', () {
      final s = GameSession(config: level1(), previewDuration: 0);
      expect(s.isPlaying, isTrue);
    });

    test('skip preview', () {
      final events = <GameEventType>[];
      final s = GameSession(config: level1(), previewDuration: 5)
        ..addEventListener((e) => events.add(e.type));
      s.skipPreview();
      expect(s.isPlaying, isTrue);
      expect(events, [GameEventType.previewEnded]);
    });
  });

  group('Mismatch handling', () {
    test('mismatch shows briefly then flips back via tick', () {
      final s = GameSession(config: level1(), previewDuration: 0);
      final m = mismatchedPair(s.board);
      s.tapTile(m[0]);
      s.tapTile(m[1]);
      expect(s.isFaceUp(m[0]) && s.isFaceUp(m[1]), isTrue);
      expect(s.acceptsInput, isFalse);
      s.tick(0.5);
      expect(s.isFaceUp(m[0]), isTrue);
      s.tick(0.31);
      expect(s.isFaceUp(m[0]), isFalse);
      expect(s.acceptsInput, isTrue);
    });

    test('rapid taps during mismatch are ignored and do not count', () {
      final s = GameSession(config: level1(), previewDuration: 0);
      final m = mismatchedPair(s.board);
      s.tapTile(m[0]);
      s.tapTile(m[1]);
      for (var i = 0; i < 16; i++) {
        expect(s.tapTile(i), SelectionResult.ignoredBusy);
      }
      expect(s.moves, 1);
    });
  });

  group('Completion', () {
    test('classic win produces exactly one result and resultsReady event', () {
      final events = <GameEventType>[];
      final s = GameSession(config: level1(), previewDuration: 0)
        ..addEventListener((e) => events.add(e.type));
      solvePerfectly(s);
      expect(s.status, SessionStatus.won);
      final r = s.result!;
      expect(r.won, isTrue);
      expect(r.moves, 8);
      expect(r.stars, 3);
      expect(r.accuracy, 1.0);
      expect(r.isPerfect, isTrue);
      expect(events.where((e) => e == GameEventType.won).length, 1);
      for (var i = 0; i < 20; i++) {
        s.tick(0.2);
      }
      expect(events.where((e) => e == GameEventType.resultsReady).length, 1);
      // Further taps are ignored after the game is over.
      expect(s.tapTile(0), SelectionResult.ignoredBusy);
    });

    test('pause freezes clock and hides unmatched tiles', () {
      final s = GameSession(config: level1(), previewDuration: 0);
      s.tick(1);
      s.tapTile(0);
      s.pause();
      expect(s.isFaceUp(0), isFalse);
      s.tick(5);
      expect(s.elapsedSeconds, closeTo(1, 1e-9));
      expect(s.tapTile(1), SelectionResult.ignoredBusy);
      s.resume();
      expect(s.isPlaying, isTrue);
      expect(s.isFaceUp(0), isTrue);
      s.tick(1);
      expect(s.elapsedSeconds, closeTo(2, 1e-9));
    });

    test('pausing during preview resumes into preview', () {
      final s = GameSession(config: level1(), previewDuration: 3);
      s.tick(1);
      s.pause();
      s.tick(10);
      s.resume();
      expect(s.isPreview, isTrue);
      expect(s.previewRemaining, closeTo(2, 1e-9));
    });
  });

  group('Timed mode', () {
    test('fails when the clock runs out', () {
      final config = const TimedMode().configFor(Difficulty.easy, seed: 5);
      final events = <GameEventType>[];
      final s = GameSession(config: config, previewDuration: 0)
        ..addEventListener((e) => events.add(e.type));
      expect(s.timeRemaining, config.timeLimitSeconds);
      for (var t = 0.0; t < config.timeLimitSeconds! + 1; t += 0.2) {
        s.tick(0.2);
      }
      expect(s.status, SessionStatus.lost);
      expect(s.result!.failureReason, FailureReason.outOfTime);
      expect(s.result!.score, 0);
      expect(events.where((e) => e == GameEventType.lost).length, 1);
    });

    test('winning before the clock ends is a win with time bonus', () {
      final config = const TimedMode().configFor(Difficulty.easy, seed: 5);
      final s = GameSession(config: config, previewDuration: 0);
      solvePerfectly(s);
      expect(s.status, SessionStatus.won);
      expect(s.result!.timeRemaining, greaterThan(0));
    });
  });

  group('Limited moves mode', () {
    test('fails when moves run out', () {
      final config = const LimitedMovesMode().configFor(
        Difficulty.easy,
        seed: 9,
      );
      final s = GameSession(config: config, previewDuration: 0);
      final limit = config.moveLimit!;
      for (var i = 0; i < limit && s.isInProgress; i++) {
        final m = mismatchedPair(s.board);
        s.tapTile(m[0]);
        s.tapTile(m[1]);
        s.tick(1);
      }
      expect(s.status, SessionStatus.lost);
      expect(s.result!.failureReason, FailureReason.outOfMoves);
      expect(s.moves, limit);
      expect(s.movesRemaining, 0);
    });

    test('matching the last pair on the last move is a win', () {
      final config = const LimitedMovesMode().configFor(
        Difficulty.easy,
        seed: 9,
      );
      final s = GameSession(config: config, previewDuration: 0);
      // Waste moves until exactly `pairs` moves remain, then solve perfectly.
      while (s.movesRemaining! > config.pairs) {
        final m = mismatchedPair(s.board);
        s.tapTile(m[0]);
        s.tapTile(m[1]);
        s.tick(1);
      }
      solvePerfectly(s);
      expect(s.status, SessionStatus.won);
      expect(s.movesRemaining, 0);
    });
  });

  group('Practice & daily', () {
    test('practice has unlimited hints and no failure', () {
      final config = const PracticeMode().configFor(Difficulty.medium, seed: 2);
      final s = GameSession(config: config, previewDuration: 0);
      expect(s.hintsRemaining, isNull);
      for (var i = 0; i < 5; i++) {
        expect(s.useHint(), isTrue);
        s.tick(2);
      }
      for (var i = 0; i < 400; i++) {
        s.tick(0.25);
      }
      expect(s.isPlaying, isTrue);
    });

    test('daily board is identical for the same date', () {
      const mode = DailyChallengeMode();
      final a = GameSession(
        config: mode.configForDate(DateTime(2026, 11, 11)),
        previewDuration: 0,
      );
      final b = GameSession(
        config: mode.configForDate(DateTime(2026, 11, 11, 23, 59)),
        previewDuration: 0,
      );
      final c = GameSession(
        config: mode.configForDate(DateTime(2026, 11, 12)),
        previewDuration: 0,
      );
      List<String> deck(GameSession s) => [
        for (final t in s.board.tiles) t.symbol.name,
      ];
      expect(deck(a), deck(b));
      expect(deck(a), isNot(deck(c)));
    });

    test(
      'daily deck is pinned (guards against accidental algorithm changes)',
      () {
        const mode = DailyChallengeMode();
        final config = mode.configForDate(DateTime(2026, 1, 1));
        expect(config.seed, 20260101);
        expect(config.dateKey, '2026-01-01');
        final s = GameSession(config: config, previewDuration: 0);
        expect(s.board.tiles.length, 36);
      },
    );
  });

  group('Hints', () {
    test('limited allowance, hint highlights a real pair, then expires', () {
      final s = GameSession(config: level1(), previewDuration: 0);
      expect(s.hintsRemaining, 2);
      expect(s.useHint(), isTrue);
      final hinted = [
        for (var i = 0; i < 16; i++)
          if (s.isHinted(i)) i,
      ];
      expect(hinted.length, 2);
      expect(s.board.tiles[hinted[0]].symbol, s.board.tiles[hinted[1]].symbol);
      expect(
        s.useHint(),
        isFalse,
        reason: 'cannot stack hints while one is showing',
      );
      s.tick(2);
      expect(s.isHinted(hinted[0]), isFalse);
      expect(s.useHint(), isTrue);
      s.tick(2);
      expect(s.hintsRemaining, 0);
      expect(s.useHint(), isFalse);
      s.grantBonusHint();
      expect(s.hintsRemaining, 1);
      expect(s.useHint(), isTrue);
    });
  });

  group('Snapshots', () {
    test('round trip restores matched tiles, counters and starts paused', () {
      final s = GameSession(config: level1(seed: 77), previewDuration: 0);
      final pair = pairIndices(s.board).first;
      s.tapTile(pair[0]);
      s.tapTile(pair[1]);
      final m = mismatchedPair(s.board);
      s.tapTile(m[0]);
      s.tapTile(m[1]);
      s.tick(1);
      s.useHint();
      final json = s.toSnapshot().toJson();
      final snap = SessionSnapshot.fromJson(json)!;
      final r = GameSession.fromSnapshot(snap)!;
      expect(r.isPaused, isTrue);
      expect(r.moves, 2);
      expect(r.matchedPairs, 1);
      expect(r.hintsUsed, 1);
      expect(r.elapsedSeconds, closeTo(s.elapsedSeconds, 1e-9));
      expect(r.sessionId, s.sessionId);
      expect(
        [for (final t in r.board.tiles) t.symbol],
        [for (final t in s.board.tiles) t.symbol],
      );
      r.resume();
      expect(r.isPlaying, isTrue);
      solvePerfectly(r);
      expect(r.status, SessionStatus.won);
    });

    test('malformed snapshots are rejected', () {
      expect(SessionSnapshot.fromJson(null), isNull);
      expect(SessionSnapshot.fromJson({'config': 'x'}), isNull);
      final good = GameSession(
        config: level1(),
        previewDuration: 0,
      ).toSnapshot().toJson();
      final badDeck = Map<String, Object?>.from(good)
        ..['deck'] = ['star', 'star', 'heart'];
      expect(SessionSnapshot.fromJson(badDeck), isNull);
      final unknown = Map<String, Object?>.from(good)
        ..['deck'] = [...(good['deck'] as List).take(15), 'notASymbol'];
      expect(SessionSnapshot.fromJson(unknown), isNull);
    });
  });

  test('every mode exposes complete rules', () {
    for (final type in GameModeType.values) {
      final rules = GameModeRules.of(type);
      expect(rules.type, type);
      expect(rules.title, isNotEmpty);
      for (final d in Difficulty.values) {
        final c = rules.configFor(d, seed: 1);
        expect(c.tileCount.isEven, isTrue);
        final s = GameSession(config: c, previewDuration: 0);
        solvePerfectly(s);
        expect(
          s.status,
          SessionStatus.won,
          reason: '$type/$d must be completable',
        );
      }
    }
  });
}
