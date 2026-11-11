import 'dart:math';

import '../game_config.dart';
import '../modes/game_mode.dart';

/// Inputs to the score formula for a *won* game.
class ScoreInput {
  const ScoreInput({
    required this.config,
    required this.moves,
    required this.elapsedSeconds,
    required this.bestCombo,
    required this.hintsUsed,
  });

  final LevelConfig config;
  final int moves;
  final double elapsedSeconds;
  final int bestCombo;
  final int hintsUsed;
}

class ScoreBreakdown {
  const ScoreBreakdown({
    required this.base,
    required this.efficiencyBonus,
    required this.timeBonus,
    required this.movesBonus,
    required this.comboBonus,
    required this.hintPenalty,
    required this.modeMultiplier,
    required this.total,
    required this.accuracy,
    required this.stars,
  });

  final int base;
  final int efficiencyBonus;
  final int timeBonus;
  final int movesBonus;
  final int comboBonus;
  final int hintPenalty;
  final double modeMultiplier;
  final int total;

  /// pairs / moves, in 0..1 (1.0 = no wasted move).
  final double accuracy;
  final int stars;
}

/// Deterministic scoring. Formula (all values rounded to integers):
///
/// ```
/// D            = difficulty multiplier (Easy 1.0, Medium 1.5, Hard 2.0, Expert 2.5)
/// base         = pairs × 100 × D
/// accuracy     = pairs ÷ moves                      (1.0 = perfect)
/// efficiency   = base × accuracy
/// timeBonus    = timed modes: secondsRemaining × 10 × D
///                otherwise:   max(0, parTime − elapsed) × 5 × D,  parTime = pairs × 4 s
/// movesBonus   = movesRemaining × 20 × D            (Limited Moves only)
/// comboBonus   = bestCombo × 15                     (longest run of consecutive matches)
/// hintPenalty  = hintsUsed × 50 × D
/// M            = mode multiplier (Classic 1.0, Timed 1.2, Limited 1.2, Daily 1.5, Practice 0.5)
/// score        = clamp((base + efficiency + timeBonus + movesBonus + comboBonus − hintPenalty) × M,
///                      0, 9 999 999)
/// ```
///
/// Stars: 3 if moves ≤ ⌈pairs × 1.5⌉, 2 if moves ≤ ⌈pairs × 2.25⌉, else 1.
/// A lost game scores 0 and earns 0 stars.
class ScoringSystem {
  const ScoringSystem._();

  static const int maxScore = 9999999;
  static const double parSecondsPerPair = 4.0;

  static double accuracy(int pairs, int moves) =>
      moves <= 0 ? 0 : min(1.0, pairs / moves);

  static int starsFor(int pairs, int moves) {
    if (moves <= (pairs * 1.5).ceil()) return 3;
    if (moves <= (pairs * 2.25).ceil()) return 2;
    return 1;
  }

  static ScoreBreakdown calculate(ScoreInput input) {
    final c = input.config;
    final d = c.difficulty.scoreMultiplier;
    final pairs = c.pairs;
    final moves = max(input.moves, pairs); // a win needs at least `pairs` moves
    final acc = accuracy(pairs, moves);
    final base = (pairs * 100 * d).round();
    final efficiency = (base * acc).round();

    int timeBonus;
    final limit = c.timeLimitSeconds;
    if (limit != null) {
      final remaining = max(0.0, limit - input.elapsedSeconds);
      timeBonus = (remaining * 10 * d).round();
    } else {
      final par = pairs * parSecondsPerPair;
      timeBonus = (max(0.0, par - input.elapsedSeconds) * 5 * d).round();
    }

    final moveLimit = c.moveLimit;
    final movesBonus = moveLimit == null
        ? 0
        : (max(0, moveLimit - moves) * 20 * d).round();
    final comboBonus = max(0, input.bestCombo) * 15;
    final hintPenalty = (max(0, input.hintsUsed) * 50 * d).round();
    final m = GameModeRules.of(c.mode).scoreMultiplier;
    final raw =
        (base +
            efficiency +
            timeBonus +
            movesBonus +
            comboBonus -
            hintPenalty) *
        m;
    final total = raw.isFinite ? raw.round().clamp(0, maxScore) : 0;

    return ScoreBreakdown(
      base: base,
      efficiencyBonus: efficiency,
      timeBonus: timeBonus,
      movesBonus: movesBonus,
      comboBonus: comboBonus,
      hintPenalty: hintPenalty,
      modeMultiplier: m,
      total: total,
      accuracy: acc,
      stars: starsFor(pairs, moves),
    );
  }
}
