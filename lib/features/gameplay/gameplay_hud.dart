import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../game/game_config.dart';
import '../../game/game_state.dart';
import '../../widgets/game_button.dart';

String formatSeconds(double seconds) {
  final s = seconds.isFinite ? seconds.ceil().clamp(0, 359999) : 0;
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

/// Top HUD: pause, title, hint, and stat chips (moves, time, pairs).
class GameplayHud extends StatelessWidget {
  const GameplayHud({
    super.key,
    required this.session,
    required this.landscape,
    required this.rewardedAvailable,
    required this.onPause,
    required this.onHint,
    required this.onRestart,
  });

  final GameSession session;
  final bool landscape;
  final bool rewardedAvailable;
  final VoidCallback onPause;
  final VoidCallback onHint;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final c = session.config;
    final hints = session.hintsRemaining;
    final canHint =
        session.canUseHint ||
        (hints == 0 && rewardedAvailable && session.acceptsInput);
    final hintBadge = hints == null
        ? '∞'
        : (hints == 0 && rewardedAvailable ? 'AD' : '$hints');

    final title = Column(
      crossAxisAlignment: landscape
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          c.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.display(22).copyWith(
            shadows: const [
              Shadow(color: Color(0x66000000), offset: Offset(0, 2)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        _DifficultyChip(
          difficulty: c.difficulty,
          size: '${c.columns}×${c.rows}',
        ),
      ],
    );

    final pauseBtn = RoundIconButton(
      key: const Key('pause_button'),
      icon: Icons.pause_rounded,
      semanticLabel: 'Pause',
      onPressed: session.isFinished ? null : onPause,
    );
    final restartBtn = RoundIconButton(
      key: const Key('restart_button'),
      icon: Icons.refresh_rounded,
      semanticLabel: 'Restart board',
      color: AppColors.skyDark,
      size: 44,
      onPressed: session.isFinished ? null : onRestart,
    );
    final hintBtn = RoundIconButton(
      key: const Key('hint_button'),
      icon: Icons.lightbulb_rounded,
      semanticLabel: hints == null
          ? 'Hint, unlimited'
          : (hints == 0 && rewardedAvailable
                ? 'Watch an ad for a hint'
                : 'Hint, $hints left'),
      color: AppColors.orangeDark,
      badge: hintBadge,
      onPressed: canHint ? onHint : null,
    );

    final stats = _StatsRow(session: session, vertical: landscape);

    if (landscape) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                pauseBtn,
                const SizedBox(width: 10),
                restartBtn,
                const SizedBox(width: 10),
                hintBtn,
              ],
            ),
            const SizedBox(height: 14),
            title,
            const SizedBox(height: 14),
            stats,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              pauseBtn,
              const SizedBox(width: 8),
              restartBtn,
              Expanded(child: title),
              const SizedBox(width: 52),
              hintBtn,
            ],
          ),
          const SizedBox(height: 10),
          stats,
        ],
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.difficulty, required this.size});
  final Difficulty difficulty;
  final String size;

  @override
  Widget build(BuildContext context) {
    final color = switch (difficulty) {
      Difficulty.easy => AppColors.teal,
      Difficulty.medium => AppColors.sky,
      Difficulty.hard => AppColors.orange,
      Difficulty.expert => AppColors.coral,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white54),
      ),
      child: Text(
        '${difficulty.label.toUpperCase()} · $size',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.session, required this.vertical});
  final GameSession session;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = session.config;
    final movesLeft = session.movesRemaining;
    final timeLeft = session.timeRemaining;

    final moves = _StatChip(
      key: const Key('moves_chip'),
      icon: Icons.touch_app_rounded,
      label: movesLeft != null ? 'MOVES LEFT' : 'MOVES',
      value: movesLeft != null ? '$movesLeft' : '${session.moves}',
      warning: movesLeft != null && movesLeft <= 3,
    );
    final time = _StatChip(
      key: const Key('time_chip'),
      icon: timeLeft != null
          ? Icons.hourglass_bottom_rounded
          : Icons.timer_outlined,
      label: timeLeft != null ? 'TIME LEFT' : 'TIME',
      value: formatSeconds(timeLeft ?? session.elapsedSeconds),
      warning: timeLeft != null && timeLeft <= 10,
    );
    final pairs = _PairsChip(matched: session.matchedPairs, total: c.pairs);

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          moves,
          const SizedBox(height: 8),
          time,
          const SizedBox(height: 8),
          pairs,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: moves),
        const SizedBox(width: 8),
        Expanded(child: time),
        const SizedBox(width: 8),
        Expanded(child: pairs),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value${warning ? ', running low' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: warning ? AppColors.danger : const Color(0x33000000),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: warning ? Colors.white : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              warning ? Icons.warning_amber_rounded : icon,
              color: AppColors.yellow,
              size: 20,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: AppTheme.display(20)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairsChip extends StatelessWidget {
  const _PairsChip({required this.matched, required this.total});
  final int matched;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : matched / total;
    return Semantics(
      label: 'Pairs $matched of $total',
      excludeSemantics: true,
      child: Container(
        key: const Key('pairs_chip'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAIRS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white70,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('$matched/$total', style: AppTheme.display(20)),
            ),
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white24,
                color: AppColors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Memorize!" countdown shown during the preview phase.
class PreviewBanner extends StatelessWidget {
  const PreviewBanner({super.key, required this.session});
  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final secs = session.previewRemaining.ceil();
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.yellow, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x88000000), blurRadius: 12),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Semantics(
                  liveRegion: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Memorize!  $secs',
                      style: AppTheme.display(22, color: AppColors.yellow),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ChunkyButton.styled(
                ChunkyButton.teal,
                key: const Key('skip_preview'),
                label: 'GO',
                semanticLabel: 'Start now',
                expand: false,
                height: 40,
                fontSize: 18,
                onPressed: session.skipPreview,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
