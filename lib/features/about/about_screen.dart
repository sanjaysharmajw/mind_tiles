import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_scope.dart';
import '../../app/app_theme.dart';
import '../../widgets/panels.dart';

/// Privacy information, credits and version.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _mobilePrivacy =
      '• No account or sign-in is needed, and the game is fully playable offline.\n'
      '• Your progress, scores, statistics and settings are stored on this device.\n'
      '• Ads are provided by Google AdMob. Where required by law you are asked for '
      'consent first, and you can change it under Settings > Ad privacy choices.\n'
      '• Anonymous usage statistics, crash reports and performance data are sent to '
      'Google Firebase to improve the game. Turn this off in Settings > '
      'Share usage & crash reports.\n'
      '• Notifications are only sent if you switch on Daily reminders.\n'
      '• Uninstalling the app or using “Reset all progress” deletes your saved progress.';

  static const String _playablesPrivacy =
      '• Mind Tiles does not ask for or collect any personal information.\n'
      '• Your progress, scores, statistics and settings are saved to your YouTube '
      'account through YouTube Playables cloud save.\n'
      '• The game makes no network requests of its own. Any ads are provided by '
      'YouTube under YouTube\'s Terms of Service and Privacy Policy.\n'
      '• “Reset all progress” in Settings erases your saved progress.';

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    const body = TextStyle(fontSize: 15, height: 1.4, color: AppColors.ink);
    Widget heading(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Semantics(
        header: true,
        child: Text(t, style: AppTheme.display(20, color: AppColors.ink)),
      ),
    );
    return GameScreenScaffold(
      title: 'Privacy & About',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: ContentWidth(
          child: GamePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConfig.appName,
                  style: AppTheme.display(30, color: AppColors.ink),
                ),
                Text(
                  'Version ${AppConfig.fullVersion}',
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                heading('Privacy'),
                Text(
                  services.isPlayables ? _playablesPrivacy : _mobilePrivacy,
                  style: body,
                ),
                heading('Credits'),
                const Text(
                  '• Game design, code, symbols and sounds: original work created for Mind Tiles.\n'
                  '• Fonts: Lilita One by Juan Montoreano and Roboto by The Roboto Project Authors, SIL Open Font License 1.1.\n'
                  '• Built with Flutter and the Flame game engine (MIT / BSD licenses).',
                  style: body,
                ),
                const SizedBox(height: 14),
                if (kDebugMode && services.crash.supportsTestCrash)
                  Center(
                    child: TextButton(
                      key: const Key('test_crash'),
                      // Debug builds only: verifies the Crashlytics pipeline.
                      onPressed: services.crash.sendTestCrash,
                      child: const Text(
                        'Send test crash (debug; needs CRASHLYTICS_DEBUG=true)',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: TextButton(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: AppConfig.appName,
                      applicationVersion: AppConfig.fullVersion,
                    ),
                    child: const Text(
                      'Open-source licenses',
                      style: TextStyle(
                        color: AppColors.violet,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
