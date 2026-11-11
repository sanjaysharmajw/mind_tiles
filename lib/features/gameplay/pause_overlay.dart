import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_theme.dart';
import '../../game/game_state.dart';
import '../../widgets/game_button.dart';
import '../../widgets/panels.dart';
import 'gameplay_hud.dart';

/// Full-screen pause menu. It hides the board (no peeking at tiles while
/// paused) and offers resume, restart, audio/haptic toggles and quit.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.title,
    required this.session,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  final String title;
  final GameSession session;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xF01C1040),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: GamePanel(
                  child: ListenableBuilder(
                    listenable: player,
                    builder: (context, _) {
                      final s = player.settings;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              key: const Key('pause_title'),
                              textAlign: TextAlign.center,
                              style: AppTheme.display(34, color: AppColors.ink),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${session.config.title} · ${session.matchedPairs}/${session.totalPairs} pairs · '
                            '${session.moves} moves · ${formatSeconds(session.elapsedSeconds)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ChunkyButton(
                            key: const Key('resume_button'),
                            label: 'RESUME',
                            icon: Icons.play_arrow_rounded,
                            onPressed: onResume,
                          ),
                          const SizedBox(height: 12),
                          ChunkyButton.styled(
                            ChunkyButton.sky,
                            key: const Key('pause_restart_button'),
                            label: 'RESTART',
                            icon: Icons.refresh_rounded,
                            onPressed: onRestart,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _Toggle(
                                icon: s.soundOn
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                                label: 'Sound',
                                on: s.soundOn,
                                onTap: () => player.updateSettings(
                                  s.copyWith(soundOn: !s.soundOn),
                                ),
                              ),
                              _Toggle(
                                icon: s.musicOn
                                    ? Icons.music_note_rounded
                                    : Icons.music_off_rounded,
                                label: 'Music',
                                on: s.musicOn,
                                onTap: () => player.updateSettings(
                                  s.copyWith(musicOn: !s.musicOn),
                                ),
                              ),
                              _Toggle(
                                icon: s.hapticsOn
                                    ? Icons.vibration_rounded
                                    : Icons.mobile_off_rounded,
                                label: 'Haptics',
                                on: s.hapticsOn,
                                onTap: () => player.updateSettings(
                                  s.copyWith(hapticsOn: !s.hapticsOn),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ChunkyButton.styled(
                            ChunkyButton.coral,
                            key: const Key('quit_button'),
                            label: 'MAIN MENU',
                            icon: Icons.home_rounded,
                            onPressed: onQuit,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          RoundIconButton(
            icon: icon,
            semanticLabel: '$label ${on ? 'on' : 'off'}',
            color: on ? AppColors.teal : AppColors.grey,
            onPressed: onTap,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$label: ${on ? 'On' : 'Off'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
