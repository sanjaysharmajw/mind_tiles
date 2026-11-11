import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_tiles_game/app/app_scope.dart';
import 'package:mind_tiles_game/app/navigation.dart';
import 'package:mind_tiles_game/data/player_data_controller.dart';
import 'package:mind_tiles_game/features/gameplay/gameplay_screen.dart';
import 'package:mind_tiles_game/features/results/results_screen.dart';
import 'package:mind_tiles_game/game/game_config.dart';
import 'package:mind_tiles_game/game/game_state.dart';
import 'package:mind_tiles_game/game/modes/practice_mode.dart';
import 'package:mind_tiles_game/game/modes/timed_mode.dart';

import '../helpers.dart';

const sizes = <String, Size>{
  'small phone 320x568': Size(320, 568),
  'android 360x640': Size(360, 640),
  'iphone 390x844': Size(390, 844),
  'large phone 430x932': Size(430, 932),
  'phone landscape 844x390': Size(844, 390),
  'tablet portrait 820x1180': Size(820, 1180),
  'tablet landscape 1366x1024': Size(1366, 1024),
};

Future<void> open(
  WidgetTester tester,
  Future<void> Function(BuildContext) push,
) async {
  final ctx = tester.element(find.byKey(const Key('play_button')));
  push(ctx);
  await pumpFor(tester, const Duration(milliseconds: 500));
}

void main() {
  for (final entry in sizes.entries) {
    group(entry.key, () {
      testWidgets('home, menus and settings render without overflow', (
        tester,
      ) async {
        final h = await TestHarness.create();
        setScreenSize(tester, entry.value);
        await tester.pumpWidget(h.app());
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('play_button')), findsOneWidget);

        for (final push in <Future<void> Function(BuildContext)>[
          AppNavigator.toSettings,
          AppNavigator.toLevels,
          AppNavigator.toModes,
          AppNavigator.toDaily,
          AppNavigator.toStatistics,
          AppNavigator.toAchievements,
          AppNavigator.toAbout,
          AppNavigator.toTutorial,
        ]) {
          await open(tester, push);
          expect(
            tester.takeException(),
            isNull,
            reason: 'overflow on ${entry.key}',
          );
          final nav = tester.state<NavigatorState>(
            find.byType(Navigator).first,
          );
          nav.popUntil((r) => r.isFirst);
          await pumpFor(tester, const Duration(milliseconds: 400));
        }
      });

      for (final d in [Difficulty.easy, Difficulty.medium, Difficulty.expert]) {
        testWidgets(
          'gameplay ${d.name} board fits horizontally and is tappable',
          (tester) async {
            final h = await TestHarness.create();
            setScreenSize(tester, entry.value);
            await tester.pumpWidget(h.app());
            await tester.pump(const Duration(milliseconds: 100));
            final ctx = tester.element(find.byKey(const Key('play_button')));
            AppNavigator.toGameplay(
              ctx,
              const PracticeMode().configFor(d, seed: 3),
            );
            await pumpFor(tester, const Duration(milliseconds: 600));
            expect(tester.takeException(), isNull);

            final state = tester.state<GameplayScreenState>(
              find.byType(GameplayScreen),
            );
            // The last tile's semantics rect must be within the screen width.
            final last = state.session.config.tileCount;
            final cols = state.session.config.columns;
            final finder = find.bySemanticsLabel(
              RegExp('^Row ${(last - 1) ~/ cols + 1}, column $cols,'),
            );
            await tester.ensureVisible(finder);
            await tester.pump();
            final rect = tester.getRect(finder);
            expect(rect.right, lessThanOrEqualTo(entry.value.width + 0.5));
            expect(
              rect.width,
              greaterThanOrEqualTo(entry.value.width < 340 ? 34 : 40),
            );

            // Pause overlay also fits.
            state.openPauseMenu();
            await tester.pump(const Duration(milliseconds: 200));
            expect(tester.takeException(), isNull);
          },
        );
      }

      testWidgets('results screens (win and loss) render without overflow', (
        tester,
      ) async {
        final h = await TestHarness.create();
        setScreenSize(tester, entry.value);
        await tester.pumpWidget(h.app());
        await tester.pump(const Duration(milliseconds: 100));
        final ctx = tester.element(find.byKey(const Key('play_button')));
        final services = AppScope.of(ctx);

        final win = GameSession(config: level1(), previewDuration: 0);
        solvePerfectly(win);
        final outcome = services.player.recordResult(win.result!, now: testNow);
        Navigator.of(ctx).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ResultsScreen(result: win.result!, outcome: outcome),
          ),
        );
        await pumpFor(tester, const Duration(seconds: 2));
        expect(tester.takeException(), isNull);

        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        nav.popUntil((r) => r.isFirst);
        await pumpFor(tester, const Duration(milliseconds: 400));

        final lose = GameSession(
          config: const TimedMode().configFor(Difficulty.easy, seed: 1),
          previewDuration: 0,
        );
        for (var i = 0; i < 300 && lose.isInProgress; i++) {
          lose.tick(0.25);
        }
        Navigator.of(tester.element(find.byKey(const Key('play_button')))).push(
          MaterialPageRoute<void>(
            builder: (_) => ResultsScreen(
              result: lose.result!,
              outcome: RecordOutcome.notRecorded,
            ),
          ),
        );
        await pumpFor(tester, const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('orientation change keeps the game state', (tester) async {
    final h = await TestHarness.create();
    setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('play_button')));
    await pumpFor(tester, const Duration(milliseconds: 500));
    final state = tester.state<GameplayScreenState>(
      find.byType(GameplayScreen),
    );
    state.session.skipPreview();
    final pair = pairIndices(state.session.board).first;
    state.session.tapTile(pair[0]);
    state.session.tapTile(pair[1]);
    final id = state.session.sessionId;

    setScreenSize(tester, const Size(844, 390));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final after = tester.state<GameplayScreenState>(
      find.byType(GameplayScreen),
    );
    expect(after.session.sessionId, id);
    expect(after.session.matchedPairs, 1);
  });
}
