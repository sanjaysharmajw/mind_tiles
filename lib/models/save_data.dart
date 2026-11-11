import '../game/game_state.dart';
import 'settings.dart';

int _int(Object? v, [int d = 0]) => v is int ? v : (v is num ? v.toInt() : d);

class LevelRecord {
  LevelRecord({
    this.stars = 0,
    this.bestScore = 0,
    this.bestTimeMs = 0,
    this.bestMoves = 0,
    this.completions = 0,
  });

  int stars;
  int bestScore;

  /// 0 = no record yet.
  int bestTimeMs;
  int bestMoves;
  int completions;

  Map<String, Object?> toJson() => {
    'stars': stars,
    'bestScore': bestScore,
    'bestTimeMs': bestTimeMs,
    'bestMoves': bestMoves,
    'completions': completions,
  };

  factory LevelRecord.fromJson(Object? j) {
    if (j is! Map) return LevelRecord();
    return LevelRecord(
      stars: _int(j['stars']).clamp(0, 3),
      bestScore: _int(j['bestScore']).clamp(0, 1 << 31),
      bestTimeMs: _int(j['bestTimeMs']).clamp(0, 1 << 31),
      bestMoves: _int(j['bestMoves']).clamp(0, 1 << 31),
      completions: _int(j['completions']).clamp(0, 1 << 31),
    );
  }
}

/// Best results for Timed / Limited Moves per difficulty.
class ModeRecord {
  ModeRecord({
    this.bestScore = 0,
    this.bestTimeMs = 0,
    this.wins = 0,
    this.plays = 0,
  });
  int bestScore;
  int bestTimeMs;
  int wins;
  int plays;

  Map<String, Object?> toJson() => {
    'bestScore': bestScore,
    'bestTimeMs': bestTimeMs,
    'wins': wins,
    'plays': plays,
  };

  factory ModeRecord.fromJson(Object? j) {
    if (j is! Map) return ModeRecord();
    return ModeRecord(
      bestScore: _int(j['bestScore']),
      bestTimeMs: _int(j['bestTimeMs']),
      wins: _int(j['wins']),
      plays: _int(j['plays']),
    );
  }
}

class PlayerStats {
  int gamesPlayed = 0;
  int wins = 0;
  int losses = 0;
  int totalPairsMatched = 0;
  int totalMoves = 0;
  int totalPlayMs = 0;
  int perfectGames = 0;
  int bestCombo = 0;
  int currentWinStreak = 0;
  int bestWinStreak = 0;
  int hintsUsed = 0;
  int fastTimedWins = 0;
  int efficientLimitedWins = 0;
  int bigBoardWins = 0;
  int noHintHardWins = 0;

  double get winRate => gamesPlayed == 0 ? 0 : wins / gamesPlayed;

  Map<String, Object?> toJson() => {
    'gamesPlayed': gamesPlayed,
    'wins': wins,
    'losses': losses,
    'totalPairsMatched': totalPairsMatched,
    'totalMoves': totalMoves,
    'totalPlayMs': totalPlayMs,
    'perfectGames': perfectGames,
    'bestCombo': bestCombo,
    'currentWinStreak': currentWinStreak,
    'bestWinStreak': bestWinStreak,
    'hintsUsed': hintsUsed,
    'fastTimedWins': fastTimedWins,
    'efficientLimitedWins': efficientLimitedWins,
    'bigBoardWins': bigBoardWins,
    'noHintHardWins': noHintHardWins,
  };

  factory PlayerStats.fromJson(Object? j) {
    final s = PlayerStats();
    if (j is! Map) return s;
    s
      ..gamesPlayed = _int(j['gamesPlayed'])
      ..wins = _int(j['wins'])
      ..losses = _int(j['losses'])
      ..totalPairsMatched = _int(j['totalPairsMatched'])
      ..totalMoves = _int(j['totalMoves'])
      ..totalPlayMs = _int(j['totalPlayMs'])
      ..perfectGames = _int(j['perfectGames'])
      ..bestCombo = _int(j['bestCombo'])
      ..currentWinStreak = _int(j['currentWinStreak'])
      ..bestWinStreak = _int(j['bestWinStreak'])
      ..hintsUsed = _int(j['hintsUsed'])
      ..fastTimedWins = _int(j['fastTimedWins'])
      ..efficientLimitedWins = _int(j['efficientLimitedWins'])
      ..bigBoardWins = _int(j['bigBoardWins'])
      ..noHintHardWins = _int(j['noHintHardWins']);
    return s;
  }

