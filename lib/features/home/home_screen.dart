import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_theme.dart';
import '../../app/navigation.dart';
import '../../game/board/game_symbol.dart';
import '../../game/modes/daily_challenge_mode.dart';
import '../../game/systems/level_progression.dart';
import '../../widgets/game_background.dart';
import '../../widgets/game_button.dart';
import '../../widgets/panels.dart';
import '../../widgets/symbol_icon.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _playNext(BuildContext context) async {
    final services = AppScope.of(context);
    if (!services.player.tutorialSeen) {
      await AppNavigator.toTutorial(context);
      if (!context.mounted) return;
    }
    final level = services.player.nextLevelToPlay;
    await AppNavigator.toGameplay(
      context,
      LevelProgression.levelConfig(
        level,
        seed: services.random.nextInt(1 << 31),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: services.player,
            builder: (context, _) {
              final player = services.player;
              final now = services.clock();
              final snapshot = player.resumableSnapshot(now);
              final settings = player.settings;
              final dailyDone = player.data.daily.isCompleted(
                DailyChallengeMode.dateKey(now),
              );
              final streak = player.dailyStreak(now);
              final allDone =
                  player.highestCompletedLevel >= LevelProgression.totalLevels;

              final topBar = Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    RoundIconButton(
                      key: const Key('stats_button'),
                      icon: Icons.bar_chart_rounded,
                      semanticLabel: 'Statistics',
                      color: AppColors.skyDark,
                      onPressed: () => AppNavigator.toStatistics(context),
                    ),
                    const SizedBox(width: 10),
                    RoundIconButton(
                      key: const Key('achievements_button'),
                      icon: Icons.emoji_events_rounded,
                      semanticLabel: 'Achievements',
                      color: AppColors.orangeDark,
                      badge: player.data.achievements.isEmpty
                          ? null
                          : '${player.data.achievements.length}',
                      onPressed: () => AppNavigator.toAchievements(context),
                    ),
                    const Spacer(),
                    RoundIconButton(
                      icon: settings.soundOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      semanticLabel: settings.soundOn
                          ? 'Turn sound effects off'
                          : 'Turn sound effects on',
                      onPressed: () => player.updateSettings(
                        settings.copyWith(soundOn: !settings.soundOn),
                      ),
                    ),
                    const SizedBox(width: 10),
                    RoundIconButton(
                      icon: settings.musicOn
                          ? Icons.music_note_rounded
                          : Icons.music_off_rounded,
                      semanticLabel: settings.musicOn
                          ? 'Turn music off'
                          : 'Turn music on',
                      onPressed: () => player.updateSettings(
                        settings.copyWith(musicOn: !settings.musicOn),
                      ),
                    ),
                    const SizedBox(width: 10),
                    RoundIconButton(
                      key: const Key('settings_button'),
                      icon: Icons.settings_rounded,
                      semanticLabel: 'Settings',
                      onPressed: () => AppNavigator.toSettings(context),
                    ),
                  ],
                ),
              );

              final buttons = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (snapshot != null) ...[
                    ChunkyButton.styled(
                      ChunkyButton.teal,
                      key: const Key('continue_button'),
                      label: 'CONTINUE',
                      icon: Icons.play_circle_fill_rounded,
                      semanticLabel: 'Continue ${snapshot.config.title}',
                      onPressed: () => AppNavigator.toGameplay(
                        context,
                        snapshot.config,
                        resume: snapshot,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ChunkyButton(
                    key: const Key('play_button'),
                    label: allDone
                        ? 'PLAY LEVEL 30'
                        : 'PLAY · LEVEL ${player.nextLevelToPlay}',
                    icon: Icons.play_arrow_rounded,
                    height: 66,
                    fontSize: 26,
                    onPressed: () => _playNext(context),
                  ),
                  if (allDone)
                    const Padding(
                      key: Key('all_levels_done'),
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'All 30 levels complete! Try the Daily Challenge, Timed and Limited Moves modes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.lilac,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChunkyButton.styled(
                          ChunkyButton.sky,
                          key: const Key('levels_button'),
                          label: 'LEVELS',
                          icon: Icons.grid_view_rounded,
                          fontSize: 19,
                          onPressed: () => AppNavigator.toLevels(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChunkyButton.styled(
                          ChunkyButton.orange,
                          key: const Key('modes_button'),
                          label: 'MODES',
                          icon: Icons.sports_esports_rounded,
                          fontSize: 19,
                          onPressed: () => AppNavigator.toModes(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ChunkyButton.styled(
                    ChunkyButton.coral,
                    key: const Key('daily_button'),
                    label: dailyDone
                        ? 'DAILY · DONE'
                        : (streak > 0
                              ? 'DAILY · STREAK $streak'
                              : 'DAILY CHALLENGE'),
                    semanticLabel: dailyDone
                        ? 'Daily challenge, completed today'
                        : 'Daily challenge${streak > 0 ? ', streak $streak days' : ''}',
                    icon: Icons.today_rounded,
                    fontSize: 19,
                    onPressed: () => AppNavigator.toDaily(context),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _TextLink(
                        label: 'How to play',
                        onTap: () => AppNavigator.toTutorial(context),
                      ),
                      const Text(
                        '  ·  ',
                        style: TextStyle(color: Colors.white54),
                      ),
                      _TextLink(
                        label: 'About & privacy',
                        onTap: () => AppNavigator.toAbout(context),
                      ),
                    ],
                  ),
                ],
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final landscape =
                      constraints.maxWidth > constraints.maxHeight &&
                      constraints.maxHeight < 560;
                  final content = landscape
                      ? Row(
                          children: [
                            const Expanded(
                              child: Center(child: _Logo(compact: true)),
                            ),
                            Expanded(
                              child: Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 420,
                                    ),
                                    child: buttons,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: math.max(
                                0,
                                constraints.maxHeight - 90,
                              ),
                            ),
                            child: ContentWidth(
                              maxWidth: 440,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: _Logo(),
                                  ),
                                  buttons,
                                ],
                              ),
                            ),
                          ),
                        );
                  return Column(
                    children: [
                      topBar,
                      Expanded(child: content),
                      services.ads.banner(),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        AppScope.of(context).buttonFeedback();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: Colors.white54,
          ),
        ),
      ),
    ),
  );
}

/// Title logo: a row of bobbing yellow tiles above outlined "MIND TILES".
class _Logo extends StatefulWidget {
  const _Logo({this.compact = false});
  final bool compact;

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  static const _symbols = [
    GameSymbol.star,
    GameSymbol.heart,
    GameSymbol.hexagon,
    GameSymbol.circleOutline,
    GameSymbol.cross,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppScope.of(context).reducedMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tile = widget.compact ? 40.0 : 52.0;
    return Semantics(
      label: 'Mind Tiles',
      header: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) => FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _symbols.length; i++)
                    Transform.translate(
                      offset: Offset(
                        0,
                        math.sin((_c.value + i * 0.15) * math.pi * 2) * 5,
                      ),
                      child: Transform.rotate(
                        angle: (i - 2) * 0.06,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: MiniTile(symbol: _symbols[i], size: tile),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedTitle(
            'MIND TILES',
            size: widget.compact ? 44 : 56,
            color: AppColors.yellow,
          ),
          const SizedBox(height: 4),
          Text(
            'Flip · Remember · Match',
            style: AppTheme.display(
              widget.compact ? 16 : 18,
              color: AppColors.lilac,
            ),
          ),
        ],
      ),
    );
  }
}
