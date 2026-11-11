import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_theme.dart';
import '../../app/navigation.dart';
import '../../game/board/game_symbol.dart';
import '../../game/game_config.dart';
import '../../game/modes/game_mode.dart';
import '../../game/modes/limited_moves_mode.dart';
import '../../game/modes/timed_mode.dart';
import '../../game/systems/level_progression.dart';
import '../../widgets/game_button.dart';
import '../../widgets/panels.dart';
import '../../widgets/symbol_icon.dart';
import '../gameplay/gameplay_hud.dart';

/// Lists every game mode. Each card leads to a fully playable experience.
class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modes = <(GameModeType, GameSymbol, ChunkyButtonStyle, String)>[
      (
        GameModeType.classic,
        GameSymbol.star,
        ChunkyButton.sky,
        'Work through 30 handcrafted levels.',
      ),
      (
        GameModeType.timed,
        GameSymbol.hourglass,
        ChunkyButton.orange,
        'Clear the board before the countdown hits zero.',
      ),
      (
        GameModeType.limitedMoves,
        GameSymbol.diceFive,
        ChunkyButton.teal,
        'A fixed number of pair attempts — make each one count.',
      ),
      (
        GameModeType.daily,
        GameSymbol.sun,
        ChunkyButton.coral,
        'One shared board per day. Keep your streak alive!',
      ),
      (
        GameModeType.practice,
        GameSymbol.flower,
        ChunkyButton.grey,
        'Any board size, no clock, unlimited hints. Not recorded.',
      ),
    ];
    return GameScreenScaffold(
      title: 'Game Modes',
      body: ContentWidth(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: modes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            final (type, icon, style, blurb) = modes[i];
            return _ModeCard(
              type: type,
              icon: icon,
              style: style,
              blurb: blurb,
            );
          },
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.type,
    required this.icon,
    required this.style,
    required this.blurb,
  });

  final GameModeType type;
  final GameSymbol icon;
  final ChunkyButtonStyle style;
  final String blurb;

  void _open(BuildContext context) {
    switch (type) {
      case GameModeType.classic:
        AppNavigator.toLevels(context);
      case GameModeType.daily:
        AppNavigator.toDaily(context);
      default:
        showDifficultyPicker(context, GameModeRules.of(type));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = GameModeRules.of(type);
    return GamePanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: style.$1,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: SymbolIcon(icon, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rules.title,
                  style: AppTheme.display(22, color: AppColors.ink),
                ),
                Text(
                  blurb,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                ChunkyButton.styled(
                  style,
                  key: Key('mode_${type.name}'),
                  label: 'PLAY',
                  semanticLabel: 'Play ${rules.title}',
                  height: 40,
                  fontSize: 18,
                  onPressed: () => _open(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _limitText(GameModeRules rules, Difficulty d) => switch (rules.type) {
  GameModeType.timed =>
    '${formatSeconds(TimedMode.timeLimitFor(d).toDouble())} clock',
  GameModeType.limitedMoves => '${LimitedMovesMode.moveLimitFor(d)} moves',
  _ => 'no limits',
};

/// Lets the player pick a difficulty for Timed / Limited Moves / Practice.
Future<void> showDifficultyPicker(BuildContext context, GameModeRules rules) {
  final services = AppScope.of(context);
  final player = services.player;
  return showGameDialog<void>(
    context: context,
    title: rules.title,
    message: rules.tagline,
    actions: [
      for (final d in Difficulty.values)
        Builder(
          builder: (ctx) {
            final unlocked = player.isDifficultyUnlocked(rules, d);
            final spec = BoardSpec.forDifficulty(d);
            final best = player.modeRecord('${rules.type.name}_${d.name}');
            final subtitle = unlocked
                ? '${spec.columns}×${spec.rows} · ${_limitText(rules, d)}'
                      '${best != null && best.bestScore > 0 ? ' · best ${best.bestScore}' : ''}'
                : 'Complete Classic level ${LevelProgression.requiredLevelFor(d)} to unlock';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChunkyButton.styled(
                  unlocked ? ChunkyButton.sky : ChunkyButton.grey,
                  key: Key('difficulty_${d.name}'),
                  label: d.label.toUpperCase(),
                  icon: unlocked ? null : Icons.lock_rounded,
                  semanticLabel:
                      '${d.label}${unlocked ? '' : ', locked'}. $subtitle',
                  height: 46,
                  fontSize: 19,
                  onPressed: unlocked
                      ? () {
                          Navigator.of(ctx).pop();
                          AppNavigator.toGameplay(
                            context,
                            rules.configFor(
                              d,
                              seed: services.random.nextInt(1 << 31),
                            ),
                          );
                        }
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      Builder(
        builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ),
    ],
  );
}
