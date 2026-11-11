import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_theme.dart';
import '../../game/systems/level_progression.dart';
import '../../widgets/panels.dart';

String formatDuration(int ms) {
  final totalMinutes = ms ~/ 60000;
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h > 0) return '${h}h ${m}m';
  final s = (ms ~/ 1000) % 60;
  return '${m}m ${s}s';
}

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final player = services.player;
    return GameScreenScaffold(
      title: 'Statistics',
      body: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final d = player.data;
          final s = d.stats;
          final items = <(IconData, String, String)>[
            (Icons.sports_esports_rounded, 'Games played', '${s.gamesPlayed}'),
            (Icons.emoji_events_rounded, 'Wins', '${s.wins}'),
            (Icons.close_rounded, 'Losses', '${s.losses}'),
            (
              Icons.percent_rounded,
              'Win rate',
              '${(s.winRate * 100).round()}%',
            ),
            (
              Icons.grid_view_rounded,
              'Levels cleared',
              '${d.highestCompletedLevel}/${LevelProgression.totalLevels}',
            ),
            (
              Icons.star_rounded,
              'Stars',
              '${d.totalStars}/${LevelProgression.totalLevels * 3}',
            ),
            (Icons.favorite_rounded, 'Pairs matched', '${s.totalPairsMatched}'),
            (Icons.touch_app_rounded, 'Total moves', '${s.totalMoves}'),
            (Icons.timer_rounded, 'Play time', formatDuration(s.totalPlayMs)),
            (Icons.auto_awesome_rounded, 'Perfect games', '${s.perfectGames}'),
            (Icons.bolt_rounded, 'Best combo', '${s.bestCombo}'),
            (
              Icons.local_fire_department_rounded,
              'Best win streak',
              '${s.bestWinStreak}',
            ),
            (
              Icons.today_rounded,
              'Daily streak',
              '${player.dailyStreak(services.clock())}',
            ),
            (
              Icons.calendar_month_rounded,
              'Best daily streak',
              '${d.daily.bestStreak}',
            ),
            (Icons.lightbulb_rounded, 'Hints used', '${s.hintsUsed}'),
            (
              Icons.military_tech_rounded,
              'Achievements',
              '${d.achievements.length}',
            ),
          ];
          return ContentWidth(
            maxWidth: 640,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final (icon, label, value) = items[i];
                return Semantics(
                  label: '$label: $value',
                  excludeSemantics: true,
                  child: GamePanel(
                    padding: const EdgeInsets.all(10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: AppColors.violet, size: 26),
                          const SizedBox(height: 2),
                          FittedBox(
                            child: Text(
                              value,
                              style: AppTheme.display(26, color: AppColors.ink),
                            ),
                          ),
                          FittedBox(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
