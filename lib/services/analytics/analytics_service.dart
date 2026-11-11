import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Gameplay events worth measuring. Parameters never include personal data
/// (no names, emails, device identifiers or free text).
enum AnalyticsEvent {
  gameStarted,
  levelStarted,
  matchFound,
  levelCompleted,
  levelFailed,
  tutorialCompleted,
  rewardClaimed,
  achievementUnlocked,
}

abstract class AnalyticsService {
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]);

  /// Turns collection on/off (Settings → Analytics & crash reports).
  void setEnabled(bool enabled) {}

  /// Optional navigator observer for automatic screen_view events.
  NavigatorObserver? get navigatorObserver => null;
}

/// Local fallback: keeps a short in-memory log and prints in debug builds.
/// Nothing leaves the device. Used when Firebase is unavailable and in tests;
/// production uses FirebaseAnalyticsService.
class LocalAnalyticsService extends AnalyticsService {
  LocalAnalyticsService({this.enabled = true, this.maxEntries = 200});

  bool enabled;

  @override
  void setEnabled(bool enabled) => this.enabled = enabled;

  final int maxEntries;
  final List<(AnalyticsEvent, Map<String, Object>)> entries = [];

  @override
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]) {
    if (!enabled) return;
    entries.add((event, params));
    if (entries.length > maxEntries) entries.removeAt(0);
    if (kDebugMode) debugPrint('[analytics] ${event.name} $params');
  }
}

/// Crash/error reporting abstraction.
abstract class CrashReporter {
  void recordError(Object error, StackTrace? stack, {bool fatal = false});

  void recordFlutterError(FlutterErrorDetails details) =>
      recordError(details.exception, details.stack);

  void setEnabled(bool enabled) {}

  /// Whether [sendTestCrash] does anything (shown as a debug-only button).
  bool get supportsTestCrash => false;

  /// Forces a crash to verify the reporting pipeline.
  void sendTestCrash() {}
}

class DebugCrashReporter extends CrashReporter {
  final List<Object> errors = [];

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    errors.add(error);
    if (errors.length > 50) errors.removeAt(0);
    debugPrint('[crash${fatal ? ':fatal' : ''}] $error');
  }
}
