import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_tiles_game/app/app_config.dart';
import 'package:mind_tiles_game/game/board/board_layout.dart';
import 'package:mind_tiles_game/game/board/game_symbol.dart';
import 'package:mind_tiles_game/game/board/symbol_renderer.dart';
import 'package:mind_tiles_game/game/systems/audio_manager.dart';
import 'package:mind_tiles_game/game/systems/game_timer.dart';
import 'package:mind_tiles_game/game/systems/haptics_manager.dart';
import 'package:mind_tiles_game/game/systems/seeded_random.dart';
import 'package:mind_tiles_game/services/ads/ad_service.dart';

void main() {
  group('BoardLayout', () {
    test('fits a 4x4 board inside a phone viewport', () {
      final l = BoardLayout.fit(
        columns: 4,
        rows: 4,
        available: const Size(360, 500),
      );
      expect(l.canvasSize.width, lessThanOrEqualTo(360.001));
      expect(l.canvasSize.height, lessThanOrEqualTo(500.001));
      expect(l.needsScroll(500), isFalse);
      expect(l.tileSize, greaterThan(BoardLayout.minTileSize));
    });

    test('tiles never exceed the max size on tablets', () {
      final l = BoardLayout.fit(
        columns: 4,
        rows: 4,
        available: const Size(1200, 1200),
      );
      expect(l.tileSize, BoardLayout.maxTileSize);
    });

    test(
      '8x10 board on a 360pt phone keeps >= 40pt tiles and scrolls vertically',
      () {
        final l = BoardLayout.fit(
          columns: 8,
          rows: 10,
          available: const Size(360, 420),
        );
        expect(l.tileSize, greaterThanOrEqualTo(BoardLayout.minTileSize));
        expect(l.canvasSize.width, lessThanOrEqualTo(360.001));
        expect(l.needsScroll(420), isTrue);
      },
    );

    test(
      'on a 320pt phone 8 columns shrink to fit the width (documented limit)',
      () {
        final l = BoardLayout.fit(
          columns: 8,
          rows: 10,
          available: const Size(320, 420),
        );
        expect(l.canvasSize.width, lessThanOrEqualTo(320.001));
        expect(l.tileSize, greaterThan(35));
      },
    );

    test('never wider than the available width', () {
      final l = BoardLayout.fit(
        columns: 8,
        rows: 8,
        available: const Size(300, 200),
      );
      expect(l.canvasSize.width, lessThanOrEqualTo(300.001));
    });

    test('tap position to tile index, rejecting gaps and outside points', () {
      final l = BoardLayout.forCanvas(
        columns: 4,
        rows: 4,
        canvas: const Size(400, 400),
      );
      final origin = l.originIn(const Size(400, 400));
      for (var i = 0; i < 16; i++) {
        final r = l.tileRect(i, origin);
        expect(l.indexAt(r.center, origin), i);
        expect(l.indexAt(r.topLeft + const Offset(1, 1), origin), i);
      }
      // Gap between tile 0 and 1.
      final r0 = l.tileRect(0, origin);
      expect(
        l.indexAt(Offset(r0.right + l.gap / 2, r0.center.dy), origin),
        isNull,
      );
      // Outside the grid.
      expect(l.indexAt(const Offset(-5, -5), origin), isNull);
      expect(l.indexAt(const Offset(399.9, 399.9), origin), isNull);
    });
  });

  group('SymbolRenderer', () {
    test('every symbol builds drawable geometry and paints without error', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      for (final s in GameSymbol.values) {
        expect(SymbolRenderer.partCount(s), greaterThan(0), reason: s.name);
        SymbolRenderer.paint(
          canvas,
          s,
          const Rect.fromLTWH(0, 0, 64, 64),
          const Color(0xFF000000),
        );
      }
      recorder.endRecording().dispose();
    });

    test('symbol catalogue has 40 unique labels across 3 tiers', () {
      expect(GameSymbol.values.length, 40);
      expect(GameSymbol.values.map((s) => s.label).toSet().length, 40);
      expect(GameSymbol.upToTier(1).length, 16);
      expect(GameSymbol.tryParse('heart'), GameSymbol.heart);
      expect(GameSymbol.tryParse('nope'), isNull);
    });
  });

  group('SeededRandom', () {
    test('is deterministic and produces in-range values', () {
      final a = SeededRandom(1234);
      final b = SeededRandom(1234);
      for (var i = 0; i < 1000; i++) {
        final x = a.nextInt(37);
        expect(x, b.nextInt(37));
        expect(x, inInclusiveRange(0, 36));
        final d = a.nextDouble();
        b.nextDouble();
        expect(d, inInclusiveRange(0, 1));
      }
    });

    test('pinned sequence guards cross-version determinism', () {
      final r = SeededRandom(20261111);
      expect([for (var i = 0; i < 6; i++) r.nextInt(100)], _pinned);
    });

    test('date seed', () {
      expect(SeededRandom.seedForDate(DateTime(2026, 11, 11)), 20261111);
    });
  });

  group('PhaseTimer', () {
    test('fires exactly once', () {
      final t = PhaseTimer()..start(1);
      expect(t.tick(0.6), isFalse);
      expect(t.tick(0.6), isTrue);
      expect(t.tick(0.6), isFalse);
      expect(t.isActive, isFalse);
    });
  });

  group('InterstitialPolicy', () {
    test('disabled config never shows ads', () {
      final p = InterstitialPolicy(const AdsConfig());
      for (var i = 0; i < 20; i++) {
        p.onGameFinished();
        expect(p.shouldShow(DateTime(2026)), isFalse);
      }
    });

    test('respects warm-up, frequency and minimum interval', () {
      final p = InterstitialPolicy(
        const AdsConfig(
          enabled: true,
          interstitialEveryNGames: 3,
          minGamesBeforeFirstInterstitial: 3,
          minSecondsBetweenInterstitials: 180,
        ),
      );
      final t0 = DateTime(2026, 1, 1, 12);
      p.onGameFinished();
      p.onGameFinished();
      expect(p.shouldShow(t0), isFalse);
      p.onGameFinished();
      expect(p.shouldShow(t0), isTrue);
      p.markShown(t0);
      for (var i = 0; i < 3; i++) {
        p.onGameFinished();
      }
      expect(
        p.shouldShow(t0.add(const Duration(seconds: 60))),
        isFalse,
        reason: 'too soon',
      );
      expect(p.shouldShow(t0.add(const Duration(seconds: 200))), isTrue);
    });

    test('disabled ad service never offers rewards', () async {
      const ads = DisabledAdService();
      expect(ads.isRewardedReady, isFalse);
      expect(await ads.showRewarded(), RewardOutcome.unavailable);
      expect(await ads.maybeShowInterstitial(), isFalse);
    });
  });

  group('AudioManager & haptics', () {
    test(
      'sound setting gates effects; music follows setting and lifecycle',
      () {
        final backend = SilentAudioBackend();
        final audio = AudioManager(backend);
        audio.apply(soundOn: true, musicOn: false);
        audio.play(Sfx.match);
        expect(backend.played, ['match.wav']);
        audio.apply(soundOn: false, musicOn: false);
        audio.play(Sfx.match);
        expect(backend.played.length, 1);

        audio.apply(soundOn: false, musicOn: true);
        expect(backend.musicPlaying, isTrue);
        audio.setAppActive(false);
        expect(backend.musicPlaying, isFalse);
        audio.setAppActive(true);
        expect(backend.musicPlaying, isTrue);
        audio.apply(soundOn: false, musicOn: false);
        expect(backend.musicPlaying, isFalse);
      },
    );

    test(
      'haptics respect the enabled flag and swallow platform errors',
      () async {
        final calls = <HapticKind>[];
        final h = HapticsManager(
          performer: (k) async {
            calls.add(k);
            throw StateError('no vibrator');
          },
        );
        h.trigger(HapticKind.match);
        h.enabled = false;
        h.trigger(HapticKind.match);
        await Future<void>.delayed(Duration.zero);
        expect(calls, [HapticKind.match]);
      },
    );
  });

  test('AppConfig version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!;
    expect(match.group(1), AppConfig.fullVersion);
  });

  test('every referenced audio asset exists', () {
    for (final s in Sfx.values) {
      expect(
        File('assets/audio/${s.file}').existsSync(),
        isTrue,
        reason: s.file,
      );
    }
    expect(File('assets/audio/${AudioManager.musicFile}').existsSync(), isTrue);
  });
}

// Filled in from the first run of the generator; changing the PRNG would
// change every Daily Challenge board, so this must stay fixed.
const _pinned = <int>[58, 22, 89, 60, 49, 65];