  PlayerStats();
}

class DailyRecord {
  DailyRecord();

  /// dateKey (yyyy-mm-dd) -> best score that day.
  final Map<String, int> bestScores = {};
  int currentStreak = 0;
  int bestStreak = 0;
  String? lastCompleted;

  bool isCompleted(String dateKey) => bestScores.containsKey(dateKey);

  Map<String, Object?> toJson() => {
    'bestScores': bestScores,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'lastCompleted': lastCompleted,
  };

  factory DailyRecord.fromJson(Object? j) {
    final d = DailyRecord();
    if (j is! Map) return d;
    final scores = j['bestScores'];
    if (scores is Map) {
      scores.forEach((k, v) {
        if (k is String && v is int) d.bestScores[k] = v;
      });
    }
    d
      ..currentStreak = _int(j['currentStreak'])
      ..bestStreak = _int(j['bestStreak'])
      ..lastCompleted = j['lastCompleted'] is String
          ? j['lastCompleted'] as String
          : null;
    return d;
  }
}

/// Everything persisted on the device, stored as one versioned JSON document.
class SaveData {
  SaveData();

  /// Bump when the JSON layout changes and add a migration in
  /// SaveRepository.defaultMigrations.
  static const int currentVersion = 1;

  GameSettings settings = const GameSettings();
  int highestCompletedLevel = 0;
  final Map<int, LevelRecord> levels = {};
  final Map<String, ModeRecord> modes = {};
  PlayerStats stats = PlayerStats();
  DailyRecord daily = DailyRecord();

  /// achievement id -> ISO timestamp of unlock.
  final Map<String, String> achievements = {};
  bool tutorialSeen = false;
  SessionSnapshot? snapshot;

  int get totalStars => levels.values.fold(0, (sum, r) => sum + r.stars);

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'settings': settings.toJson(),
    'highestCompletedLevel': highestCompletedLevel,
    'levels': {for (final e in levels.entries) '${e.key}': e.value.toJson()},
    'modes': {for (final e in modes.entries) e.key: e.value.toJson()},
    'stats': stats.toJson(),
    'daily': daily.toJson(),
    'achievements': achievements,
    'tutorialSeen': tutorialSeen,
    'snapshot': snapshot?.toJson(),
  };

  /// Tolerant parser: invalid sections are replaced by defaults instead of
  /// discarding the whole save.
  factory SaveData.fromJson(Map<String, Object?> j) {
    final d = SaveData();
    d.settings = GameSettings.fromJson(j['settings']);
    d.highestCompletedLevel = _int(j['highestCompletedLevel']).clamp(0, 1000);
    final levels = j['levels'];
    if (levels is Map) {
      levels.forEach((k, v) {
        final n = int.tryParse('$k');
        if (n != null && n > 0) d.levels[n] = LevelRecord.fromJson(v);
      });
    }
    final modes = j['modes'];
    if (modes is Map) {
      modes.forEach((k, v) {
        if (k is String) d.modes[k] = ModeRecord.fromJson(v);
      });
    }
    d.stats = PlayerStats.fromJson(j['stats']);
    d.daily = DailyRecord.fromJson(j['daily']);
    final ach = j['achievements'];
    if (ach is Map) {
      ach.forEach((k, v) {
        if (k is String && v is String) d.achievements[k] = v;
      });
    }
    d.tutorialSeen = j['tutorialSeen'] == true;
    d.snapshot = SessionSnapshot.fromJson(j['snapshot']);
    return d;
  }
}
