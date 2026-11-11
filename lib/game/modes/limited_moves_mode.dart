import '../game_config.dart';
import 'game_mode.dart';

/// Clear the board within a fixed number of moves (pair attempts).
class LimitedMovesMode extends GameModeRules {
  const LimitedMovesMode();

  @override
  GameModeType get type => GameModeType.limitedMoves;
  @override
  String get title => 'Limited Moves';
  @override
  String get tagline => 'Every flip counts';
  @override
  double get scoreMultiplier => 1.2;

  static double movesPerPair(Difficulty d) => switch (d) {
    Difficulty.easy => 2.5,
    Difficulty.medium => 2.2,
    Difficulty.hard => 2.0,
    Difficulty.expert => 1.9,
  };

  static int moveLimitFor(Difficulty d) =>
      (BoardSpec.forDifficulty(d).pairs * movesPerPair(d)).ceil();

  @override
  LevelConfig configFor(Difficulty difficulty, {required int seed}) {
    final spec = BoardSpec.forDifficulty(difficulty);
    return LevelConfig(
      mode: type,
      difficulty: difficulty,
      columns: spec.columns,
      rows: spec.rows,
      previewSeconds: double.parse((2.0 + spec.pairs * 0.2).toStringAsFixed(1)),
      symbolTier: BoardSpec.symbolTierFor(difficulty),
      seed: seed,
      moveLimit: moveLimitFor(difficulty),
      hintAllowance: 1,
    );
  }

  @override
  FailureReason? checkFailure(LevelConfig config, ModeProgress progress) {
    if (progress.isComplete) return null;
    if (progress.moves >= config.moveLimit!) return FailureReason.outOfMoves;
    return null;
  }
}
