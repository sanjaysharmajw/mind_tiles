import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_scope.dart';
import '../../app/app_theme.dart';
import '../../app/navigation.dart';
import '../../game/board/game_symbol.dart';
import '../../game/board/tile_palette.dart';
import '../../models/settings.dart';
import '../../widgets/game_button.dart';
import '../../widgets/panels.dart';
import '../../widgets/symbol_icon.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final player = services.player;
    return GameScreenScaffold(
      title: 'Settings',
      body: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final s = player.settings;
          void update(GameSettings next) => player.updateSettings(next);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(
                      title: 'Audio & feel',
                      children: [
                        _SwitchRow(
                          key: const Key('sound_switch'),
                          icon: Icons.volume_up_rounded,
                          label: 'Sound effects',
                          value: s.soundOn,
                          onChanged: (v) => update(s.copyWith(soundOn: v)),
                        ),
                        _SwitchRow(
                          key: const Key('music_switch'),
                          icon: Icons.music_note_rounded,
                          label: 'Music',
                          value: s.musicOn,
                          onChanged: (v) => update(s.copyWith(musicOn: v)),
                        ),
                        _SwitchRow(
                          key: const Key('haptics_switch'),
                          icon: Icons.vibration_rounded,
                          label: 'Haptic feedback',
                          value: s.hapticsOn,
                          onChanged: (v) => update(s.copyWith(hapticsOn: v)),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Gameplay',
                      children: [
                        _SwitchRow(
                          key: const Key('motion_switch'),
                          icon: Icons.animation_rounded,
                          label: 'Reduce motion',
                          subtitle:
                              'Instant flips, no shaking, particles or confetti.',
                          value: s.reducedMotion,
                          onChanged: (v) =>
                              update(s.copyWith(reducedMotion: v)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Memorize preview',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'How long all tiles are shown when a board starts.',
                          style: TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in PreviewSetting.values)
                              _Choice(
                                key: Key('preview_${p.name}'),
                                label: p.label,
                                selected: s.preview == p,
                                onTap: () => update(s.copyWith(preview: p)),
                              ),
                          ],
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Tile theme',
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final t in TileThemeId.values)
                              _ThemeCard(
                                theme: t,
                                selected: s.tileTheme == t,
                                onTap: () => update(s.copyWith(tileTheme: t)),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (!services.isPlayables)
                      _Section(
                        title: 'Notifications & privacy',
                        children: [
                          _SwitchRow(
                            key: const Key('notifications_switch'),
                            icon: Icons.notifications_active_rounded,
                            label: 'Daily reminders',
                            subtitle:
                                'A nudge when a new Daily Challenge is ready.',
                            value: s.notificationsOn,
                            onChanged: (v) async {
                              final on = await services.setNotifications(v);
                              if (v && !on && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Notifications are blocked. Allow them for Mind Tiles in your device settings.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          _SwitchRow(
                            key: const Key('analytics_switch'),
                            icon: Icons.insights_rounded,
                            label: 'Share usage & crash reports',
                            subtitle:
                                'Anonymous gameplay stats and crash logs help us improve the game.',
                            value: s.analyticsOn,
                            onChanged: (v) =>
                                update(s.copyWith(analyticsOn: v)),
                          ),
                          FutureBuilder<bool>(
                            future: services.ads.isPrivacyOptionsRequired(),
                            builder: (context, snap) => snap.data == true
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: ChunkyButton.styled(
                                      ChunkyButton.sky,
                                      key: const Key('ad_privacy_button'),
                                      label: 'AD PRIVACY CHOICES',
                                      icon: Icons.shield_rounded,
                                      height: 48,
                                      fontSize: 18,
                                      onPressed:
                                          services.ads.showPrivacyOptions,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    _Section(
                      title: 'Help & info',
                      children: [
                        ChunkyButton.styled(
                          ChunkyButton.sky,
                          label: 'HOW TO PLAY',
                          icon: Icons.help_rounded,
                          height: 48,
                          fontSize: 18,
                          onPressed: () => AppNavigator.toTutorial(context),
                        ),
                        const SizedBox(height: 10),
                        ChunkyButton.styled(
                          ChunkyButton.teal,
                          label: 'PRIVACY & ABOUT',
                          icon: Icons.privacy_tip_rounded,
                          height: 48,
                          fontSize: 18,
                          onPressed: () => AppNavigator.toAbout(context),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Danger zone',
                      children: [
                        ChunkyButton.styled(
                          ChunkyButton.coral,
                          key: const Key('reset_progress'),
                          label: 'RESET ALL PROGRESS',
                          icon: Icons.delete_forever_rounded,
                          height: 48,
                          fontSize: 18,
                          onPressed: () async {
                            final ok = await confirmAction(
                              context,
                              title: 'Reset progress?',
                              message:
                                  'This permanently erases unlocked levels, stars, scores, statistics '
                                  'and achievements. Settings are kept.',
                              confirmLabel: 'ERASE',
                            );
                            if (ok) {
                              player.resetProgress();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Progress has been reset.'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '${AppConfig.appName} v${AppConfig.fullVersion}',
                        key: const Key('version_text'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: GamePanel(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppTheme.display(22, color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          AppScope.of(context).buttonFeedback();
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: AppColors.violet),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Preview $label',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: () {
        AppScope.of(context).buttonFeedback();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.violet : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.violet : AppColors.panelBorder,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });
  final TileThemeId theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = TilePalette.of(theme);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Tile theme ${theme.label}',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('theme_${theme.name}'),
        onTap: () {
          AppScope.of(context).buttonFeedback();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 100,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? AppColors.violet : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.violet : AppColors.panelBorder,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _swatch(
                    p.faceBottom,
                    p.faceEdge,
                    child: SymbolIcon(
                      GameSymbol.heart,
                      size: 22,
                      color: p.symbol,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _swatch(p.backBottom, p.backEdge),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                theme.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swatch(Color face, Color edge, {Widget? child}) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: face,
      borderRadius: BorderRadius.circular(8),
      border: Border(bottom: BorderSide(color: edge, width: 4)),
    ),
    alignment: Alignment.center,
    child: child,
  );
}
