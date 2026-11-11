import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/app_scope.dart';
import 'data/local_storage/key_value_store.dart';
import 'data/player_data_controller.dart';
import 'data/repositories/save_repository.dart';
import 'game/systems/audio_manager.dart';
import 'game/systems/haptics_manager.dart';
import 'services/ads/ad_service.dart';
import 'services/ads/admob_ad_service.dart';
import 'services/analytics/analytics_service.dart';
import 'services/firebase/firebase_services.dart';
import 'services/notifications/fcm_push_service.dart';
import 'services/notifications/push_service.dart';
import 'services/performance/performance_tracer.dart';

/// Master switch for ads. Set to false to ship an ad-free build.
const bool kAdsEnabled = true;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase first, so crashes during startup are reported. If it fails
  // (only on misconfiguration — being offline is fine), the game falls back
  // to local services and stays fully playable.
  final firebaseReady = await initializeFirebase();

  final CrashReporter crash = firebaseReady
      ? CrashlyticsReporter()
      : DebugCrashReporter();
  final AnalyticsService analytics = firebaseReady
      ? FirebaseAnalyticsService()
      : LocalAnalyticsService();
  final PerformanceTracer performance = firebaseReady
      ? FirebasePerformanceTracer()
      : const NoopPerformanceTracer();
  final PushService push = firebaseReady
      ? FcmPushService()
      : const DisabledPushService();
  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crash.recordFlutterError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crash.recordError(error, stack, fatal: true);
    return true;
  };

  final startupTrace = performance.start('app_bootstrap');

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  KeyValueStore store;
  try {
    store = await SharedPrefsStore.create();
  } catch (e) {
    // Storage unavailable: keep playing with an in-memory save.
    crash.recordError(e, null);
    store = MemoryStore();
  }
  final player = await PlayerDataController.load(SaveRepository(store));

  final audio = AudioManager(AudioPlayersBackend());
  unawaited(audio.init());

  final AdService ads = kAdsEnabled
      ? AdMobAdService()
      : const DisabledAdService();

  final services = AppServices(
    player: player,
    audio: audio,
    haptics: HapticsManager(),
    analytics: analytics,
    ads: ads,
    crash: crash,
    performance: performance,
    push: push,
  );
  services.syncSettings();

  runApp(MindTilesApp(services: services));
  unawaited(startupTrace.stop());

  // After the first frame: consent form + ads, and push listeners. Neither
  // blocks gameplay; failures leave the game ad-free / notification-free.
  unawaited(ads.initialize());
  unawaited(
    push.initialize().then((_) async {
      // Re-subscribe returning players who opted in (no prompt if granted).
      if (player.settings.notificationsOn) await push.enable();
    }),
  );
  analytics.log(AnalyticsEvent.gameStarted);
}
