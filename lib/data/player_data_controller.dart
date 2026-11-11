import 'dart:math';

import 'package:flutter/foundation.dart';

import '../game/game_config.dart';
import '../game/game_state.dart';
import '../game/modes/daily_challenge_mode.dart';
import '../game/modes/game_mode.dart';
import '../game/systems/level_progression.dart';
import '../models/achievement.dart';
import '../models/game_result.dart';
import '../models/save_data.dart';
import '../models/settings.dart';
import 'repositories/save_repository.dart';

/// What happened when a result was recorded; shown on the results screen.
class RecordOutcome {
  const RecordOutcome({
    required this.recorded,
    this.isNewBest = false,
    this.previousBest,
    this.newAchievements = const [],
    this.unlockedLevel,
  });

  static const RecordOutcome notRecorded = RecordOutcome(recorded: false);

  final bool recorded;
  final bool isNewBest;
  final int? previousBest;
  final List<AchievementDef> newAchievements;

  /// Campaign level newly unlocked by this result, if any.
  final int? unlockedLevel;
}

/// The single source of truth for persistent player state (settings,
/// progress, statistics, achievements, resumable game). Every mutation is
/// persisted immediately through [SaveRepository].
class PlayerDataController extends ChangeNotifier {
  PlayerDataController(this._repo, this._data);

  static Future<PlayerDataController> load(SaveRepository repo) async {
    final result = await repo.load();
    return PlayerDataController(repo, result.data);
  }

  final SaveRepository _repo;
  SaveData _data;
  final Map<String, RecordOutcome> _recorded = {};

  SaveData get data => _data;
  GameSettings get settings => _data.settings;
  int get highestCompletedLevel => _data.highestCompletedLevel;
  int get unlockedLevel =>
      LevelProgression.unlockedLevelAfter(_data.highestCompletedLevel);
  bool get tutorialSeen => _data.tutorialSeen;

  bool isLevelUnlocked(int level) =>
      LevelProgression.isValidLevel(level) && level <= unlockedLevel;

  LevelRecord? levelRecord(int level) => _data.levels[level];
  ModeRecord? modeRecord(String key) => _data.modes[key];

  bool isDifficultyUnlocked(GameModeRules rules, Difficulty d) =>
      rules.allDifficultiesUnlocked ||
      LevelProgression.isDifficultyUnlocked(d, _data.highestCompletedLevel);

  /// The level "Play" should start: the first level not yet completed.
  int get nextLevelToPlay => unlockedLevel;

  /// A saved in-progress game, if one can be resumed. Daily snapshots from a
  /// previous day are discarded.
  SessionSnapshot? resumableSnapshot(DateTime now) {
    final s = _data.snapshot;
    if (s == null) return null;
    if (s.config.mode == GameModeType.daily &&
        s.config.dateKey != DailyChallengeMode.dateKey(now)) {
      return null;
    }
    if (s.config.mode == GameModeType.classic &&
        !isLevelUnlocked(s.config.level ?? 0)) {
      return null;
    }
    return s;
  }

  int dailyStreak(DateTime today) {
    final last = _data.daily.lastCompleted;
    if (last == null) return 0;
    final todayKey = DailyChallengeMode.dateKey(today);
    final yesterdayKey = DailyChallengeMode.dateKey(
      DateTime(today.year, today.month, today.day - 1),
    );
    return (last == todayKey || last == yesterdayKey)
        ? _data.daily.currentStreak
        : 0;
  }

  void _commit() {
    notifyListeners();
    _repo.save(_data);
  }

  Future<void> flush() => _repo.flush();

  void updateSettings(GameSettings settings) {
    if (settings == _data.settings) return;
    _data.settings = settings;
    _commit();
  }

  void markTutorialSeen() {
    if (_data.tutorialSeen) return;
    _data.tutorialSeen = true;
    _commit();
  }

  void saveSnapshot(SessionSnapshot snapshot) {
    _data.snapshot = snapshot;
    _commit();
  }

  void clearSnapshot([String? sessionId]) {
    final s = _data.snapshot;
    if (s == null) return;
    if (sessionId != null && s.sessionId != sessionId) return;
    _data.snapshot = null;
    _commit();
  }

