import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_tiles_game/features/gameplay/gameplay_screen.dart';
import 'package:mind_tiles_game/features/results/results_screen.dart';
import 'package:mind_tiles_game/game/game_config.dart';
import 'package:mind_tiles_game/game/game_state.dart';
import 'package:mind_tiles_game/models/settings.dart';
import 'package:mind_tiles_game/app/app.dart';
import 'package:mind_tiles_game/app/app_scope.dart';
import 'package:mind_tiles_game/services/ads/ad_service.dart';
import 'package:mind_tiles_game/services/notifications/push_service.dart';
import 'package:mind_tiles_game/services/performance/performance_tracer.dart';

import '../helpers.dart';

GameplayScreenState gameplay(WidgetTester tester) =>
    tester.state<GameplayScreenState>(find.byType(GameplayScreen));

Future<void> startApp(WidgetTester tester, TestHarness h) async {
  setScreenSize(tester, const Size(390, 844));
  await tester.pumpWidget(h.app());
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pump(); // lay out the scrolled position before tapping
  await tester.tap(f);
  await pumpFor(tester, const Duration(milliseconds: 500));
}

/// Solves the current board and waits for the results screen.
Future<void> winCurrentGame(WidgetTester tester) async {
  final s = gameplay(tester).session;
  solvePerfectly(s);
  expect(s.status, SessionStatus.won);
  s.tick(2); // results delay
  await pumpFor(tester, const Duration(milliseconds: 800));
}

/// A fake ad service whose rewarded ad always grants a verified reward.
class FakeRewardAds extends DisabledAdService {
  FakeRewardAds(this.outcome);
  final RewardOutcome outcome;
  int shown = 0;
  @override
  bool get isRewardedReady => true;
  @override
  Future<RewardOutcome> showRewarded() async {
    shown++;
    return outcome;
  }
}

