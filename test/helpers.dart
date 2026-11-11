import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_tiles_game/app/app.dart';
import 'package:mind_tiles_game/app/app_scope.dart';
import 'package:mind_tiles_game/data/local_storage/key_value_store.dart';
import 'package:mind_tiles_game/data/player_data_controller.dart';
import 'package:mind_tiles_game/data/repositories/save_repository.dart';
import 'package:mind_tiles_game/game/board/board_controller.dart';
import 'package:mind_tiles_game/game/game_config.dart';
import 'package:mind_tiles_game/game/game_state.dart';
import 'package:mind_tiles_game/game/systems/audio_manager.dart';
import 'package:mind_tiles_game/game/systems/haptics_manager.dart';
import 'package:mind_tiles_game/game/systems/level_progression.dart';
import 'package:mind_tiles_game/models/settings.dart';
import 'package:mind_tiles_game/services/ads/ad_service.dart';
import 'package:mind_tiles_game/services/analytics/analytics_service.dart';
import 'package:mind_tiles_game/services/notifications/push_service.dart';
import 'package:mind_tiles_game/services/performance/performance_tracer.dart';

final DateTime testNow = DateTime(2026, 11, 11, 10);

/// Pairs of indices that match, from the session's deck.
List<List<int>> pairIndices(BoardController board) {
  final bySymbol = <Object, List<int>>{};
  for (final t in board.tiles) {
    bySymbol.putIfAbsent(t.symbol, () => []).add(t.index);
  }
  return bySymbol.values.toList();
}

/// Plays a perfect game (no mismatches) on [session].
void solvePerfectly(GameSession session) {
  if (session.isPreview) session.skipPreview();
  for (final pair in pairIndices(session.board)) {
    if (session.isFinished) break;
    session.tapTile(pair[0]);
    session.tapTile(pair[1]);
    session.tick(0.5);
  }
}

/// Indices of two tiles with different symbols.
List<int> mismatchedPair(BoardController board) {
  final first = board.tiles.firstWhere((t) => !t.isMatched);
  final second = board.tiles.firstWhere(
    (t) => !t.isMatched && t.symbol != first.symbol,
  );
  return [first.index, second.index];
}

LevelConfig level1({int seed = 1}) =>
    LevelProgression.levelConfig(1, seed: seed);

class TestHarness {
  TestHarness._(this.store, this.services, this.audio, this.analytics);

  final MemoryStore store;
  final AppServices services;
  final SilentAudioBackend audio;
  final LocalAnalyticsService analytics;

  PlayerDataController get player => services.player;

  static Future<TestHarness> create({
    MemoryStore? store,
    bool tutorialSeen = true,
    GameSettings? settings,
    AdService ads = const DisabledAdService(),
    DateTime? now,
  }) async {
    final s = store ?? MemoryStore();
    final player = await PlayerDataController.load(SaveRepository(s));
    if (tutorialSeen) player.markTutorialSeen();
    if (settings != null) player.updateSettings(settings);
    final backend = SilentAudioBackend();
    final analytics = LocalAnalyticsService();
    final services = AppServices(
      player: player,
      audio: AudioManager(backend),
      haptics: HapticsManager(performer: (_) async {}),
      analytics: analytics,
      ads: ads,
      crash: DebugCrashReporter(),
      random: Random(7),
      clock: () => now ?? testNow,
    );
    services.syncSettings();
    return TestHarness._(s, services, backend, analytics);
  }

  Widget app() => MindTilesApp(services: services);

  /// Same player/audio/haptics, with some services swapped for fakes.
  AppServices withServices({
    AnalyticsService? analytics,
    CrashReporter? crash,
    PerformanceTracer? performance,
    PushService? push,
    AdService? ads,
  }) => AppServices(
    player: services.player,
    audio: services.audio,
    haptics: services.haptics,
    analytics: analytics ?? services.analytics,
    ads: ads ?? services.ads,
    crash: crash ?? services.crash,
    performance: performance ?? services.performance,
    push: push ?? services.push,
    random: services.random,
    clock: services.clock,
  );
}

/// Pumps frames for [duration] in small steps (the Flame loop and animations
/// never "settle", so pumpAndSettle cannot be used).
Future<void> pumpFor(
  WidgetTester tester,
  Duration duration, {
  Duration step = const Duration(milliseconds: 50),
}) async {
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// Sets a logical screen size for responsive tests.
void setScreenSize(WidgetTester tester, Size logical, {double dpr = 3}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = logical * dpr;
  addTearDown(tester.view.reset);
}
