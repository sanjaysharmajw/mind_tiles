import '../game_config.dart';
import '../systems/level_progression.dart';
import 'game_mode.dart';

/// Campaign play: 30 levels, no time or move limit.
class ClassicMode extends GameModeRules {
  const ClassicMode();

  @override
  GameModeType get type => GameModeType.classic;
  @override
  String get title => 'Classic';
  @override
  String get tagline => '30 levels · no limits · earn stars';
  @override
  double get scoreMultiplier => 1.0;
  @override
  bool get usesDifficultySelection => false;

  /// Classic is level based; [difficulty] maps to that tier's first level.
  @override
  LevelConfig configFor(Difficulty difficulty, {required int seed}) {
    final level = switch (difficulty) {
      Difficulty.easy => 1,
      Difficulty.medium => 7,
      Difficulty.hard => 16,
      Difficulty.expert => 25,
    };
    return LevelProgression.levelConfig(level, seed: seed);
  }

  LevelConfig configForLevel(int level, {required int seed}) =>
      LevelProgression.levelConfig(level, seed: seed);

  @override
  FailureReason? checkFailure(LevelConfig config, ModeProgress progress) =>
      null;
}
