import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_theme.dart';
import '../../app/navigation.dart';
import '../../data/player_data_controller.dart';
import '../../game/board/game_symbol.dart';
import '../../game/game_config.dart';
import '../../game/modes/game_mode.dart';
import '../../game/systems/audio_manager.dart';
import '../../game/systems/level_progression.dart';
import '../../models/game_result.dart';
import '../../widgets/game_background.dart';
import '../../widgets/game_button.dart';
import '../../widgets/panels.dart';
import '../../widgets/stars_and_effects.dart';
import '../../widgets/symbol_icon.dart';
import '../gameplay/gameplay_hud.dart';

/// Victory or failure summary with score, stars, stats and next actions.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.result, required this.outcome});

  final GameResult result;
  final RecordOutcome outcome;

  bool get _hasNextLevel =>
      result.won &&
      result.config.mode == GameModeType.classic &&
      (result.config.level ?? LevelProgression.totalLevels) <
          LevelProgression.totalLevels;

  Future<void> _leave(BuildContext context, void Function() go) async {
    await AppScope.of(context).ads.maybeShowInterstitial();
    if (context.mounted) go();
  }

  void _replay(BuildContext context) {
    final services = AppScope.of(context);
    _leave(context, () {
      AppNavigator.toGameplay(
        context,
        result.config.withNewSeed(services.random),
        replace: true,
      );
    });
  }

  void _next(BuildContext context) {
    final services = AppScope.of(context);
    final next = result.config.level! + 1;
    _leave(context, () {
      AppNavigator.toGameplay(
        context,
        LevelProgression.levelConfig(
          next,
          seed: services.random.nextInt(1 << 31),
        ),
        replace: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final reduced = services.reducedMotion(context);
    final won = result.won;
    final heading = won
        ? switch (result.config.mode) {
            GameModeType.daily => 'DAILY COMPLETE!',
            GameModeType.practice => 'WELL PLAYED!',
            _ => 'LEVEL COMPLETE!',
          }
        : (result.failureReason == FailureReason.outOfTime
              ? "TIME'S UP!"
              : 'OUT OF MOVES!');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) AppNavigator.popToHome(context);
      },
      child: Scaffold(
        body: GameBackground(
          child: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: ContentWidth(
                    maxWidth: 480,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        OutlinedTitle(
                          heading,
                          size: 40,
                          color: won ? AppColors.yellow : AppColors.coral,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.config.title,
                          style: AppTheme.display(20, color: AppColors.lilac),
                        ),
                        const SizedBox(height: 16),
                        if (won)
                          AnimatedStars(
                            earned: result.stars,
                            reducedMotion: reduced,
                            onStarShown: () => services.audio.play(Sfx.star),
                          )
                        else
                          SymbolIcon(
                            result.failureReason == FailureReason.outOfTime
                                ? GameSymbol.hourglass
                                : GameSymbol.cross,
                            size: 80,
                            color: AppColors.coral,
                          ),
                        const SizedBox(height: 16),
                        GamePanel(
                          child: Column(
                            children: [
                              if (won) ...[
                                const Text(
                                  'SCORE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.inkSoft,
                                    letterSpacing: 2,
                                  ),
                                ),
                                _ScoreCounter(
                                  score: result.score,
                                  animate: !reduced,
                                ),
                                _BestLine(result: result, outcome: outcome),
                                const SizedBox(height: 14),
                              ] else ...[
                                Text(
                                  result.failureReason ==
                                          FailureReason.outOfTime
                                      ? 'The clock ran out. Try again — you were close!'
                                      : 'No moves left. Plan your flips and try again!',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              _StatsGrid(result: result),
                            ],
                          ),
                        ),
                        if (won &&
                            result.config.mode == GameModeType.classic &&
                            result.config.level ==
                                LevelProgression.totalLevels) ...[
                          const SizedBox(height: 12),
                          const _Banner(
                            key: Key('campaign_complete'),
                            icon: Icons.emoji_events_rounded,
                            text:
                                'You have completed all 30 levels! Keep playing the Daily '
                                'Challenge, Timed and Limited Moves modes, or replay levels for 3 stars.',
                            color: AppColors.violet,
                          ),
                        ],
                        if (outcome.unlockedLevel != null) ...[
                          const SizedBox(height: 12),
                          _Banner(
                            icon: Icons.lock_open_rounded,
                            text: 'Level ${outcome.unlockedLevel} unlocked!',
                            color: AppColors.teal,
                          ),
                        ],
                        for (final a in outcome.newAchievements) ...[
                          const SizedBox(height: 10),
                          _Banner(
                            icon: Icons.emoji_events_rounded,
                            text: 'Achievement: ${a.title}',
                            color: AppColors.orange,
                          ),
                        ],
                        if (result.config.mode == GameModeType.practice) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Practice games are not recorded in stats or records.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_hasNextLevel) ...[
                          ChunkyButton(
                            key: const Key('next_level_button'),
                            label: 'NEXT LEVEL',
                            icon: Icons.arrow_forward_rounded,
                            height: 64,
                            fontSize: 26,
                            onPressed: () => _next(context),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: ChunkyButton.styled(
                                won ? ChunkyButton.sky : ChunkyButton.teal,
                                key: const Key('replay_button'),
                                label: won ? 'REPLAY' : 'RETRY',
                                icon: Icons.replay_rounded,
                                onPressed: () => _replay(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChunkyButton.styled(
                                ChunkyButton.coral,
                                key: const Key('home_button'),
                                label: 'HOME',
                                icon: Icons.home_rounded,
                                onPressed: () => _leave(
                                  context,
                                  () => AppNavigator.popToHome(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        services.ads.banner(),
                      ],
                    ),
                  ),
                ),
              ),
              if (won) Positioned.fill(child: ConfettiBurst(enabled: !reduced)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCounter extends StatelessWidget {
  const _ScoreCounter({required this.score, required this.animate});
  final int score;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Score $score',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(
          begin: animate ? 0 : score.toDouble(),
          end: score.toDouble(),
        ),
        duration: Duration(milliseconds: animate ? 1200 : 0),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text(
          '${v.round()}',
          key: const Key('score_text'),
          style: AppTheme.display(52, color: AppColors.ink),
        ),
      ),
    );
  }
}

class _BestLine extends StatelessWidget {
  const _BestLine({required this.result, required this.outcome});
  final GameResult result;
  final RecordOutcome outcome;

  @override
  Widget build(BuildContext context) {
    if (!outcome.recorded) return const SizedBox.shrink();
    if (outcome.isNewBest) {
      return Container(
        key: const Key('new_best'),
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.coral,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          outcome.previousBest == null
              ? 'FIRST CLEAR · NEW BEST!'
              : 'NEW BEST! (was ${outcome.previousBest})',
          style: AppTheme.display(16),
        ),
      );
    }
    return Text(
      'Best: ${outcome.previousBest ?? result.score}',
      style: const TextStyle(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.result});
  final GameResult result;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      (
        'Moves',
        '${result.moves}${result.config.moveLimit != null ? ' / ${result.config.moveLimit}' : ''}',
      ),
      ('Time', formatSeconds(result.elapsedSeconds)),
      ('Pairs', '${result.matchedPairs} / ${result.totalPairs}'),
      ('Accuracy', '${(result.accuracy * 100).round()}%'),
      ('Best combo', '${result.bestCombo}'),
      ('Hints used', '${result.hintsUsed}'),
    ];
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final (label, value) in items)
              Container(
                width: 132,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.panelBorder.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
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
                    Text(
                      value,
                      style: AppTheme.display(22, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Accuracy = pairs ÷ moves (100% = no wasted flips)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white70, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: AppTheme.display(18))),
        ],
      ),
    );
  }
}
