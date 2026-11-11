import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

/// Ad unit IDs. Defaults are Google's public TEST units, which always fill
/// and are safe to click. Supply real IDs only for release builds:
///
///   flutter build appbundle --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-xxx/yyy \
///     --dart-define=ADMOB_INTERSTITIAL_ANDROID=... --dart-define=ADMOB_REWARDED_ANDROID=...
///
/// (and the *_IOS variants for `flutter build ipa`). The App IDs live in
/// android/gradle.properties (admobAppId) and ios/Flutter/AppConfig.xcconfig.
class AdUnitIds {
  const AdUnitIds({
    required this.banner,
    required this.interstitial,
    required this.rewarded,
  });

  final String banner;
  final String interstitial;
  final String rewarded;

  static const _bannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const _interstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const _rewardedAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const _bannerIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );
  static const _interstitialIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );
  static const _rewardedIos = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  static AdUnitIds forPlatform() => Platform.isIOS
      ? const AdUnitIds(
          banner: _bannerIos,
          interstitial: _interstitialIos,
          rewarded: _rewardedIos,
        )
      : const AdUnitIds(
          banner: _bannerAndroid,
          interstitial: _interstitialAndroid,
          rewarded: _rewardedAndroid,
        );

  bool get isTest => banner.startsWith('ca-app-pub-3940256099942544/');
}

/// Google AdMob implementation of [AdService], with UMP consent.
///
/// * Consent is gathered before any ad request; if consent cannot be
///   obtained, no ads are requested and the game continues normally.
/// * Interstitials only at natural breaks, gated by [InterstitialPolicy].
/// * Rewards only from the SDK's verified `onUserEarnedReward` callback.
/// * Every load/show failure degrades to "no ad".
class AdMobAdService extends AdService {
  AdMobAdService({this.config = const AdsConfig(enabled: true), AdUnitIds? ids})
    : ids = ids ?? AdUnitIds.forPlatform(),
      _policy = InterstitialPolicy(config);

  final AdsConfig config;
  final AdUnitIds ids;
  final InterstitialPolicy _policy;
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  bool _canRequest = false;
  bool _initialised = false;
  int _rewardedRetry = 0;
  int _interstitialRetry = 0;

  /// Rebuilds banners once ads become available after consent.
  final ValueNotifier<bool> ready = ValueNotifier(false);

  @override
  bool get enabled => config.enabled;

  @override
  Future<void> initialize() async {
    if (!config.enabled || _initialised) return;
    _initialised = true;
    try {
      await _gatherConsent();
      _canRequest = await ConsentInformation.instance.canRequestAds();
      if (!_canRequest) return;
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          // Family-friendly puzzle game: only G-rated ad content.
          maxAdContentRating: MaxAdContentRating.g,
        ),
      );
      await MobileAds.instance.initialize();
      ready.value = true;
      _loadRewarded();
      _loadInterstitial();
    } catch (e) {
      debugPrint('AdMob init failed (game continues without ads): $e');
    }
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error != null) debugPrint('Consent form: ${error.message}');
        if (!done.isCompleted) done.complete();
      }),
      (error) {
        debugPrint('Consent info update failed: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
  }

  /// Exponential back-off on load failures (max ~64 s) so a no-fill or
  /// offline period never turns into a request loop.
  Duration _backoff(int attempt) => Duration(seconds: 1 << attempt.clamp(1, 6));

  void _loadRewarded() {
    if (!_canRequest) return;
    RewardedAd.load(
      adUnitId: ids.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedRetry = 0;
          _rewarded = ad;
        },
        onAdFailedToLoad: (error) {
          _rewarded = null; // the hint button hides the "AD" option
          debugPrint('Rewarded load failed: ${error.message}');
          Future.delayed(_backoff(++_rewardedRetry), _loadRewarded);
        },
      ),
    );
  }

  void _loadInterstitial() {
    if (!_canRequest) return;
    InterstitialAd.load(
      adUnitId: ids.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialRetry = 0;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitial = null;
          debugPrint('Interstitial load failed: ${error.message}');
          Future.delayed(_backoff(++_interstitialRetry), _loadInterstitial);
        },
      ),
    );
  }

  @override
  bool get isRewardedReady => _canRequest && _rewarded != null;

  /// Whether an interstitial is loaded (used by on-device tests).
  bool get isInterstitialReady => _canRequest && _interstitial != null;

  @override
  Future<RewardOutcome> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) return RewardOutcome.unavailable;
    _rewarded = null;
    final result = Completer<RewardOutcome>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
        if (!result.isCompleted) {
          result.complete(
            earned ? RewardOutcome.rewarded : RewardOutcome.dismissed,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewarded();
        if (!result.isCompleted) result.complete(RewardOutcome.failed);
      },
    );
    try {
      // The reward is granted ONLY through this verified SDK callback.
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
    } catch (e) {
      if (!result.isCompleted) result.complete(RewardOutcome.failed);
    }
    return result.future;
  }

  @override
  void onGameFinished() => _policy.onGameFinished();

  @override
  Future<bool> maybeShowInterstitial() async {
    final ad = _interstitial;
    final now = DateTime.now();
    if (ad == null || !_policy.shouldShow(now)) return false;
    _interstitial = null;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
        if (!done.isCompleted) done.complete(false);
      },
    );
    _policy.markShown(now);
    try {
      await ad.show();
    } catch (_) {
      if (!done.isCompleted) done.complete(false);
    }
    return done.future;
  }

  @override
  Widget banner() => ValueListenableBuilder<bool>(
    valueListenable: ready,
    builder: (context, isReady, _) => isReady
        ? _AdaptiveBanner(adUnitId: ids.banner)
        : const SizedBox.shrink(),
  );

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) debugPrint('Privacy options: ${error.message}');
      });
      _canRequest = await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('Privacy options failed: $e');
    }
  }
}

/// Anchored adaptive banner sized to the available width. Collapses to
/// nothing until (and unless) an ad loads, so it never covers controls.
class _AdaptiveBanner extends StatefulWidget {
  const _AdaptiveBanner({required this.adUnitId});
  final String adUnitId;

  @override
  State<_AdaptiveBanner> createState() => _AdaptiveBannerState();
}

class _AdaptiveBannerState extends State<_AdaptiveBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width != _width) {
      _width = width;
      _load(width);
    }
  }

  Future<void> _load(int width) async {
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) return;
    await _ad?.dispose();
    _loaded = false;
    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    setState(() => _ad = ad);
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
