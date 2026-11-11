import 'package:flutter_test/flutter_test.dart';
import 'package:mind_tiles_game/models/settings.dart';
import 'package:mind_tiles_game/services/ads/admob_ad_service.dart';
import 'package:mind_tiles_game/services/analytics/analytics_service.dart';
import 'package:mind_tiles_game/services/firebase/firebase_services.dart';
import 'package:mind_tiles_game/services/notifications/push_service.dart';
import 'package:mind_tiles_game/services/performance/performance_tracer.dart';

import '../helpers.dart';

class RecordingAnalytics extends LocalAnalyticsService {
  final List<bool> enabledCalls = [];
  @override
  void setEnabled(bool enabled) {
    enabledCalls.add(enabled);
    super.setEnabled(enabled);
  }
}

class RecordingCrash extends DebugCrashReporter {
  final List<bool> enabledCalls = [];
  @override
  void setEnabled(bool enabled) => enabledCalls.add(enabled);
}

class RecordingTracer extends PerformanceTracer {
  final List<(String, Map<String, String>, NoopTrace)> traces = [];
  final List<bool> enabledCalls = [];
  @override
  PerfTrace start(String name, {Map<String, String> attributes = const {}}) {
    final t = NoopTrace();
    traces.add((name, attributes, t));
    return t;
  }

  @override
  void setEnabled(bool enabled) => enabledCalls.add(enabled);
}

class FakePush extends PushService {
  FakePush({required this.grant});
  final bool grant;
  int enables = 0;
  int disables = 0;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> enable() async {
    enables++;
    return grant;
  }

  @override
  Future<void> disable() async => disables++;
  @override
  set onOpen(void Function(PushTarget target)? callback) {}
}

void main() {
  group('Firebase analytics mapping', () {
    test('event names are snake_case and within Firebase rules', () {
      final re = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
      for (final e in AnalyticsEvent.values) {
        expect(firebaseEventName(e), matches(re), reason: e.name);
      }
      expect(
        firebaseEventName(AnalyticsEvent.levelCompleted),
        'level_completed',
      );
    });

    test('params are converted to String/num only, long strings truncated', () {
      final p = firebaseParams({
        'a': true,
        'b': 3,
        'c': 2.5,
        'd': 'x' * 150,
        'e': false,
      });
      expect(p['a'], 1);
      expect(p['e'], 0);
      expect(p['b'], 3);
      expect(p['c'], 2.5);
      expect((p['d']! as String).length, 100);
    });
  });

  group('AdMob configuration', () {
    test('defaults to Google test ad units (never production IDs in dev)', () {
      const ids = AdUnitIds(
        banner: 'ca-app-pub-3940256099942544/6300978111',
        interstitial: 'ca-app-pub-3940256099942544/1033173712',
        rewarded: 'ca-app-pub-3940256099942544/5224354917',
      );
      expect(ids.isTest, isTrue);
      expect(
        AdUnitIds.forPlatform().isTest,
        isTrue,
        reason: 'no --dart-define given in tests → test IDs',
      );
    });
  });

  group('Settings', () {
    test('notifications default off, analytics default on, both persisted', () {
      const d = GameSettings();
      expect(d.notificationsOn, isFalse);
      expect(d.analyticsOn, isTrue);
      final s = d.copyWith(notificationsOn: true, analyticsOn: false);
      final back = GameSettings.fromJson(s.toJson());
      expect(back, s);
      expect(
        GameSettings.fromJson({'notificationsOn': 'yes'}).notificationsOn,
        isFalse,
      );
    });
  });

  group('AppServices data-collection consent', () {
    test(
      'turning analytics off disables analytics, crash and performance',
      () async {
        final h = await TestHarness.create();
        final analytics = RecordingAnalytics();
        final crash = RecordingCrash();
        final tracer = RecordingTracer();
        final services = h.withServices(
          analytics: analytics,
          crash: crash,
          performance: tracer,
        );
        services.syncSettings();
        expect(analytics.enabledCalls, [true]);
        services.player.updateSettings(
          services.player.settings.copyWith(analyticsOn: false),
        );
        services.syncSettings();
        expect(analytics.enabledCalls.last, isFalse);
        expect(crash.enabledCalls.last, isFalse);
        expect(tracer.enabledCalls.last, isFalse);
        analytics.log(AnalyticsEvent.levelStarted);
        expect(
          analytics.entries,
          isEmpty,
          reason: 'nothing logged after opt-out',
        );
        // Re-sync with no change does not spam the SDKs.
        services.syncSettings();
        expect(analytics.enabledCalls.length, 2);
      },
    );
  });

  group('Notifications opt-in', () {
    test(
      'granted permission turns the setting on; turning off unsubscribes',
      () async {
        final h = await TestHarness.create();
        final push = FakePush(grant: true);
        final services = h.withServices(push: push);
        expect(await services.setNotifications(true), isTrue);
        expect(services.player.settings.notificationsOn, isTrue);
        expect(push.enables, 1);
        expect(await services.setNotifications(false), isFalse);
        expect(services.player.settings.notificationsOn, isFalse);
        expect(push.disables, 1);
      },
    );

    test('denied permission leaves the setting off', () async {
      final h = await TestHarness.create();
      final services = h.withServices(push: FakePush(grant: false));
      expect(await services.setNotifications(true), isFalse);
      expect(services.player.settings.notificationsOn, isFalse);
    });
  });
}
