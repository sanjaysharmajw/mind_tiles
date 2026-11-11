// Entry point for the YouTube Playables (web) build.
//
//   flutter build web -t lib/main_playables.dart --release --no-web-resources-cdn
//
// Differences from the mobile build (lib/main.dart), required by the
// Playables certification rules:
// * no Firebase / AdMob / notifications — no external network calls;
// * progress saved only via ytgame cloud save (PlayablesStore) inside
//   YouTube; localStorage when the same build runs on a normal website;
// * audio follows YouTube's mute (isAudioEnabled / onAudioEnabledChange);
// * pause/resume only from ytgame onPause/onResume (never page visibility);
// * ads only via ytgame.ads (PlayablesAdService);
// * firstFrameReady is called by web/index.html while the HTML loading
//   screen shows; gameReady is called here once the game is interactive.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_scope.dart';
import 'data/local_storage/key_value_store.dart';
import 'data/player_data_controller.dart';
import 'data/repositories/save_repository.dart';
import 'game/systems/audio_manager.dart';
import 'game/systems/haptics_manager.dart';
import 'playables/js_playables_platform.dart';
import 'playables/playables_ad_service.dart';
import 'playables/playables_crash_reporter.dart';
import 'playables/playables_platform.dart';
import 'playables/playables_store.dart';
import 'services/analytics/analytics_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final PlayablesPlatform platform =
      JsPlayablesPlatform.tryCreate() ?? LocalPlayablesPlatform();
  final crash = PlayablesCrashReporter(platform);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crash.recordFlutterError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crash.recordError(error, stack, fatal: true);
    return true;
  };

  // Inside YouTube Playables, progress MUST use ytgame cloud save only
  // (loaded before anything is saved). Outside YouTube — the same build
  // hosted as a normal website — progress lives in the browser's
  // localStorage so it survives a page refresh.
  PlayablesStore? cloud;
  KeyValueStore store;
  if (platform.inPlayablesEnv) {
    store = cloud = await PlayablesStore.open(platform);
  } else {
    try {
      store = await SharedPrefsStore.create();
    } catch (_) {
      store = MemoryStore();
    }
  }
  final player = await PlayerDataController.load(SaveRepository(store));

  final audio = AudioManager(AudioPlayersBackend())
    ..setPlatformAudioEnabled(platform.isAudioEnabled());
  unawaited(audio.init());

  final hostPaused = ValueNotifier<bool>(false);

  final services = AppServices(
    player: player,
    audio: audio,
    haptics: HapticsManager(),
    analytics: LocalAnalyticsService(enabled: kDebugMode),
    ads: PlayablesAdService(platform),
    crash: crash,
    flavor: AppFlavor.playables,
    hostPaused: hostPaused,
  );
  services.syncSettings();

  platform.onAudioEnabledChange(audio.setPlatformAudioEnabled);
  platform.onPause(() {
    hostPaused.value = true; // gameplay pauses + snapshots; tickers stop
    audio.setAppActive(false);
    if (cloud != null) unawaited(cloud.flush());
  });
  platform.onResume(() {
    audio.setAppActive(true);
    hostPaused.value = false;
  });

  // Browsers only allow audio after a user gesture.
  var gestureSeen = false;
  GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
    if (gestureSeen || event is! PointerDownEvent) return;
    gestureSeen = true;
    audio.retryAfterUserGesture();
  });

  runApp(MindTilesApp(services: services));

  // Once the home screen has rendered: remove the HTML loading screen, then
  // tell YouTube the game is interactive.
  await WidgetsBinding.instance.endOfFrame;
  hideHtmlLoader();
  platform.gameReady();
}
