// YouTube Playables SDK bridge for Flutter web, using dart:js_interop.
// Only imported by lib/main_playables.dart (web-only entry point).
import 'dart:js_interop';

import 'playables_platform.dart';

@JS('ytgame')
external _YtGame? get _ytgame;

extension type _YtGame._(JSObject _) implements JSObject {
  @JS('IN_PLAYABLES_ENV')
  external bool? get inPlayablesEnv;
  external _YtGameGame get game;
  external _YtSystem get system;
  external _YtHealth? get health;
  external _YtAds? get ads;
}

extension type _YtGameGame._(JSObject _) implements JSObject {
  external void firstFrameReady();
  external void gameReady();
  external JSPromise<JSString?> loadData();
  external JSPromise<JSAny?> saveData(JSString data);
}

extension type _YtSystem._(JSObject _) implements JSObject {
  external bool isAudioEnabled();
  external JSFunction onAudioEnabledChange(JSFunction callback);
  external JSFunction onPause(JSFunction callback);
  external JSFunction onResume(JSFunction callback);
}

extension type _YtHealth._(JSObject _) implements JSObject {
  external void logError();
  external void logWarning();
}

extension type _YtAds._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> requestInterstitialAd();
  external JSPromise<JSBoolean> requestRewardedAd(JSString rewardId);
}

/// Calls into the real `ytgame` global. Every call is guarded so a missing
/// or older SDK can never crash the game.
class JsPlayablesPlatform implements PlayablesPlatform {
  JsPlayablesPlatform._(this._sdk);

  /// Returns null when the SDK script is not on the page.
  static JsPlayablesPlatform? tryCreate() {
    final sdk = _ytgame;
    return sdk == null ? null : JsPlayablesPlatform._(sdk);
  }

  final _YtGame _sdk;

  @override
  bool get inPlayablesEnv {
    try {
      return _sdk.inPlayablesEnv ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get adsAvailable {
    try {
      return inPlayablesEnv && _sdk.ads != null;
    } catch (_) {
      return false;
    }
  }

  @override
  void firstFrameReady() {
    try {
      _sdk.game.firstFrameReady();
    } catch (_) {}
  }

  @override
  void gameReady() {
    try {
      _sdk.game.gameReady();
    } catch (_) {}
  }

  @override
  Future<String> loadData() async =>
      (await _sdk.game.loadData().toDart)?.toDart ?? '';

  @override
  Future<void> saveData(String data) async {
    await _sdk.game.saveData(data.toJS).toDart;
  }

  @override
  bool isAudioEnabled() {
    try {
      return _sdk.system.isAudioEnabled();
    } catch (_) {
      return true;
    }
  }

  @override
  void onAudioEnabledChange(void Function(bool enabled) callback) {
    try {
      _sdk.system.onAudioEnabledChange(
        ((JSBoolean enabled) => callback(enabled.toDart)).toJS,
      );
    } catch (_) {}
  }

  @override
  void onPause(void Function() callback) {
    try {
      _sdk.system.onPause(callback.toJS);
    } catch (_) {}
  }

  @override
  void onResume(void Function() callback) {
    try {
      _sdk.system.onResume(callback.toJS);
    } catch (_) {}
  }

  @override
  Future<void> requestInterstitialAd() async {
    final ads = _sdk.ads;
    if (ads == null) return;
    await ads.requestInterstitialAd().toDart;
  }

  @override
  Future<bool> requestRewardedAd(String rewardId) async {
    final ads = _sdk.ads;
    if (ads == null) return false;
    return (await ads.requestRewardedAd(rewardId.toJS).toDart).toDart;
  }

  @override
  void logError() {
    try {
      _sdk.health?.logError();
    } catch (_) {}
  }

  @override
  void logWarning() {
    try {
      _sdk.health?.logWarning();
    } catch (_) {}
  }
}

/// Removes the HTML loading screen defined in web/index.html.
@JS('mindTilesHideLoader')
external JSFunction? get _hideLoader;

void hideHtmlLoader() {
  try {
    _hideLoader?.callAsFunction();
  } catch (_) {}
}
