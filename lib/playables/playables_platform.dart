/// Pure-Dart view of the YouTube Playables SDK (`ytgame`).
///
/// The real implementation (`JsPlayablesPlatform`) uses `dart:js_interop`
/// and is only compiled into the Playables web build. Tests and local runs
/// without the SDK use [LocalPlayablesPlatform].
///
/// Reference: https://developers.google.com/youtube/gaming/playables/reference/sdk
abstract class PlayablesPlatform {
  /// True when running inside YouTube Playables (`ytgame.IN_PLAYABLES_ENV`).
  bool get inPlayablesEnv;

  /// Whether the SDK's ads functions exist (YouTube app on Android/iOS).
  bool get adsAvailable;

  /// Must be called while a loading/splash screen is shown, before
  /// [gameReady]. (Called from web/index.html, before Flutter loads.)
  void firstFrameReady();

  /// Must be called once the game is interactive — never while a loading
  /// screen is still visible.
  void gameReady();

  /// Cloud save. Must complete before the first [saveData] call.
  Future<String> loadData();

  /// Saves a well-formed UTF-16 string, max 3 MiB.
  Future<void> saveData(String data);

  bool isAudioEnabled();
  void onAudioEnabledChange(void Function(bool enabled) callback);
  void onPause(void Function() callback);
  void onResume(void Function() callback);

  Future<void> requestInterstitialAd();

  /// Resolves true only if the player earned the reward.
  Future<bool> requestRewardedAd(String rewardId);

  void logError();
  void logWarning();
}

/// Used when the SDK is not present (local `flutter run -d chrome`, tests).
/// Saves are kept in memory only; audio is always enabled; no ads.
class LocalPlayablesPlatform implements PlayablesPlatform {
  LocalPlayablesPlatform({this.initialSave = ''});

  String initialSave;
  String? lastSaved;
  int saveCount = 0;
  bool firstFrameReadyCalled = false;
  bool gameReadyCalled = false;
  bool audioEnabled = true;
  void Function(bool)? _audioListener;
  void Function()? _pauseListener;
  void Function()? _resumeListener;

  @override
  bool get inPlayablesEnv => false;
  @override
  bool get adsAvailable => false;
  @override
  void firstFrameReady() => firstFrameReadyCalled = true;
  @override
  void gameReady() => gameReadyCalled = true;
  @override
  Future<String> loadData() async => initialSave;
  @override
  Future<void> saveData(String data) async {
    saveCount++;
    lastSaved = data;
  }

  @override
  bool isAudioEnabled() => audioEnabled;
  @override
  void onAudioEnabledChange(void Function(bool enabled) callback) =>
      _audioListener = callback;
  @override
  void onPause(void Function() callback) => _pauseListener = callback;
  @override
  void onResume(void Function() callback) => _resumeListener = callback;
  @override
  Future<void> requestInterstitialAd() async {}
  @override
  Future<bool> requestRewardedAd(String rewardId) async => false;
  @override
  void logError() {}
  @override
  void logWarning() {}

  // Test helpers: simulate YouTube events.
  void simulateAudio(bool enabled) {
    audioEnabled = enabled;
    _audioListener?.call(enabled);
  }

  void simulatePause() => _pauseListener?.call();
  void simulateResume() => _resumeListener?.call();
}
