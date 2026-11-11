import 'package:flutter/widgets.dart';

import '../services/ads/ad_service.dart';
import 'playables_platform.dart';

/// Ads through the YouTube Playables SDK (`ytgame.ads`). Off-platform ad
/// SDKs such as AdMob are not allowed in Playables (Monetization 2c).
///
/// * Interstitial: only when leaving the results screen (a natural transition
///   between content screens, never during play — Monetization 2.2), and
///   further limited by [InterstitialPolicy].
/// * Rewarded: only from the player's explicit tap on the "AD" hint button,
///   never automatic, never blocking progress (Monetization 2.1).
/// * No banners (YouTube provides pre-roll automatically).
class PlayablesAdService extends AdService {
  PlayablesAdService(
    this._platform, {
    AdsConfig config = const AdsConfig(enabled: true),
  }) : _policy = InterstitialPolicy(config);

  /// Stable, non-personal reward identifier required by requestRewardedAd.
  static const String hintRewardId = 'mind_tiles_extra_hint';

  final PlayablesPlatform _platform;
  final InterstitialPolicy _policy;

  @override
  bool get enabled => _platform.adsAvailable;

  @override
  Future<void> initialize() async {}

  @override
  bool get isRewardedReady => _platform.adsAvailable;

  @override
  Future<RewardOutcome> showRewarded() async {
    if (!_platform.adsAvailable) return RewardOutcome.unavailable;
    try {
      final earned = await _platform.requestRewardedAd(hintRewardId);
      return earned ? RewardOutcome.rewarded : RewardOutcome.dismissed;
    } catch (_) {
      return RewardOutcome.failed;
    }
  }

  @override
  void onGameFinished() => _policy.onGameFinished();

  @override
  Future<bool> maybeShowInterstitial() async {
    final now = DateTime.now();
    if (!_platform.adsAvailable || !_policy.shouldShow(now)) return false;
    _policy.markShown(now);
    try {
      // The SDK does not report whether an ad was actually shown.
      await _platform.requestInterstitialAd();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget banner() => const SizedBox.shrink();
}
