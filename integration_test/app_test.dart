// End-to-end test on a real device/simulator: real storage plugin, real audio
// plugin, real Flame game loop, and real pointer taps on board tiles.
//
// Run: flutter test integration_test/app_test.dart -d <device-id>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mind_tiles_game/app/app.dart';
import 'package:mind_tiles_game/app/app_scope.dart';
import 'package:mind_tiles_game/data/local_storage/key_value_store.dart';
import 'package:mind_tiles_game/data/player_data_controller.dart';
import 'package:mind_tiles_game/data/repositories/save_repository.dart';
import 'package:mind_tiles_game/features/gameplay/gameplay_screen.dart';
import 'package:mind_tiles_game/features/results/results_screen.dart';
import 'package:mind_tiles_game/game/game_state.dart';
import 'package:mind_tiles_game/game/systems/audio_manager.dart';
import 'package:mind_tiles_game/game/systems/haptics_manager.dart';
import 'package:mind_tiles_game/services/ads/ad_service.dart';
import 'package:mind_tiles_game/services/analytics/analytics_service.dart';

Future<AppServices> realServices() async {
  final store = await SharedPrefsStore.create();
  await store.remove(SaveRepository.key); // start from a clean install state
  final player = await PlayerDataController.load(SaveRepository(store));
  final audio = AudioManager(AudioPlayersBackend());
  await audio.init();
  final services = AppServices(
    player: player,
    audio: audio,
    haptics: HapticsManager(),
    analytics: LocalAnalyticsService(),
    ads: const DisabledAdService(),
    crash: DebugCrashReporter(),
  );
  services.syncSettings();
  return services;
}

Future<void> settle(WidgetTester tester, [int ms = 600]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}

/// Taps a tile by its on-screen position (goes through Flame hit testing).
Future<void> tapTile(WidgetTester tester, GameSession s, int index) async {
  final cols = s.config.columns;
  final label = RegExp(
    '^Row ${index ~/ cols + 1}, column ${index % cols + 1},',
  );
  final f = find.bySemanticsLabel(label);
  await tester.tap(f, warnIfMissed: false);
  await settle(tester, 120);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'install → tutorial → play level 1 with real taps → results → persisted',
    (tester) async {
      final services = await realServices();
      await tester.pumpWidget(MindTilesApp(services: services));
      await settle(tester, 1000);

      await tapKey(tester, 'play_button');
      expect(find.text('Memorize'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tapKey(tester, 'tutorial_next');
      }
      expect(services.player.tutorialSeen, isTrue);

      final state = tester.state<GameplayScreenState>(
        find.byType(GameplayScreen),
      );
      final s = state.session;
      expect(s.isPreview, isTrue);
      await tapKey(tester, 'skip_preview');
      expect(s.isPlaying, isTrue);

      // One deliberate mismatch, tapped through the real Flame board.
      final first = s.board.tiles.first;
      final other = s.board.tiles.firstWhere((t) => t.symbol != first.symbol);
      await tapTile(tester, s, first.index);
      expect(
        s.board.tiles[first.index].isRevealed,
        isTrue,
        reason: 'Flame tap → tile index',
      );
      await tapTile(tester, s, other.index);
      expect(s.moves, 1);
      await settle(tester, 1200); // mismatch flips back via the game loop
      expect(s.board.tiles[first.index].isHidden, isTrue);

      // Then solve every pair with real taps.
      final bySymbol = <Object, List<int>>{};
      for (final t in s.board.tiles) {
        bySymbol.putIfAbsent(t.symbol, () => []).add(t.index);
      }
      for (final pair in bySymbol.values) {
        await tapTile(tester, s, pair[0]);
        await tapTile(tester, s, pair[1]);
      }
      expect(s.status, SessionStatus.won);
      await settle(tester, 2500);
      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(s.result!.moves, 9);

      // Persistence through the real platform storage.
      await services.player.flush();
      final reloaded = await PlayerDataController.load(
        SaveRepository(await SharedPrefsStore.create()),
      );
      expect(reloaded.highestCompletedLevel, 1);
      expect(reloaded.levelRecord(1)!.completions, 1);
      expect(reloaded.tutorialSeen, isTrue);

      await tapKey(tester, 'next_level_button');
      final next = tester.state<GameplayScreenState>(
        find.byType(GameplayScreen),
      );
      expect(next.session.config.level, 2);
      debugPrint('Integration run on ${Platform.operatingSystem} passed');

      // Let in-flight sound effects finish so audioplayers' frame callbacks end
      // before the test framework checks for leftover callbacks.
      // Background music loops forever, so turn it off (exercising the real
      // settings → audio path) before tearing down.
      expect(services.audio.musicOn, isTrue);
      services.player.updateSettings(
        services.player.settings.copyWith(musicOn: false),
      );
      expect(services.audio.musicOn, isFalse);
      await tester.pumpWidget(const SizedBox());
      await settle(tester, 2500);
    },
  );
}
