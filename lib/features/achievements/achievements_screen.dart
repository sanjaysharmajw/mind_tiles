import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_theme.dart';
import '../../models/achievement.dart';
import '../../widgets/panels.dart';
import '../../widgets/symbol_icon.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    return GameScreenScaffold(
      title: 'Achievements',
      body: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final data = player.data;
          return ContentWidth(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: Achievements.all.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Text(
                    '${data.achievements.length} of ${Achievements.all.length} unlocked',
                    textAlign: TextAlign.center,
                    style: AppTheme.display(18, color: AppColors.lilac),
                  );
                }
                final a = Achievements.all[i - 1];
                final unlockedAt = data.achievements[a.id.name];
                final progress = min(a.progress(data), a.target);
                return _AchievementTile(
                  def: a,
                  unlocked: unlockedAt != null,
                  unlockedAt: unlockedAt == null
                      ? null
                      : DateTime.tryParse(unlockedAt),
                  progress: progress,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.def,
    required this.unlocked,
    required this.unlockedAt,
    required this.progress,
  });

  final AchievementDef def;
  final bool unlocked;
  final DateTime? unlockedAt;
  final int progress;

  @override
  Widget build(BuildContext context) {
    final date = unlockedAt;
    return Semantics(
      label:
          '${def.title}, ${unlocked ? 'unlocked' : 'locked'}. ${def.description} '
          'Progress $progress of ${def.target}.',
      excludeSemantics: true,
      child: GamePanel(
        padding: const EdgeInsets.all(12),
        color: unlocked ? AppColors.panel : const Color(0xFFE9E4F5),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                MiniTile(symbol: def.icon, size: 54, faceDown: !unlocked),
                if (unlocked)
                  const Positioned(
                    right: -4,
                    top: -4,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.success,
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  const Positioned(
                    right: -4,
                    top: -4,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.greyDark,
                      child: Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    def.title,
                    style: AppTheme.display(19, color: AppColors.ink),
                  ),
                  Text(
                    def.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: def.target == 0 ? 1 : progress / def.target,
                            minHeight: 8,
                            backgroundColor: AppColors.panelBorder,
                            color: unlocked
                                ? AppColors.success
                                : AppColors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$progress/${def.target}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (date != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Unlocked ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft,
                        ),
                      ),
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