  /// Records a finished game exactly once per session id.
  RecordOutcome recordResult(GameResult r, {DateTime? now}) {
    final cached = _recorded[r.sessionId];
    if (cached != null) return cached;
    final time = now ?? DateTime.now();
    clearSnapshotSilently(r.sessionId);

    final rules = GameModeRules.of(r.config.mode);
    if (!rules.recordsProgress) {
      _recorded[r.sessionId] = RecordOutcome.notRecorded;
      _commit();
      return RecordOutcome.notRecorded;
    }

    final s = _data.stats;
    s.gamesPlayed++;
    s.totalPairsMatched += r.matchedPairs;
    s.totalMoves += r.moves;
    s.totalPlayMs += r.elapsedMillis;
    s.hintsUsed += r.hintsUsed;
    s.bestCombo = max(s.bestCombo, r.bestCombo);

    var isNewBest = false;
    int? previousBest;
    int? unlocked;

    if (r.won) {
      s.wins++;
      s.currentWinStreak++;
      s.bestWinStreak = max(s.bestWinStreak, s.currentWinStreak);
      if (r.isPerfect) s.perfectGames++;
      if (r.config.pairs >= 32) s.bigBoardWins++;
      if (r.hintsUsed == 0 &&
          r.config.difficulty.index >= Difficulty.medium.index) {
        s.noHintHardWins++;
      }
      final limit = r.config.timeLimitSeconds;
      if (r.config.mode == GameModeType.timed &&
          limit != null &&
          (r.timeRemaining ?? 0) >= limit / 2) {
        s.fastTimedWins++;
      }
      final moveLimit = r.config.moveLimit;
      if (r.config.mode == GameModeType.limitedMoves &&
          moveLimit != null &&
          (r.movesRemaining ?? 0) >= moveLimit * 0.25) {
        s.efficientLimitedWins++;
      }
    } else {
      s.losses++;
      s.currentWinStreak = 0;
    }

    switch (r.config.mode) {
      case GameModeType.classic:
        if (r.won) {
          final level = r.config.level!;
          final rec = _data.levels.putIfAbsent(level, LevelRecord.new);
          previousBest = rec.completions > 0 ? rec.bestScore : null;
          isNewBest = r.score > rec.bestScore;
          rec
            ..completions += 1
            ..stars = max(rec.stars, r.stars)
            ..bestScore = max(rec.bestScore, r.score)
            ..bestTimeMs = rec.bestTimeMs == 0
                ? r.elapsedMillis
                : min(rec.bestTimeMs, r.elapsedMillis)
            ..bestMoves = rec.bestMoves == 0
                ? r.moves
                : min(rec.bestMoves, r.moves);
          if (level > _data.highestCompletedLevel) {
            _data.highestCompletedLevel = level;
            if (level < LevelProgression.totalLevels) unlocked = level + 1;
          }
        }
      case GameModeType.timed:
      case GameModeType.limitedMoves:
        final rec = _data.modes.putIfAbsent(r.config.recordKey, ModeRecord.new);
        rec.plays++;
        if (r.won) {
          previousBest = rec.wins > 0 ? rec.bestScore : null;
          isNewBest = r.score > rec.bestScore;
          rec
            ..wins += 1
            ..bestScore = max(rec.bestScore, r.score)
            ..bestTimeMs = rec.bestTimeMs == 0
                ? r.elapsedMillis
                : min(rec.bestTimeMs, r.elapsedMillis);
        }
      case GameModeType.daily:
        if (r.won) {
          final key = r.config.dateKey!;
          final d = _data.daily;
          previousBest = d.bestScores[key];
          isNewBest = previousBest == null || r.score > previousBest;
          d.bestScores[key] = max(previousBest ?? 0, r.score);
          if (d.lastCompleted != key) {
            final date = DailyChallengeMode.parseDateKey(key);
            final yesterday = date == null
                ? null
                : DailyChallengeMode.dateKey(
                    DateTime(date.year, date.month, date.day - 1),
                  );
            d.currentStreak = d.lastCompleted == yesterday
                ? d.currentStreak + 1
                : 1;
            d.bestStreak = max(d.bestStreak, d.currentStreak);
            d.lastCompleted = key;
          }
        }
      case GameModeType.practice:
        break;
    }

    final newAchievements = Achievements.evaluate(_data, time);
    final outcome = RecordOutcome(
      recorded: true,
      isNewBest: r.won && isNewBest,
      previousBest: previousBest,
      newAchievements: newAchievements,
      unlockedLevel: unlocked,
    );
    _recorded[r.sessionId] = outcome;
    _commit();
    return outcome;
  }

  void clearSnapshotSilently(String sessionId) {
    if (_data.snapshot?.sessionId == sessionId) _data.snapshot = null;
  }

  /// Erases progress, statistics and achievements; keeps settings and the
  /// tutorial flag.
  void resetProgress() {
    final settings = _data.settings;
    final tutorial = _data.tutorialSeen;
    _data = SaveData()
      ..settings = settings
      ..tutorialSeen = tutorial;
    _recorded.clear();
    _commit();
  }
}
