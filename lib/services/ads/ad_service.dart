import 'package:flutter/widgets.dart';

/// Central monetization switches. Ads are OFF by default; see
/// docs/MONETIZATION.md for enabling AdMob with real identifiers.
class AdsConfig {
  const AdsConfig({
    this.enabled = false,
    this.interstitialEveryNGames = 3,
    this.minGamesBeforeFirstInterstitial = 3,
    this.minSecondsBetweenInterstitials = 180,
  });

  final bool enabled;
  final int interstitialEveryNGames;
  final int minGamesBeforeFirstInterstitial;
  final int minSecondsBetweenInterstitials;

  static const AdsConfig current = AdsConfig();
}

/// Decides when an interstitial may be shown. Interstitials are only ever
/// requested at natural breaks (leaving the results screen), never during
/// play. Pure and unit-tested.
class InterstitialPolicy {
  InterstitialPolicy(this.config);

  final AdsConfig config;
  int _gamesFinished = 0;
  DateTime? _lastShown;

  void onGameFinished() => _gamesFinished++;

  bool shouldShow(DateTime now) {
    if (!config.enabled) return false;
    if (_gamesFinished < config.minGamesBeforeFirstInterstitial) return false;
    if (config.interstitialEveryNGames <= 0 ||
        _gamesFinished % config.interstitialEveryNGames != 0) {
      return false;
    }
    final last = _lastShown;
    if (last != null &&
        now.difference(last).inSeconds <
            config.minSecondsBetweenInterstitials) {
      return false;
    }
    return true;
  }

  void markShown(DateTime now) => _lastShown = now;
}

enum RewardOutcome { rewarded, dismissed, unavailable, failed }

/// Ad provider abstraction. Game code never talks to an ad SDK directly.
abstract class AdService {
  const AdService();

  bool get enabled;

  Future<void> initialize();

  /// Whether a rewarded ad is loaded and can be offered right now. UI must
  /// hide reward buttons when this is false.
  bool get isRewardedReady;

  /// Shows a rewarded ad. Returns [RewardOutcome.rewarded] only after the
  /// SDK's verified reward callback fired.
  Future<RewardOutcome> showRewarded();

  /// Called at natural breaks; shows an interstitial only if policy allows.
  Future<bool> maybeShowInterstitial();

  void onGameFinished();

  /// Banner for non-gameplay screens; empty when ads are unavailable.
  Widget banner();

  /// Whether regulations require a "privacy options" entry point (UMP).
  Future<bool> isPrivacyOptionsRequired() async => false;

  /// Re-opens the consent form so the player can change their choice.
  Future<void> showPrivacyOptions() async {}
}

/// Default: no ads. Core gameplay never depends on ads.
class DisabledAdService extends AdService {
  const DisabledAdService();

  @override
  bool get enabled => false;
  @override
  Future<void> initialize() async {}
  @override
  bool get isRewardedReady => false;
  @override
  Future<RewardOutcome> showRewarded() async => RewardOutcome.unavailable;
  @override
  Future<bool> maybeShowInterstitial() async => false;
  @override
  void onGameFinished() {}
  @override
  Widget banner() => const SizedBox.shrink();
}
