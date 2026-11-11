import '../game/board/game_symbol.dart';
import 'save_data.dart';

enum AchievementId {
  firstWin,
  perfectMemory,
  onARoll,
  pairCollector,
  pairMaster,
  starGazer,
  speedDemon,
  efficientMind,
  dailyDevotee,
  bigThinker,
  grandMaster,
  marathon,
  unassisted,
}

/// An achievement with an explicit, measurable unlock condition:
/// it unlocks when `progress(data) >= target`.
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.target,
    required this.progress,
  });

  final AchievementId id;
  final String title;
  final String description;
  final GameSymbol icon;
  final int target;
  final int Function(SaveData data) progress;

  bool isMet(SaveData data) => progress(data) >= target;
}

class Achievements {
  const Achievements._();

  static final List<AchievementDef> all = [
    AchievementDef(
      id: AchievementId.firstWin,
      title: 'First Steps',
      description: 'Win your first game.',
      icon: GameSymbol.star,
      target: 1,
      progress: (d) => d.stats.wins,
    ),
    AchievementDef(
      id: AchievementId.perfectMemory,
      title: 'Perfect Memory',
      description: 'Win a game without a single mismatch.',
      icon: GameSymbol.target,
      target: 1,
      progress: (d) => d.stats.perfectGames,
    ),
    AchievementDef(
      id: AchievementId.onARoll,
      title: 'On a Roll',
      description: 'Make 5 matches in a row.',
      icon: GameSymbol.lightning,
      target: 5,
      progress: (d) => d.stats.bestCombo,
    ),
    AchievementDef(
      id: AchievementId.pairCollector,
      title: 'Pair Collector',
      description: 'Match 100 pairs in total.',
      icon: GameSymbol.heart,
      target: 100,
      progress: (d) => d.stats.totalPairsMatched,
    ),
    AchievementDef(
      id: AchievementId.pairMaster,
      title: 'Pair Master',
      description: 'Match 1,000 pairs in total.',
      icon: GameSymbol.hexagram,
      target: 1000,
      progress: (d) => d.stats.totalPairsMatched,
    ),
    AchievementDef(
      id: AchievementId.starGazer,
      title: 'Star Gazer',
      description: 'Collect 30 stars in Classic levels.',
      icon: GameSymbol.starOutline,
      target: 30,
      progress: (d) => d.totalStars,
    ),
    AchievementDef(
      id: AchievementId.speedDemon,
      title: 'Speed Demon',
      description: 'Win a Timed Challenge with at least half the clock left.',
      icon: GameSymbol.hourglass,
      target: 1,
      progress: (d) => d.stats.fastTimedWins,
    ),
    AchievementDef(
      id: AchievementId.efficientMind,
      title: 'Efficient Mind',
      description: 'Win Limited Moves with at least 25% of moves to spare.',
      icon: GameSymbol.diceFive,
      target: 1,
      progress: (d) => d.stats.efficientLimitedWins,
    ),
    AchievementDef(
      id: AchievementId.dailyDevotee,
      title: 'Daily Devotee',
      description: 'Complete the Daily Challenge 3 days in a row.',
      icon: GameSymbol.sun,
      target: 3,
      progress: (d) => d.daily.bestStreak,
    ),
    AchievementDef(
      id: AchievementId.bigThinker,
      title: 'Big Thinker',
      description: 'Complete an 8×8 board or larger.',
      icon: GameSymbol.hexagon,
      target: 1,
      progress: (d) => d.stats.bigBoardWins,
    ),
    AchievementDef(
      id: AchievementId.grandMaster,
      title: 'Grand Master',
      description: 'Complete all 30 Classic levels.',
      icon: GameSymbol.diamond,
      target: 30,
      progress: (d) => d.highestCompletedLevel,
    ),
    AchievementDef(
      id: AchievementId.marathon,
      title: 'Marathon',
      description: 'Play 25 games.',
      icon: GameSymbol.flower,
      target: 25,
      progress: (d) => d.stats.gamesPlayed,
    ),
    AchievementDef(
      id: AchievementId.unassisted,
      title: 'Unassisted',
      description: 'Win a Medium or harder board without using a hint.',
      icon: GameSymbol.checkmark,
      target: 1,
      progress: (d) => d.stats.noHintHardWins,
    ),
  ];

  static AchievementDef byId(AchievementId id) =>
      all.firstWhere((a) => a.id == id);

  /// Unlocks every achievement whose condition is met and returns the ones
  /// that were newly unlocked by this call.
  static List<AchievementDef> evaluate(SaveData data, DateTime now) {
    final unlocked = <AchievementDef>[];
    for (final a in all) {
      if (!data.achievements.containsKey(a.id.name) && a.isMet(data)) {
        data.achievements[a.id.name] = now.toIso8601String();
        unlocked.add(a);
      }
    }
    return unlocked;
  }
}
