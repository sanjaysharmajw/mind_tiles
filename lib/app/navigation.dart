import 'package:flutter/material.dart';

import '../features/about/about_screen.dart';
import '../features/achievements/achievements_screen.dart';
import '../features/daily/daily_screen.dart';
import '../features/gameplay/gameplay_screen.dart';
import '../features/level_selection/level_select_screen.dart';
import '../features/modes/mode_select_screen.dart';
import '../features/onboarding/tutorial_screen.dart';
import '../features/results/results_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/statistics/statistics_screen.dart';
import '../game/game_config.dart';
import '../game/game_state.dart';
import '../data/player_data_controller.dart';
import '../models/game_result.dart';
import 'app_scope.dart';

/// Central navigation helpers with game-style transitions.
class AppNavigator {
  const AppNavigator._();

  static Route<T> _route<T>(BuildContext context, Widget page, {String? name}) {
    final reduced = AppScope.of(context).reducedMotion(context);
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: name),
      transitionDuration: Duration(milliseconds: reduced ? 0 : 320),
      reverseTransitionDuration: Duration(milliseconds: reduced ? 0 : 240),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) {
        if (reduced) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Future<void> toGameplay(
    BuildContext context,
    LevelConfig config, {
    SessionSnapshot? resume,
    bool replace = false,
  }) {
    final page = GameplayScreen(config: config, resume: resume);
    final route = _route<void>(context, page, name: 'gameplay');
    return replace
        ? Navigator.of(context).pushReplacement(route)
        : Navigator.of(context).push(route);
  }

  static Future<void> toResults(
    BuildContext context,
    GameResult result,
    RecordOutcome outcome,
  ) => Navigator.of(context).pushReplacement(
    _route<void>(
      context,
      ResultsScreen(result: result, outcome: outcome),
      name: 'results',
    ),
  );

  static Future<void> toLevels(BuildContext context) => Navigator.of(
    context,
  ).push(_route(context, const LevelSelectScreen(), name: 'levels'));

  static Future<void> toModes(BuildContext context) => Navigator.of(
    context,
  ).push(_route(context, const ModeSelectScreen(), name: 'modes'));

  static Future<void> toDaily(BuildContext context) => Navigator.of(
    context,
  ).push(_route(context, const DailyScreen(), name: 'daily'));

  static Future<void> toSettings(BuildContext context) => Navigator.of(
    context,
  ).push(_route(context, const SettingsScreen(), name: 'settings'));

  static Future<void> toStatistics(BuildContext context) => Navigator.of(
    context,
  ).push(_route(context, const StatisticsScreen(), name: 'stats'));

  static Future<void> toAchievements(BuildContext context) => Navigator.of(
    context,
  ).push(_route(context, const AchievementsScreen(), name: 'achievements'));

  static Future<void> toAbout(BuildContext context) => Navigator.of(
    context,
  ).push(_route(context, const AboutScreen(), name: 'about'));

  /// Shows the tutorial; resolves to true when the player finished it.
  static Future<bool?> toTutorial(BuildContext context) => Navigator.of(
    context,
  ).push<bool>(_route(context, const TutorialScreen(), name: 'tutorial'));

  static void popToHome(BuildContext context) =>
      Navigator.of(context).popUntil((r) => r.isFirst);
}
