import 'package:flutter/foundation.dart';

import '../services/analytics/analytics_service.dart';
import 'playables_platform.dart';

/// Reports errors to YouTube via `ytgame.health.logError` (best effort,
/// rate-limited by YouTube). No third-party crash service is allowed.
class PlayablesCrashReporter extends CrashReporter {
  PlayablesCrashReporter(this._platform);
  final PlayablesPlatform _platform;

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    debugPrint('[playables${fatal ? ':fatal' : ''}] $error');
    _platform.logError();
  }
}
