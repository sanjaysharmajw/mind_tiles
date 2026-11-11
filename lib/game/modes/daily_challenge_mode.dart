import '../game_config.dart';
import '../systems/seeded_random.dart';
import 'game_mode.dart';

/// One deterministic board per calendar day (device local date).
///
/// The seed is `yyyymmdd` of the local date, fed to [SeededRandom], so every
/// player gets the same layout on the same date. The board is 6×6 with a
/// generous 3-minute clock; finishing on consecutive days builds a streak.
class DailyChallengeMode extends GameModeRules {
  const DailyChallengeMode();

  static const int timeLimitSeconds = 180;

  @override
  GameModeType get type => GameModeType.daily;
  @override
  String get title => 'Daily Challenge';
  @override
  String get tagline => 'Same board for everyone today';
  @override
  double get scoreMultiplier => 1.5;
  @override
  bool get usesDifficultySelection => false;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime? parseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  LevelConfig configForDate(DateTime date) => LevelConfig(
    mode: type,
    difficulty: Difficulty.medium,
    columns: 6,
    rows: 6,
    previewSeconds: 4.0,
    symbolTier: 2,
    seed: SeededRandom.seedForDate(date),
    dateKey: dateKey(date),
    timeLimitSeconds: timeLimitSeconds,
    hintAllowance: 1,
  );

  /// The daily board ignores difficulty; it is always today's board.
  @override
  LevelConfig configFor(Difficulty difficulty, {required int seed}) =>
      configForDate(DateTime.now());

  @override
  FailureReason? checkFailure(LevelConfig config, ModeProgress progress) {
    if (progress.isComplete) return null;
    if (progress.elapsedSeconds >= config.timeLimitSeconds!) {
      return FailureReason.outOfTime;
    }
    return null;
  }
}
