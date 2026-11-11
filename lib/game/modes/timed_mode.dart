import '../game_config.dart';
import 'game_mode.dart';

/// Finish the board before the countdown expires. Preview time does not
/// count against the clock.
class TimedMode extends GameModeRules {
  const TimedMode();

  @override
  GameModeType get type => GameModeType.timed;
  @override
  String get title => 'Timed Challenge';
  @override
  String get tagline => 'Beat the clock';
  @override
  double get scoreMultiplier => 1.2;

  static double secondsPerPair(Difficulty d) => switch (d) {
    Difficulty.easy => 6.0,
    Difficulty.medium => 5.0,
    Difficulty.hard => 4.5,
    Difficulty.expert => 4.2,
  };

  static int timeLimitFor(Difficulty d) =>
      (BoardSpec.forDifficulty(d).pairs * secondsPerPair(d)).round();

  @override
  LevelConfig configFor(Difficulty difficulty, {required int seed}) {
    final spec = BoardSpec.forDifficulty(difficulty);
    return LevelConfig(
      mode: type,
      difficulty: difficulty,
      columns: spec.columns,
      rows: spec.rows,
      previewSeconds: double.parse(
        (1.5 + spec.pairs * 0.15).toStringAsFixed(1),
      ),
      symbolTier: BoardSpec.symbolTierFor(difficulty),
      seed: seed,
      timeLimitSeconds: timeLimitFor(difficulty),
      hintAllowance: 1,
    );
  }

  @override
  FailureReason? checkFailure(LevelConfig config, ModeProgress progress) {
    if (progress.isComplete) return null;
    if (progress.elapsedSeconds >= config.timeLimitSeconds!) {
      return FailureReason.outOfTime;
    }
    return null;
  }
}
