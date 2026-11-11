import 'package:flutter_test/flutter_test.dart';
import 'package:mind_tiles_game/game/game_config.dart';
import 'package:mind_tiles_game/game/modes/limited_moves_mode.dart';
import 'package:mind_tiles_game/game/modes/practice_mode.dart';
import 'package:mind_tiles_game/game/modes/timed_mode.dart';
import 'package:mind_tiles_game/game/systems/level_progression.dart';
import 'package:mind_tiles_game/game/systems/scoring_system.dart';

import '../helpers.dart';

void main() {
  group('ScoringSystem', () {
    test('documented formula for a perfect easy classic game', () {
      // pairs 8, D 1.0: base 800, efficiency 800, par 32s, elapsed 20s -> 12*5 = 60,
      // combo 8*15 = 120, hints 0, M 1.0 -> 1780
      final s = ScoringSystem.calculate(
        ScoreInput(
          config: level1(),
          moves: 8,
          elapsedSeconds: 20,
          bestCombo: 8,
          hintsUsed: 0,
        ),
      );
      expect(s.base, 800);
      expect(s.efficiencyBonus, 800);
      expect(s.timeBonus, 60);
      expect(s.comboBonus, 120);
      expect(s.total, 1780);
      expect(s.accuracy, 1.0);
      expect(s.stars, 3);
    });

    test('more moves lower the score and stars', () {
      ScoreBreakdown run(int moves) => ScoringSystem.calculate(
        ScoreInput(
          config: level1(),
          moves: moves,
          elapsedSeconds: 40,
          bestCombo: 1,
          hintsUsed: 0,
        ),
      );
      expect(run(8).total, greaterThan(run(16).total));
      expect(run(12).stars, 3); // <= ceil(8*1.5)
      expect(run(13).stars, 2);
      expect(run(18).stars, 2); // <= ceil(8*2.25)
      expect(run(19).stars, 1);
      expect(run(16).accuracy, 0.5);
    });

    test(
      'timed mode rewards remaining time; limited rewards remaining moves',
      () {
        final timed = const TimedMode().configFor(Difficulty.easy, seed: 1);
        final fast = ScoringSystem.calculate(
          ScoreInput(
            config: timed,
            moves: 10,
            elapsedSeconds: 10,
            bestCombo: 2,
            hintsUsed: 0,
          ),
        );
        final slow = ScoringSystem.calculate(
          ScoreInput(
            config: timed,
            moves: 10,
            elapsedSeconds: 40,
            bestCombo: 2,
            hintsUsed: 0,
          ),
        );
        expect(fast.timeBonus, (timed.timeLimitSeconds! - 10) * 10);
        expect(fast.total, greaterThan(slow.total));
        expect(fast.modeMultiplier, 1.2);

        final limited = const LimitedMovesMode().configFor(
          Difficulty.easy,
          seed: 1,
        );
        final s = ScoringSystem.calculate(
          ScoreInput(
            config: limited,
            moves: 10,
            elapsedSeconds: 10,
            bestCombo: 2,
            hintsUsed: 0,
          ),
        );
        expect(s.movesBonus, (limited.moveLimit! - 10) * 20);
      },
    );

    test('score never negative and never overflows', () {
      final practice = const PracticeMode().configFor(Difficulty.easy, seed: 1);
      final s = ScoringSystem.calculate(
        ScoreInput(
          config: practice,
          moves: 1000,
          elapsedSeconds: 99999,
          bestCombo: 0,
          hintsUsed: 500,
        ),
      );
      expect(s.total, 0);
      final big = ScoringSystem.calculate(
        ScoreInput(
          config: level1(),
          moves: 8,
          elapsedSeconds: -1e12,
          bestCombo: 1 << 30,
          hintsUsed: 0,
        ),
      );
      expect(big.total, ScoringSystem.maxScore);
    });

    test('moves below the theoretical minimum are clamped', () {
      final s = ScoringSystem.calculate(
        ScoreInput(
          config: level1(),
          moves: 0,
          elapsedSeconds: 5,
          bestCombo: 0,
          hintsUsed: 0,
        ),
      );
      expect(s.accuracy, 1.0);
    });

    test('hints reduce the score', () {
      ScoreBreakdown run(int hints) => ScoringSystem.calculate(
        ScoreInput(
          config: level1(),
          moves: 10,
          elapsedSeconds: 30,
          bestCombo: 3,
          hintsUsed: hints,
        ),
      );
      expect(run(0).total - run(2).total, 100);
    });
  });

  group('LevelProgression', () {
    test(
      '30 valid levels with growing boards and shrinking previews in a group',
      () {
        var lastPairs = 0;
        for (var l = 1; l <= LevelProgression.totalLevels; l++) {
          final c = LevelProgression.levelConfig(l, seed: 1);
          expect(c.tileCount.isEven, isTrue);
          expect(c.pairs, greaterThanOrEqualTo(lastPairs));
          expect(c.previewSeconds, greaterThanOrEqualTo(2.5));
          expect(c.level, l);
          expect(c.columns, lessThanOrEqualTo(8));
          lastPairs = c.pairs;
        }
        expect(LevelProgression.levelConfig(1, seed: 1).pairs, 8);
        expect(LevelProgression.levelConfig(10, seed: 1).pairs, 18);
        expect(LevelProgression.levelConfig(22, seed: 1).pairs, 32);
        expect(LevelProgression.levelConfig(30, seed: 1).pairs, 40);
        expect(
          LevelProgression.levelConfig(1, seed: 1).previewSeconds,
          greaterThan(LevelProgression.levelConfig(3, seed: 1).previewSeconds),
        );
      },
    );

    test('invalid levels throw', () {
      expect(() => LevelProgression.levelConfig(0, seed: 1), throwsRangeError);
      expect(() => LevelProgression.levelConfig(31, seed: 1), throwsRangeError);
    });

    test('difficulty tiers and unlock rules', () {
      expect(LevelProgression.difficultyOfLevel(1), Difficulty.easy);
      expect(LevelProgression.difficultyOfLevel(7), Difficulty.medium);
      expect(LevelProgression.difficultyOfLevel(16), Difficulty.hard);
      expect(LevelProgression.difficultyOfLevel(25), Difficulty.expert);
      expect(LevelProgression.isDifficultyUnlocked(Difficulty.easy, 0), isTrue);
      expect(
        LevelProgression.isDifficultyUnlocked(Difficulty.medium, 5),
        isFalse,
      );
      expect(
        LevelProgression.isDifficultyUnlocked(Difficulty.medium, 6),
        isTrue,
      );
      expect(
        LevelProgression.isDifficultyUnlocked(Difficulty.expert, 23),
        isFalse,
      );
      expect(LevelProgression.unlockedLevelAfter(0), 1);
      expect(LevelProgression.unlockedLevelAfter(5), 6);
      expect(LevelProgression.unlockedLevelAfter(30), 30);
    });

    test('LevelConfig JSON round trip', () {
      final c = const TimedMode().configFor(Difficulty.hard, seed: 123);
      expect(LevelConfig.fromJson(c.toJson()), c);
      expect(LevelConfig.fromJson({'mode': 'classic'}), isNull);
      expect(
        LevelConfig.fromJson({...c.toJson(), 'columns': 3, 'rows': 3}),
        isNull,
      );
    });
  });
}
