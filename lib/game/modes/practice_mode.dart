import '../game_config.dart';
import 'game_mode.dart';

/// Relaxed play: any board size, unlimited time and hints, long preview.
/// Practice games never affect records, stats or achievements.
class PracticeMode extends GameModeRules {
  const PracticeMode();

  @override
  GameModeType get type => GameModeType.practice;
  @override
  String get title => 'Practice';
  @override
  String get tagline => 'Relax · unlimited hints';
  @override
  double get scoreMultiplier => 0.5;
  @override
  bool get recordsProgress => false;
  @override
  bool get allDifficultiesUnlocked => true;

  @override
  LevelConfig configFor(Difficulty difficulty, {required int seed}) {
    final spec = BoardSpec.forDifficulty(difficulty);
    return LevelConfig(
      mode: type,
      difficulty: difficulty,
      columns: spec.columns,
      rows: spec.rows,
      previewSeconds: double.parse(
        (3.0 + spec.pairs * 0.25).toStringAsFixed(1),
      ),
      symbolTier: BoardSpec.symbolTierFor(difficulty),
      seed: seed,
    );
  }

  @override
  FailureReason? checkFailure(LevelConfig config, ModeProgress progress) =>
      null;
}
