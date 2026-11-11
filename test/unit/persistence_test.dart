import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_tiles_game/data/local_storage/key_value_store.dart';
import 'package:mind_tiles_game/data/player_data_controller.dart';
import 'package:mind_tiles_game/data/repositories/save_repository.dart';
import 'package:mind_tiles_game/game/board/tile_palette.dart';
import 'package:mind_tiles_game/game/game_config.dart';
import 'package:mind_tiles_game/game/game_state.dart';
import 'package:mind_tiles_game/game/modes/daily_challenge_mode.dart';
import 'package:mind_tiles_game/game/modes/limited_moves_mode.dart';
import 'package:mind_tiles_game/game/modes/practice_mode.dart';
import 'package:mind_tiles_game/game/modes/timed_mode.dart';
import 'package:mind_tiles_game/game/systems/level_progression.dart';
import 'package:mind_tiles_game/models/achievement.dart';
import 'package:mind_tiles_game/models/game_result.dart';
import 'package:mind_tiles_game/models/save_data.dart';
import 'package:mind_tiles_game/models/settings.dart';

import '../helpers.dart';

GameResult winResult(LevelConfig config, {int seed = 1}) {
  final s = GameSession(config: config, previewDuration: 0);
  solvePerfectly(s);
  return s.result!;
}

GameResult loseResult(LevelConfig config) {
  final s = GameSession(config: config, previewDuration: 0);
  for (var i = 0; i < 2000 && s.isInProgress; i++) {
    final m = mismatchedPair(s.board);
    s.tapTile(m[0]);
    s.tapTile(m[1]);
    s.tick(0.25);
  }
  return s.result!;
}

Future<PlayerDataController> freshController([MemoryStore? store]) =>
    PlayerDataController.load(SaveRepository(store ?? MemoryStore()));