void main() {
  testWidgets('home screen shows primary actions', (tester) async {
    final h = await TestHarness.create();
    await startApp(tester, h);
    expect(find.byKey(const Key('play_button')), findsOneWidget);
    expect(find.byKey(const Key('levels_button')), findsOneWidget);
    expect(find.byKey(const Key('modes_button')), findsOneWidget);
    expect(find.byKey(const Key('daily_button')), findsOneWidget);
    expect(find.byKey(const Key('continue_button')), findsNothing);
    expect(find.text('PLAY · LEVEL 1'), findsOneWidget);
  });

  testWidgets('home navigation reaches every secondary screen and back', (
    tester,
  ) async {
    final h = await TestHarness.create();
    await startApp(tester, h);
    final targets = <String, String>{
      'stats_button': 'Statistics',
      'achievements_button': 'Achievements',
      'settings_button': 'Settings',
    };
    for (final e in targets.entries) {
      await tester.tap(find.byKey(Key(e.key)));
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(find.text(e.value), findsWidgets);
      await tester.tap(find.bySemanticsLabel('Back'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const Key('play_button')), findsOneWidget);
    }
    await tapKey(tester, 'levels_button');
    expect(find.text('Classic Levels'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tapKey(tester, 'modes_button');
    expect(find.text('Game Modes'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tapKey(tester, 'daily_button');
    expect(find.text('Daily Challenge'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Back'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('About & privacy'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Privacy & About'), findsOneWidget);
  });

  testWidgets('first play shows the tutorial, then starts level 1', (
    tester,
  ) async {
    final h = await TestHarness.create(tutorialSeen: false);
    await startApp(tester, h);
    await tapKey(tester, 'play_button');
    expect(find.text('Memorize'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tapKey(tester, 'tutorial_next');
    }
    expect(find.text("LET'S PLAY!"), findsOneWidget);
    await tapKey(tester, 'tutorial_next');
    expect(h.player.tutorialSeen, isTrue);
    expect(gameplay(tester).session.config.level, 1);
    expect(
      h.analytics.entries.any((e) => e.$1.name == 'tutorialCompleted'),
      isTrue,
    );
  });

  testWidgets('play level 1 to completion, see results, advance to level 2', (
    tester,
  ) async {
    final h = await TestHarness.create();
    await startApp(tester, h);
    await tapKey(tester, 'play_button');
    final state = gameplay(tester);
    expect(state.session.isPreview, isTrue);
    expect(find.byKey(const Key('skip_preview')), findsOneWidget);
    await tapKey(tester, 'skip_preview');
    expect(state.session.isPlaying, isTrue);

    await winCurrentGame(tester);
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('LEVEL COMPLETE!'), findsWidgets);
    expect(find.byKey(const Key('new_best')), findsOneWidget);
    expect(find.text('Level 2 unlocked!'), findsOneWidget);
    expect(h.player.highestCompletedLevel, 1);
    expect(h.player.levelRecord(1)!.stars, 3);
    expect(h.audio.played, contains('victory.wav'));

    await tapKey(tester, 'next_level_button');
    expect(gameplay(tester).session.config.level, 2);
  });

  testWidgets('real taps on the Flame board flip tiles and count moves', (
    tester,
  ) async {
    final h = await TestHarness.create(
      settings: const GameSettings(preview: PreviewSetting.off),
    );
    await startApp(tester, h);
    await tapKey(tester, 'play_button');
    final s = gameplay(tester).session;
    expect(
      s.isPlaying,
      isTrue,
      reason: 'preview setting Off skips the preview',
    );

    final board = find.byKey(const Key('board_scroll')).evaluate().isEmpty
        ? find.byType(GameplayScreen)
        : find.byKey(const Key('board_scroll'));
    expect(board, findsOneWidget);
    // Tap the centre of the first two tiles through the semantics overlay rects.
    final first = find.bySemanticsLabel(RegExp(r'^Row 1, column 1, hidden'));
    final second = find.bySemanticsLabel(RegExp(r'^Row 1, column 2, hidden'));
    await tester.tap(first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(s.board.tiles[0].isRevealed, isTrue);
    await tester.tap(second, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(s.moves, 1);
    expect(h.audio.played, contains('flip.wav'));
  });

  testWidgets('pause and resume', (tester) async {
    final h = await TestHarness.create();
    await startApp(tester, h);
    await tapKey(tester, 'play_button');
    await tapKey(tester, 'skip_preview');
    final state = gameplay(tester);
    await tapKey(tester, 'pause_button');
    expect(state.session.isPaused, isTrue);
    expect(find.byKey(const Key('pause_title')), findsOneWidget);
    final elapsed = state.session.elapsedSeconds;
    await pumpFor(tester, const Duration(seconds: 2));
    expect(
      state.session.elapsedSeconds,
      elapsed,
      reason: 'clock frozen while paused',
    );
    await tapKey(tester, 'resume_button');
    expect(state.session.isPlaying, isTrue);
    expect(find.byKey(const Key('pause_title')), findsNothing);
  });

  testWidgets('restart asks for confirmation; cancel keeps the board', (
    tester,
  ) async {
    final h = await TestHarness.create();
    await startApp(tester, h);
    await tapKey(tester, 'play_button');
    await tapKey(tester, 'skip_preview');
    final state = gameplay(tester);
    final firstId = state.session.sessionId;
    final pair = pairIndices(state.session.board).first;
    state.session.tapTile(pair[0]);
    state.session.tapTile(pair[1]);

    await tapKey(tester, 'restart_button');
    expect(find.text('Restart?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(state.session.sessionId, firstId);
    expect(state.session.matchedPairs, 1);

    await tapKey(tester, 'restart_button');
    await tester.tap(find.text('RESTART'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(state.session.sessionId, isNot(firstId));
    expect(state.session.matchedPairs, 0);
    expect(state.session.moves, 0);
  });

  testWidgets('leaving mid-game saves; Continue restores the same board', (
    tester,
  ) async {
    final h = await TestHarness.create();
    await startApp(tester, h);
    await tapKey(tester, 'play_button');
    await tapKey(tester, 'skip_preview');
    var state = gameplay(tester);
    final pair = pairIndices(state.session.board).first;
    state.session.tapTile(pair[0]);
    state.session.tapTile(pair[1]);
    final deck = [for (final t in state.session.board.tiles) t.symbol];

    await tapKey(tester, 'pause_button');
    await tapKey(tester, 'quit_button');
    await tester.tap(find.text('LEAVE'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.byKey(const Key('continue_button')), findsOneWidget);

    await tapKey(tester, 'continue_button');
    state = gameplay(tester);
    expect(state.session.isPaused, isTrue);
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(state.session.matchedPairs, 1);
    expect([for (final t in state.session.board.tiles) t.symbol], deck);
    await tapKey(tester, 'resume_button');
    await winCurrentGame(tester);
    expect(
      h.player.data.snapshot,
      isNull,
      reason: 'finished games clear the save slot',
    );
  });

  testWidgets('app backgrounded pauses the game and saves a snapshot', (
    tester,
  ) async {
    final h = await TestHarness.create();
    await startApp(tester, h);
    await tapKey(tester, 'play_button');
    await tapKey(tester, 'skip_preview');
    final state = gameplay(tester);
    state.session.tapTile(0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(state.session.isPaused, isTrue);
    expect(h.player.data.snapshot?.sessionId, state.session.sessionId);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(
      state.session.isPaused,
      isTrue,
      reason: 'stays paused until the player resumes',
    );
    expect(find.byKey(const Key('pause_title')), findsOneWidget);
    await tapKey(tester, 'resume_button');
    expect(state.session.isPlaying, isTrue);
  });

  testWidgets('timed challenge failure shows failure screen and retry works', (
    tester,
  ) async {
    final h = await TestHarness.create();
    await startApp(tester, h);
    await tapKey(tester, 'modes_button');
    await tapKey(tester, 'mode_timed');
    expect(find.byKey(const Key('difficulty_easy')), findsOneWidget);
    await tapKey(tester, 'difficulty_easy');
    final state = gameplay(tester);
    expect(state.session.config.mode, GameModeType.timed);
    state.session.skipPreview();
    for (var i = 0; i < 400 && state.session.isInProgress; i++) {
      state.session.tick(0.25);
    }
    expect(state.session.status, SessionStatus.lost);
    state.session.tick(2);
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.text("TIME'S UP!"), findsWidgets);
    expect(find.byKey(const Key('next_level_button')), findsNothing);
    expect(h.player.data.stats.losses, 1);

    await tapKey(tester, 'replay_button');
    expect(gameplay(tester).session.config.mode, GameModeType.timed);
    expect(gameplay(tester).session.isInProgress, isTrue);
  });

  testWidgets('locked difficulties cannot be started', (tester) async {
    final h = await TestHarness.create();
    await startApp(tester, h);
    await tapKey(tester, 'modes_button');
    await tapKey(tester, 'mode_limitedMoves');
    await tester.tap(find.byKey(const Key('difficulty_hard')));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byType(GameplayScreen), findsNothing);
    expect(find.textContaining('Complete Classic level 15'), findsOneWidget);
  });

  testWidgets('locked level shows a hint; unlocked level starts', (
    tester,
  ) async {
    final h = await TestHarness.create();
    await startApp(tester, h);
    await tapKey(tester, 'levels_button');
    await tester.tap(find.byKey(const Key('level_2')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Complete level 1 to unlock level 2.'), findsOneWidget);
    await pumpFor(
      tester,
      const Duration(seconds: 5),
    ); // let the snackbar finish
    await tester.tap(find.byKey(const Key('level_1')));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(gameplay(tester).session.config.level, 1);
  });

  testWidgets('settings persist across app restarts and affect gameplay', (
    tester,
  ) async {
    final h = await TestHarness.create();
    await startApp(tester, h);
    await tapKey(tester, 'settings_button');
    await tapKey(tester, 'sound_switch');
    await tapKey(tester, 'preview_off');
    await tapKey(tester, 'theme_midnight');
    expect(h.player.settings.soundOn, isFalse);
    await h.player.flush();

    final h2 = await TestHarness.create(store: h.store);
    expect(h2.player.settings.soundOn, isFalse);
    expect(h2.player.settings.preview, PreviewSetting.off);
    expect(h2.player.settings.tileTheme.name, 'midnight');

    await tester.pumpWidget(const SizedBox()); // unmount the first app
    await tester.pumpWidget(h2.app());
    await tester.pump(const Duration(milliseconds: 100));
    await tapKey(tester, 'play_button');
    expect(
      gameplay(tester).session.isPlaying,
      isTrue,
      reason: 'preview Off starts immediately',
    );
    final before = h2.audio.played.length;
    gameplay(tester).session.tapTile(0);
    await tester.pump();
    expect(h2.audio.played.length, before, reason: 'sound effects are muted');
  });

  testWidgets('reset progress requires confirmation', (tester) async {
    final h = await TestHarness.create();
    await startApp(tester, h);
    await tapKey(tester, 'play_button');
    await winCurrentGame(tester);
    await tapKey(tester, 'home_button');
    await tapKey(tester, 'settings_button');
    await tapKey(tester, 'reset_progress');
    expect(find.text('Reset progress?'), findsOneWidget);
    await tester.tap(find.text('ERASE'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(h.player.highestCompletedLevel, 0);
    await pumpFor(tester, const Duration(seconds: 5));
  });

  testWidgets(
    'hint button: rewarded ad grants a hint only on verified reward',
    (tester) async {
      final ads = FakeRewardAds(RewardOutcome.rewarded);
      final h = await TestHarness.create(ads: ads);
      await startApp(tester, h);
      await tapKey(tester, 'play_button');
      await tapKey(tester, 'skip_preview');
      final state = gameplay(tester);
      // Spend the two free hints.
      for (var i = 0; i < 2; i++) {
        await state.requestHint();
        state.session.tick(2);
      }
      expect(state.session.hintsRemaining, 0);
      await state.requestHint();
      expect(ads.shown, 1);
      expect(state.session.hintsUsed, 3);

      final dismissed = FakeRewardAds(RewardOutcome.dismissed);
      final h2 = await TestHarness.create(ads: dismissed);
      await tester.pumpWidget(const SizedBox()); // unmount the first app
      await tester.pumpWidget(h2.app());
      await tester.pump(const Duration(milliseconds: 100));
      await tapKey(tester, 'play_button');
      await tapKey(tester, 'skip_preview');
      final s2 = gameplay(tester);
      for (var i = 0; i < 2; i++) {
        await s2.requestHint();
        s2.session.tick(2);
      }
      await s2.requestHint();
      expect(dismissed.shown, 1);
      expect(
        s2.session.hintsUsed,
        2,
        reason: 'no reward without the verified callback',
      );
    },
  );

  testWidgets('daily challenge completion is recorded once per day', (
    tester,
  ) async {
    final h = await TestHarness.create();
    await startApp(tester, h);
    await tapKey(tester, 'daily_button');
    await tapKey(tester, 'play_daily');
    expect(gameplay(tester).session.config.dateKey, '2026-11-11');
    await winCurrentGame(tester);
    expect(find.text('DAILY COMPLETE!'), findsWidgets);
    expect(h.player.data.daily.isCompleted('2026-11-11'), isTrue);
    await tapKey(tester, 'home_button');
    expect(find.text('DAILY · DONE'), findsOneWidget);
  });

  testWidgets('level_play performance trace records outcome and metrics', (
    tester,
  ) async {
    final h = await TestHarness.create();
    final tracer = _Tracer();
    final services = h.withServices(performance: tracer);
    setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(MindTilesApp(services: services));
    await tester.pump(const Duration(milliseconds: 100));
    await tapKey(tester, 'play_button');
    expect(tracer.traces.single.$1, 'level_play');
    expect(tracer.traces.single.$2['mode'], 'classic');
    await winCurrentGame(tester);
    final t = tracer.traces.single.$3;
    expect(t.stopped, isTrue);
    expect(t.attributes['outcome'], 'won');
    expect(t.metrics['moves'], 8);
    expect(t.metrics['pairs_matched'], 8);
  });

  testWidgets('notifications toggle asks permission and reports denial', (
    tester,
  ) async {
    final h = await TestHarness.create();
    final services = h.withServices(push: _DenyPush());
    setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(MindTilesApp(services: services));
    await tester.pump(const Duration(milliseconds: 100));
    await tapKey(tester, 'settings_button');
    await tapKey(tester, 'notifications_switch');
    expect(services.player.settings.notificationsOn, isFalse);
    expect(find.textContaining('Notifications are blocked'), findsOneWidget);
    await pumpFor(tester, const Duration(seconds: 5));
  });

  testWidgets('Playables: host pause halts play; OS lifecycle is ignored', (
    tester,
  ) async {
    final h = await TestHarness.create();
    final hostPaused = ValueNotifier(false);
    final services = AppServices(
      player: h.player,
      audio: h.services.audio,
      haptics: h.services.haptics,
      analytics: h.services.analytics,
      ads: const DisabledAdService(),
      crash: h.services.crash,
      flavor: AppFlavor.playables,
      hostPaused: hostPaused,
      random: h.services.random,
      clock: h.services.clock,
    );
    setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(MindTilesApp(services: services));
    await tester.pump(const Duration(milliseconds: 100));
    await tapKey(tester, 'play_button');
    await tapKey(tester, 'skip_preview');
    final state = gameplay(tester);
    // Page-visibility style lifecycle changes must not pause in Playables.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(state.session.isPlaying, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    // ytgame onPause.
    hostPaused.value = true;
    await tester.pump();
    expect(state.session.isPaused, isTrue);
    expect(find.byKey(const Key('pause_title')), findsOneWidget);
    expect(
      h.player.data.snapshot,
      isNotNull,
      reason: 'progress saved on onPause',
    );
    hostPaused.value = false;
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tapKey(tester, 'resume_button');
    expect(state.session.isPlaying, isTrue);
    // Playables hides notification/analytics/ad-privacy settings.
    Navigator.of(tester.element(find.byType(GameplayScreen))).pop();
    await pumpFor(tester, const Duration(milliseconds: 500));
  });

  testWidgets('Playables settings hide notifications and analytics', (
    tester,
  ) async {
    final h = await TestHarness.create();
    final services = AppServices(
      player: h.player,
      audio: h.services.audio,
      haptics: h.services.haptics,
      analytics: h.services.analytics,
      ads: const DisabledAdService(),
      crash: h.services.crash,
      flavor: AppFlavor.playables,
    );
    setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(MindTilesApp(services: services));
    await tester.pump(const Duration(milliseconds: 100));
    await tapKey(tester, 'settings_button');
    expect(find.byKey(const Key('notifications_switch')), findsNothing);
    expect(find.byKey(const Key('analytics_switch')), findsNothing);
    expect(find.byKey(const Key('sound_switch')), findsOneWidget);
  });
}

class _Tracer extends PerformanceTracer {
  final List<(String, Map<String, String>, NoopTrace)> traces = [];
  @override
  PerfTrace start(String name, {Map<String, String> attributes = const {}}) {
    final t = NoopTrace();
    traces.add((name, attributes, t));
    return t;
  }
}

class _DenyPush extends PushService {
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> enable() async => false;
  @override
  Future<void> disable() async {}
  @override
  set onOpen(void Function(PushTarget target)? callback) {}
}
