import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_theme.dart';
import '../../app/navigation.dart';
import '../../game/game_config.dart';
import '../../game/systems/level_progression.dart';
import '../../widgets/panels.dart';
import '../../widgets/stars_and_effects.dart';

/// Classic campaign: 30 levels grouped by difficulty, with lock state,
/// stars and best scores.
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final player = services.player;
    return GameScreenScaffold(
      title: 'Classic Levels',
      trailing: ListenableBuilder(
        listenable: player,
        builder: (context, _) => _StarTotal(stars: player.data.totalStars),
      ),
      body: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final groups = <Difficulty, List<int>>{};
          for (var l = 1; l <= LevelProgression.totalLevels; l++) {
            groups
                .putIfAbsent(LevelProgression.difficultyOfLevel(l), () => [])
                .add(l);
          }
          return ContentWidth(
            maxWidth: 640,
            child: CustomScrollView(
              slivers: [
                for (final entry in groups.entries) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Semantics(
                        header: true,
                        child: Text(
                          entry.key.label.toUpperCase(),
                          style: AppTheme.display(20, color: AppColors.lilac),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 110,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _LevelCell(level: entry.value[i]),
                        childCount: entry.value.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StarTotal extends StatelessWidget {
  const _StarTotal({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0x33000000),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const StarRow(earned: 1, max: 1, size: 20),
        const SizedBox(width: 4),
        Text(
          '$stars/${LevelProgression.totalLevels * 3}',
          style: AppTheme.display(16),
        ),
      ],
    ),
  );
}

class _LevelCell extends StatelessWidget {
  const _LevelCell({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final player = services.player;
    final unlocked = player.isLevelUnlocked(level);
    final record = player.levelRecord(level);
    final config = LevelProgression.levelConfig(level, seed: 0);
    final completed = record != null && record.completions > 0;
    final current = unlocked && !completed;

    final face = !unlocked
        ? AppColors.greyDark
        : (current ? AppColors.yellow : const Color(0xFFFFE9A8));
    final edge = !unlocked ? const Color(0xFF3F3A57) : AppColors.yellowDark;

    return Semantics(
      button: true,
      label: unlocked
          ? 'Level $level, ${config.columns} by ${config.rows}'
                '${completed ? ', ${record.stars} stars, best ${record.bestScore}' : ', not completed'}'
          : 'Level $level, locked',
      excludeSemantics: true,
      onTap: () => _open(context, unlocked),
      child: GestureDetector(
        key: Key('level_$level'),
        onTap: () => _open(context, unlocked),
        child: Container(
          decoration: BoxDecoration(
            color: edge,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.only(bottom: 5),
          child: Container(
            decoration: BoxDecoration(
              color: face,
              borderRadius: BorderRadius.circular(18),
              border: current
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!unlocked)
                  const Icon(
                    Icons.lock_rounded,
                    color: Colors.white70,
                    size: 30,
                  )
                else
                  FittedBox(
                    child: Text(
                      '$level',
                      style: AppTheme.display(32, color: AppColors.ink),
                    ),
                  ),
                const SizedBox(height: 2),
                FittedBox(
                  child: Text(
                    '${config.columns}×${config.rows}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: unlocked ? AppColors.inkSoft : Colors.white60,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                if (unlocked)
                  FittedBox(child: StarRowDark(earned: record?.stars ?? 0)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, bool unlocked) {
    final services = AppScope.of(context);
    if (!unlocked) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Complete level ${level - 1} to unlock level $level.',
            ),
          ),
        );
      return;
    }
    services.buttonFeedback();
    AppNavigator.toGameplay(
      context,
      LevelProgression.levelConfig(
        level,
        seed: services.random.nextInt(1 << 31),
      ),
    );
  }
}

/// Star row variant for light backgrounds.
class StarRowDark extends StatelessWidget {
  const StarRowDark({super.key, required this.earned});
  final int earned;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: AppColors.ink.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(10),
    ),
    child: StarRow(earned: earned, size: 14),
  );
}
