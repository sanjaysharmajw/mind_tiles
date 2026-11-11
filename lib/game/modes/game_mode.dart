import '../game_config.dart';
import 'classic_mode.dart';
import 'daily_challenge_mode.dart';
import 'limited_moves_mode.dart';
import 'practice_mode.dart';
import 'timed_mode.dart';

enum FailureReason { outOfTime, outOfMoves }

/// Read-only view of a game in progress, used by mode rules.
class ModeProgress {
  const ModeProgress({
    required this.elapsedSeconds,
    required this.moves,
    required this.isComplete,
  });
  final double elapsedSeconds;
  final int moves;
  final bool isComplete;
}

/// Rules that distinguish one game mode from another.
abstract class GameModeRules {
  const GameModeRules();

  GameModeType get type;
  String get title;
  String get tagline;

  /// Multiplier applied to the final score.
  double get scoreMultiplier;

  /// Whether results update statistics, records and achievements.
  bool get recordsProgress => true;

  /// Whether this mode lets the player pick a difficulty.
  bool get usesDifficultySelection => true;

  /// Whether every difficulty is available regardless of campaign progress.
  bool get allDifficultiesUnlocked => false;

  /// Builds a config for a difficulty-based game.
  LevelConfig configFor(Difficulty difficulty, {required int seed});

  /// Returns a failure reason if the game is lost, otherwise null.
  /// A completed board is never a failure.
  FailureReason? checkFailure(LevelConfig config, ModeProgress progress) {
    if (progress.isComplete) return null;
    final limit = config.timeLimitSeconds;
    if (limit != null && progress.elapsedSeconds >= limit) {
      return FailureReason.outOfTime;
    }
    final moveLimit = config.moveLimit;
    if (moveLimit != null && progress.moves >= moveLimit) {
      return FailureReason.outOfMoves;
    }
    return null;
  }

  static GameModeRules of(GameModeType type) => switch (type) {
    GameModeType.classic => const ClassicMode(),
    GameModeType.timed => const TimedMode(),
    GameModeType.limitedMoves => const LimitedMovesMode(),
    GameModeType.daily => const DailyChallengeMode(),
    GameModeType.practice => const PracticeMode(),
  };
}
