import 'dart:math';

import '../game_config.dart';

/// Defines the 30-level Classic campaign and unlock rules.
///
/// Levels come in groups of three that share a board size. Within a group
/// the preview gets shorter; across groups boards grow and the symbol set
/// becomes harder to tell apart.
class LevelProgression {
  const LevelProgression._();

  static const int totalLevels = 30;

  static const List<(int, int)> _groupBoards = [
    (4, 4), // 8 pairs
    (4, 5), // 10
    (5, 6), // 15
    (6, 6), // 18
    (6, 7), // 21
    (6, 8), // 24
    (7, 8), // 28
    (8, 8), // 32
    (8, 9), // 36
    (8, 10), // 40
  ];

  static bool isValidLevel(int level) => level >= 1 && level <= totalLevels;

  static LevelConfig levelConfig(int level, {required int seed}) {
    if (!isValidLevel(level)) {
      throw RangeError.range(level, 1, totalLevels, 'level');
    }
    final group = (level - 1) ~/ 3;
    final step = (level - 1) % 3;
    final (columns, rows) = _groupBoards[group];
    final pairs = columns * rows ~/ 2;
    final preview = max(2.5, 2.0 + pairs * 0.2 - step * 0.5);
    return LevelConfig(
      mode: GameModeType.classic,
      difficulty: Difficulty.fromPairs(pairs),
      columns: columns,
      rows: rows,
      previewSeconds: double.parse(preview.toStringAsFixed(1)),
      symbolTier: group < 3 ? 1 : (group < 6 ? 2 : 3),
      seed: seed,
      level: level,
      hintAllowance: 2,
    );
  }

  static Difficulty difficultyOfLevel(int level) =>
      levelConfig(level, seed: 0).difficulty;

  /// Classic level the player must have *completed* before a difficulty is
  /// available in Timed and Limited Moves modes (Easy is always available).
  static int requiredLevelFor(Difficulty d) => switch (d) {
    Difficulty.easy => 0,
    Difficulty.medium => 6,
    Difficulty.hard => 15,
    Difficulty.expert => 24,
  };

  /// [highestCompleted] is the highest campaign level the player has beaten.
  static bool isDifficultyUnlocked(Difficulty d, int highestCompleted) =>
      highestCompleted >= requiredLevelFor(d);

  /// Highest level that can be played, given the highest completed level.
  static int unlockedLevelAfter(int highestCompleted) =>
      min(totalLevels, max(1, highestCompleted + 1));
}
