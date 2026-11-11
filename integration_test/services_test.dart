// On-device check of the live Firebase + AdMob integration.
// Run: flutter test integration_test/services_test.dart -d <device-id>
// (Android 13+: grant notifications first so no system dialog blocks the test:
//  adb shell pm grant com.codestack_mindtiles.game.mind_tiles_game android.permission.POST_NOTIFICATIONS)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mind_tiles_game/services/ads/admob_ad_service.dart';
import 'package:mind_tiles_game/services/analytics/analytics_service.dart';
import 'package:mind_tiles_game/services/firebase/firebase_services.dart';
import 'package:mind_tiles_game/services/notifications/fcm_push_service.dart';

Future<bool> waitFor(bool Function() cond, Duration timeout) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (cond()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  return cond();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Firebase: core, analytics, crashlytics, performance, messaging',
    (tester) async {
      expect(await initializeFirebase(), isTrue);
      expect(Firebase.app().options.projectId, 'mind-tiles-9t1li');

      final analytics = FirebaseAnalyticsService()..setEnabled(true);
      analytics.log(AnalyticsEvent.gameStarted);
      analytics.log(AnalyticsEvent.levelCompleted, {
        'mode': 'integration_test',
        'moves': 8,
      });

      final crash = CrashlyticsReporter()..setEnabled(true);
      crash.recordError(
        StateError('Integration test non-fatal (expected)'),
        StackTrace.current,
      );

      final perf = FirebasePerformanceTracer()..setEnabled(true);
      final trace = perf.start(
        'integration_test_trace',
        attributes: {'source': 'device_test'},
      );
      trace.setMetric('value', 42);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await trace.stop();

      final push = FcmPushService();
      await push.initialize();
      expect(
        await push.enable(),
        isTrue,
        reason: 'notification permission granted',
      );
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('[services_test] FCM token: $token');
      expect(token, isNotNull);
      expect(token!.length, greaterThan(20));
    },
  );

  testWidgets('AdMob: consent, init, test rewarded + interstitial load', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final ads = AdMobAdService();
    expect(
      ads.ids.isTest,
      isTrue,
      reason: 'dev builds must use Google test units',
    );
    await ads.initialize();
    expect(
      ads.ready.value,
      isTrue,
      reason: 'consent obtained and SDK initialised',
    );
    expect(
      await waitFor(() => ads.isRewardedReady, const Duration(seconds: 60)),
      isTrue,
    );
    expect(
      await waitFor(() => ads.isInterstitialReady, const Duration(seconds: 60)),
      isTrue,
    );
    debugPrint('[services_test] rewarded + interstitial test ads loaded');
  });
}
