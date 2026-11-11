import '../game/game_config.dart';
import '../game/modes/game_mode.dart';

/// Final outcome of a single game, produced once by the GameSession.
class GameResult {
  const GameResult({
    required this.sessionId,
    required this.config,
    required this.won,
    required this.score,
    required this.stars,
    required this.moves,
    required this.elapsedSeconds,
    required this.accuracy,
    required this.matchedPairs,
    required this.bestCombo,
    required this.hintsUsed,
    this.failureReason,
    this.timeRemaining,
    this.movesRemaining,
  });

  final String sessionId;
  final LevelConfig config;
  final bool won;
  final FailureReason? failureReason;
  final int score;
  final int stars;
  final int moves;
  final double elapsedSeconds;

  /// pairs / moves in 0..1.
  final double accuracy;
  final int matchedPairs;
  final int bestCombo;
  final int hintsUsed;
  final double? timeRemaining;
  final int? movesRemaining;

  int get totalPairs => config.pairs;
  bool get isPerfect => won && moves == config.pairs;
  int get elapsedMillis => (elapsedSeconds * 1000).round();
}
