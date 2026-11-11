import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../firebase_options.dart';
import '../analytics/analytics_service.dart';
import '../performance/performance_tracer.dart';

/// Initializes Firebase. Returns false (and the app keeps working with local
/// services) if initialization fails, e.g. on an unsupported platform.
Future<bool> initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return true;
  } catch (e) {
    debugPrint('Firebase init failed, continuing offline-only: $e');
    return false;
  }
}

/// Converts `levelCompleted` → `level_completed` (Firebase naming rules).
String firebaseEventName(AnalyticsEvent e) =>
    e.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// Firebase only accepts String and num parameter values (max 100 chars).
Map<String, Object> firebaseParams(Map<String, Object> params) => {
  for (final e in params.entries)
    e.key: switch (e.value) {
      final bool b => b ? 1 : 0,
      final num n => n,
      final Object o =>
        o.toString().length > 100
            ? o.toString().substring(0, 100)
            : o.toString(),
    },
};

/// Firebase Analytics. Events appear in the Realtime dashboard within
/// seconds and in DebugView when debug mode is on (see docs).
class FirebaseAnalyticsService extends AnalyticsService {
  FirebaseAnalyticsService() : _fa = FirebaseAnalytics.instance;

  final FirebaseAnalytics _fa;
  bool _enabled = true;

  @override
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]) {
    if (!_enabled) return;
    if (kDebugMode) {
      debugPrint('[analytics→firebase] ${firebaseEventName(event)} $params');
    }
    _fa
        .logEvent(
          name: firebaseEventName(event),
          parameters: firebaseParams(params),
        )
        .catchError((Object e) => debugPrint('analytics log failed: $e'));
  }

  @override
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _fa.setAnalyticsCollectionEnabled(enabled).catchError((_) {});
  }

  @override
  NavigatorObserver get navigatorObserver => FirebaseAnalyticsObserver(
    analytics: _fa,
    // Only named routes (all app screens are named) become screen_view.
    routeFilter: (route) => route is PageRoute && route.settings.name != null,
  );
}

/// Firebase Crashlytics. Collection is disabled in debug builds so local
/// development does not pollute crash reports.
class CrashlyticsReporter extends CrashReporter {
  /// Run with `--dart-define=CRASHLYTICS_DEBUG=true` to send reports from a
  /// debug build (e.g. to verify setup with the test-crash button).
  static const bool reportInDebug = bool.fromEnvironment('CRASHLYTICS_DEBUG');

  final FirebaseCrashlytics _c = FirebaseCrashlytics.instance;

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    if (kDebugMode) debugPrint('[crashlytics${fatal ? ':fatal' : ''}] $error');
    _c.recordError(error, stack, fatal: fatal).catchError((_) {});
  }

  @override
  bool get supportsTestCrash => true;

  @override
  void sendTestCrash() => _c.crash();

  @override
  void recordFlutterError(FlutterErrorDetails details) {
    _c.recordFlutterError(details).catchError((_) {});
  }

  @override
  void setEnabled(bool enabled) {
    _c
        .setCrashlyticsCollectionEnabled(
          enabled && (!kDebugMode || reportInDebug),
        )
        .catchError((_) {});
  }
}

/// Firebase Performance Monitoring. App start, screen rendering and network
/// traces are automatic; this adds custom traces such as `level_play`.
class FirebasePerformanceTracer extends PerformanceTracer {
  final FirebasePerformance _p = FirebasePerformance.instance;
  bool _enabled = true;

  @override
  PerfTrace start(String name, {Map<String, String> attributes = const {}}) {
    if (!_enabled) return NoopTrace();
    try {
      final t = _p.newTrace(name);
      attributes.forEach(t.putAttribute);
      t.start().catchError((_) {});
      return _FirebaseTrace(t);
    } catch (e) {
      debugPrint('perf trace failed: $e');
      return NoopTrace();
    }
  }

  @override
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _p.setPerformanceCollectionEnabled(enabled).catchError((_) {});
  }
}

class _FirebaseTrace implements PerfTrace {
  _FirebaseTrace(this._t);
  final Trace _t;
  bool _stopped = false;

  @override
  void setMetric(String name, int value) => _t.setMetric(name, value);
  @override
  void putAttribute(String name, String value) => _t.putAttribute(name, value);
  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await _t.stop().catchError((_) {});
  }
}
