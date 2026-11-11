// Captures store-style screenshots of the main screens.
//
// Run: flutter drive --driver=test_driver/integration_test.dart \
//        --target=integration_test/screenshots_test.dart -d <device-id>
// PNGs are written to build/screenshots/.
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
import 'package:mind_tiles_game/game/board/tile_palette.dart';
import 'package:mind_tiles_game/game/systems/audio_manager.dart';
import 'package:mind_tiles_game/game/systems/haptics_manager.dart';
import 'package:mind_tiles_game/models/settings.dart';
import 'package:mind_tiles_game/services/ads/ad_service.dart';
import 'package:mind_tiles_game/services/analytics/analytics_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int ms = 700]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester, 300);
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot(name);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  testWidgets('screenshots', (tester) async {
    final player = await PlayerDataController.load(
      SaveRepository(MemoryStore()),
    );
    player.markTutorialSeen();
    player.updateSettings(const GameSettings(musicOn: false, soundOn: false));
    final services = AppServices(
      player: player,
      audio: AudioManager(SilentAudioBackend()),
      haptics: HapticsManager(performer: (_) async {}),
      analytics: LocalAnalyticsService(enabled: false),
      ads: const DisabledAdService(),
      crash: DebugCrashReporter(),
    );
    services.syncSettings();
    await tester.pumpWidget(MindTilesApp(services: services));
    await settle(tester, 1200);
    await shot(tester, '01_home');

    await tapKey(tester, 'play_button');
    await settle(tester, 400);
    await shot(tester, '02_preview');

    final s = tester
        .state<GameplayScreenState>(find.byType(GameplayScreen))
        .session;
    s.skipPreview();
    final bySymbol = <Object, List<int>>{};
    for (final t in s.board.tiles) {
      bySymbol.putIfAbsent(t.symbol, () => []).add(t.index);
    }
    final pairs = bySymbol.values.toList();
    for (final p in pairs.take(3)) {
      s.tapTile(p[0]);
      s.tapTile(p[1]);
    }
    final a = pairs[3][0];
    final b = pairs[4][0];
    s.tapTile(a);
    s.tapTile(b);
    await settle(tester, 250);
    await shot(tester, '03_gameplay');
    await settle(tester, 1000);

    for (final p in pairs.skip(3)) {
      s.tapTile(p[0]);
      s.tapTile(p[1]);
    }
    await settle(tester, 3200);
    await shot(tester, '04_results');

    await tapKey(tester, 'home_button');
    await tapKey(tester, 'modes_button');
    await shot(tester, '05_modes');
    Navigator.of(tester.element(find.text('Game Modes'))).pop();
    await settle(tester);
    await tapKey(tester, 'levels_button');
    await shot(tester, '06_levels');
    Navigator.of(tester.element(find.text('Classic Levels'))).pop();
    await settle(tester);
    await tapKey(tester, 'settings_button');
    await shot(tester, '07_settings');
    Navigator.of(tester.element(find.text('Settings').first)).pop();
    await settle(tester);
    await tapKey(tester, 'achievements_button');
    await shot(tester, '08_achievements');
    Navigator.of(tester.element(find.text('Achievements').first)).pop();
    await settle(tester);

    // A big board (Practice · Expert 8×10) and the midnight theme.
    player.updateSettings(
      player.settings.copyWith(tileTheme: TileThemeId.midnight),
    );
    await tapKey(tester, 'modes_button');
    await tapKey(tester, 'mode_practice');
    await tapKey(tester, 'difficulty_expert');
    await settle(tester, 600);
    await shot(tester, '09_expert_board_midnight');
  });
}
