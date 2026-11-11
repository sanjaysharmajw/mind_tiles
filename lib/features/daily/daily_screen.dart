import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_theme.dart';
import '../../app/navigation.dart';
import '../../game/board/game_symbol.dart';
import '../../game/modes/daily_challenge_mode.dart';
import '../../widgets/game_button.dart';
import '../../widgets/panels.dart';
import '../../widgets/symbol_icon.dart';
import '../gameplay/gameplay_hud.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final player = services.player;
    const mode = DailyChallengeMode();
    return GameScreenScaffold(
      title: 'Daily Challenge',
      body: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final now = services.clock();
          final key = DailyChallengeMode.dateKey(now);
          final done = player.data.daily.isCompleted(key);
          final best = player.data.daily.bestScores[key];
          final streak = player.dailyStreak(now);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: ContentWidth(
              maxWidth: 460,
              child: Column(
                children: [
                  GamePanel(
                    child: Column(
                      children: [
                        const SymbolIcon(
                          GameSymbol.sun,
                          size: 56,
                          color: AppColors.orange,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_months[now.month - 1]} ${now.day}, ${now.year}',
                          style: AppTheme.display(26, color: AppColors.ink),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Everyone gets the same 6×6 board today. Clear it within '
                          '3 minutes to keep your streak going.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _Info(
                              label: 'Status',
                              value: done ? 'Done' : 'Not yet',
                            ),
                            _Info(label: 'Streak', value: '$streak'),
                            _Info(
                              label: 'Best today',
                              value: best == null ? '–' : '$best',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Best streak: ${player.data.daily.bestStreak} · '
                          'Clock: ${formatSeconds(DailyChallengeMode.timeLimitSeconds.toDouble())}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ChunkyButton.styled(
                    ChunkyButton.coral,
                    key: const Key('play_daily'),
                    label: done ? 'PLAY AGAIN' : 'PLAY TODAY',
                    icon: Icons.play_arrow_rounded,
                    height: 64,
                    fontSize: 24,
                    onPressed: () => AppNavigator.toGameplay(
                      context,
                      mode.configForDate(now),
                    ),
                  ),
                  if (done)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Replays can improve today\'s best score.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.inkSoft,
          ),
        ),
        FittedBox(
          child: Text(value, style: AppTheme.display(22, color: AppColors.ink)),
        ),
      ],
    ),
  );
}