void main() {
  group('SaveRepository', () {
    test('missing save gives defaults', () async {
      final r = await SaveRepository(MemoryStore()).load();
      expect(r.data.highestCompletedLevel, 0);
      expect(r.recoveredFromCorruption, isFalse);
    });

    test('save and restore round trip', () async {
      final store = MemoryStore();
      final c = await freshController(store);
      c.updateSettings(
        const GameSettings(
          soundOn: false,
          preview: PreviewSetting.long,
          tileTheme: TileThemeId.midnight,
        ),
      );
      c.recordResult(winResult(level1()), now: testNow);
      c.markTutorialSeen();
      await c.flush();

      final again = await freshController(store);
      expect(again.settings.soundOn, isFalse);
      expect(again.settings.preview, PreviewSetting.long);
      expect(again.settings.tileTheme, TileThemeId.midnight);
      expect(again.highestCompletedLevel, 1);
      expect(again.levelRecord(1)!.stars, 3);
      expect(again.data.stats.wins, 1);
      expect(again.tutorialSeen, isTrue);
      expect(
        again.data.achievements.containsKey(AchievementId.firstWin.name),
        isTrue,
      );
    });

    test('corrupted JSON is backed up and replaced by defaults', () async {
      final store = MemoryStore({SaveRepository.key: '{not json'});
      final r = await SaveRepository(store).load();
      expect(r.recoveredFromCorruption, isTrue);
      expect(r.data.highestCompletedLevel, 0);
      expect(store.data[SaveRepository.backupKey], '{not json');
    });

    test('wrong types in fields fall back per field', () async {
      final store = MemoryStore({
        SaveRepository.key: jsonEncode({
          'version': 1,
          'settings': {'soundOn': 'yes', 'musicOn': false, 'preview': 'bogus'},
          'highestCompletedLevel': 'three',
          'levels': {
            '2': {'stars': 9, 'bestScore': 100},
            'x': 5,
          },
          'stats': [1, 2, 3],
          'snapshot': {'garbage': true},
        }),
      });
      final r = await SaveRepository(store).load();
      expect(r.recoveredFromCorruption, isFalse);
      expect(r.data.settings.soundOn, isTrue);
      expect(r.data.settings.musicOn, isFalse);
      expect(r.data.settings.preview, PreviewSetting.normal);
      expect(r.data.highestCompletedLevel, 0);
      expect(r.data.levels[2]!.stars, 3, reason: 'clamped');
      expect(r.data.stats.gamesPlayed, 0);
      expect(r.data.snapshot, isNull);
    });

    test('migrations run in order from older versions', () async {
      final store = MemoryStore({
        SaveRepository.key: jsonEncode({'version': 0, 'highestLevel': 4}),
      });
      final repo = SaveRepository(
        store,
        migrations: {
          0: (json) =>
              json..['highestCompletedLevel'] = json.remove('highestLevel'),
        },
      );
      final r = await repo.load();
      expect(r.migratedFrom, 0);
      expect(r.data.highestCompletedLevel, 4);
    });

    test('migrate() stamps the target version', () {
      final out = SaveRepository.migrate(
        {'version': 0},
        from: 0,
        to: 3,
        migrations: const {},
      );
      expect(out['version'], 3);
    });

    test('writes are serialized: last write wins', () async {
      final store = MemoryStore();
      final repo = SaveRepository(store);
      final d = SaveData();
      for (var i = 1; i <= 5; i++) {
        d.highestCompletedLevel = i;
        repo.save(d);
      }
      await repo.flush();
      final r = await repo.load();
      expect(r.data.highestCompletedLevel, 5);
    });
  });

  group('PlayerDataController progression', () {
    test('levels unlock only after completing the previous one', () async {
      final c = await freshController();
      expect(c.isLevelUnlocked(1), isTrue);
      expect(c.isLevelUnlocked(2), isFalse);
      c.recordResult(
        loseResult(const TimedMode().configFor(Difficulty.easy, seed: 1)),
        now: testNow,
      );
      expect(c.isLevelUnlocked(2), isFalse, reason: 'losses never unlock');
      final outcome = c.recordResult(winResult(level1()), now: testNow);
      expect(outcome.unlockedLevel, 2);
      expect(c.isLevelUnlocked(2), isTrue);
      expect(c.isLevelUnlocked(3), isFalse);
      expect(c.nextLevelToPlay, 2);
    });

    test('replaying an old level does not unlock anything new', () async {
      final c = await freshController();
      c.recordResult(winResult(level1(seed: 1)), now: testNow);
      final again = c.recordResult(winResult(level1(seed: 2)), now: testNow);
      expect(again.unlockedLevel, isNull);
      expect(c.levelRecord(1)!.completions, 2);
    });

    test('the same session is only recorded once', () async {
      final c = await freshController();
      final r = winResult(level1());
      c.recordResult(r, now: testNow);
      c.recordResult(r, now: testNow);
      expect(c.data.stats.gamesPlayed, 1);
      expect(c.data.stats.totalPairsMatched, 8);
    });

    test('best score and new-best detection', () async {
      final c = await freshController();
      final first = c.recordResult(winResult(level1(seed: 1)), now: testNow);
      expect(first.isNewBest, isTrue);
      expect(first.previousBest, isNull);
      // A worse game (many mismatches) is not a new best.
      final s = GameSession(config: level1(seed: 3), previewDuration: 0);
      for (var i = 0; i < 6; i++) {
        final m = mismatchedPair(s.board);
        s.tapTile(m[0]);
        s.tapTile(m[1]);
        s.tick(1);
      }
      solvePerfectly(s);
      final worse = c.recordResult(s.result!, now: testNow);
      expect(worse.isNewBest, isFalse);
      expect(worse.previousBest, c.levelRecord(1)!.bestScore);
      expect(c.levelRecord(1)!.stars, 3, reason: 'stars never decrease');
    });

    test('practice games are never recorded', () async {
      final c = await freshController();
      final o = c.recordResult(
        winResult(const PracticeMode().configFor(Difficulty.easy, seed: 1)),
        now: testNow,
      );
      expect(o.recorded, isFalse);
      expect(c.data.stats.gamesPlayed, 0);
    });

    test('win/loss stats and streaks', () async {
      final c = await freshController();
      c.recordResult(winResult(level1(seed: 1)), now: testNow);
      c.recordResult(winResult(level1(seed: 2)), now: testNow);
      expect(c.data.stats.currentWinStreak, 2);
      c.recordResult(
        loseResult(
          const LimitedMovesMode().configFor(Difficulty.easy, seed: 1),
        ),
        now: testNow,
      );
      expect(c.data.stats.currentWinStreak, 0);
      expect(c.data.stats.bestWinStreak, 2);
      expect(c.data.stats.losses, 1);
      expect(c.data.stats.winRate, closeTo(2 / 3, 1e-9));
      expect(c.modeRecord('limitedMoves_easy')!.plays, 1);
    });

    test(
      'daily streak counts consecutive days and resets after a gap',
      () async {
        final c = await freshController();
        const mode = DailyChallengeMode();
        for (final day in [10, 11, 12]) {
          c.recordResult(
            winResult(mode.configForDate(DateTime(2026, 11, day))),
            now: DateTime(2026, 11, day),
          );
        }
        expect(c.data.daily.currentStreak, 3);
        expect(c.dailyStreak(DateTime(2026, 11, 12)), 3);
        expect(
          c.dailyStreak(DateTime(2026, 11, 13)),
          3,
          reason: 'still alive the next day',
        );
        expect(
          c.dailyStreak(DateTime(2026, 11, 14)),
          0,
          reason: 'missed a day',
        );
        expect(
          c.data.achievements.containsKey(AchievementId.dailyDevotee.name),
          isTrue,
        );
        // Replaying the same day does not extend the streak.
        c.recordResult(
          winResult(mode.configForDate(DateTime(2026, 11, 12))),
          now: DateTime(2026, 11, 12),
        );
        expect(c.data.daily.currentStreak, 3);
        c.recordResult(
          winResult(mode.configForDate(DateTime(2026, 11, 15))),
          now: DateTime(2026, 11, 15),
        );
        expect(c.data.daily.currentStreak, 1);
        expect(c.data.daily.bestStreak, 3);
      },
    );

    test(
      'difficulty unlocks for Timed/Limited follow campaign; practice is open',
      () async {
        final c = await freshController();
        expect(
          c.isDifficultyUnlocked(const TimedMode(), Difficulty.medium),
          isFalse,
        );
        expect(
          c.isDifficultyUnlocked(const PracticeMode(), Difficulty.expert),
          isTrue,
        );
        for (var l = 1; l <= 6; l++) {
          c.recordResult(
            winResult(LevelProgression.levelConfig(l, seed: l)),
            now: testNow,
          );
        }
        expect(
          c.isDifficultyUnlocked(const TimedMode(), Difficulty.medium),
          isTrue,
        );
        expect(
          c.isDifficultyUnlocked(const TimedMode(), Difficulty.hard),
          isFalse,
        );
      },
    );

    test('snapshot save/clear and stale daily snapshots are ignored', () async {
      final c = await freshController();
      final s = GameSession(config: level1(), previewDuration: 0);
      s.tapTile(0);
      c.saveSnapshot(s.toSnapshot());
      expect(c.resumableSnapshot(testNow), isNotNull);
      c.clearSnapshot('someone-else');
      expect(c.resumableSnapshot(testNow), isNotNull);
      c.clearSnapshot(s.sessionId);
      expect(c.resumableSnapshot(testNow), isNull);

      final daily = GameSession(
        config: const DailyChallengeMode().configForDate(
          DateTime(2026, 11, 10),
        ),
        previewDuration: 0,
      );
      c.saveSnapshot(daily.toSnapshot());
      expect(c.resumableSnapshot(DateTime(2026, 11, 10)), isNotNull);
      expect(c.resumableSnapshot(DateTime(2026, 11, 11)), isNull);
    });

    test('finishing a game clears its snapshot', () async {
      final c = await freshController();
      final s = GameSession(config: level1(), previewDuration: 0);
      c.saveSnapshot(s.toSnapshot());
      solvePerfectly(s);
      c.recordResult(s.result!, now: testNow);
      expect(c.data.snapshot, isNull);
    });

    test('reset progress keeps settings and tutorial flag', () async {
      final c = await freshController();
      c.updateSettings(const GameSettings(musicOn: false));
      c.markTutorialSeen();
      c.recordResult(winResult(level1()), now: testNow);
      c.resetProgress();
      expect(c.highestCompletedLevel, 0);
      expect(c.data.stats.gamesPlayed, 0);
      expect(c.data.achievements, isEmpty);
      expect(c.settings.musicOn, isFalse);
      expect(c.tutorialSeen, isTrue);
    });
  });

  group('Achievements', () {
    test('each condition unlocks exactly at its threshold', () {
      final d = SaveData();
      expect(Achievements.evaluate(d, testNow), isEmpty);
      d.stats.wins = 1;
      d.stats.bestCombo = 4;
      var unlocked = Achievements.evaluate(d, testNow).map((a) => a.id).toSet();
      expect(unlocked, {AchievementId.firstWin});
      d.stats.bestCombo = 5;
      unlocked = Achievements.evaluate(d, testNow).map((a) => a.id).toSet();
      expect(unlocked, {AchievementId.onARoll});
      expect(
        Achievements.evaluate(d, testNow),
        isEmpty,
        reason: 'never re-unlocked',
      );
      d.stats.totalPairsMatched = 1000;
      d.stats.gamesPlayed = 25;
      d.highestCompletedLevel = 30;
      unlocked = Achievements.evaluate(d, testNow).map((a) => a.id).toSet();
      expect(unlocked, {
        AchievementId.pairCollector,
        AchievementId.pairMaster,
        AchievementId.marathon,
        AchievementId.grandMaster,
      });
    });

    test(
      'perfect, big board, unassisted, speed and efficiency are recorded from results',
      () async {
        final c = await freshController();
        c.recordResult(
          winResult(LevelProgression.levelConfig(22, seed: 1)),
          now: testNow,
        ); // 8x8
        c.recordResult(
          winResult(const TimedMode().configFor(Difficulty.easy, seed: 1)),
          now: testNow,
        );
        c.recordResult(
          winResult(
            const LimitedMovesMode().configFor(Difficulty.easy, seed: 1),
          ),
          now: testNow,
        );
        final ids = c.data.achievements.keys.toSet();
        expect(
          ids,
          containsAll([
            AchievementId.perfectMemory.name,
            AchievementId.bigThinker.name,
            AchievementId.unassisted.name,
            AchievementId.speedDemon.name,
            AchievementId.efficientMind.name,
          ]),
        );
      },
    );

    test('all achievements have unique ids and positive targets', () {
      expect(
        Achievements.all.map((a) => a.id).toSet().length,
        AchievementId.values.length,
      );
      expect(Achievements.all.every((a) => a.target > 0), isTrue);
    });
  });
}
