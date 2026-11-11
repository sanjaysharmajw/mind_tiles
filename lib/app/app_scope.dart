import 'dart:math';

import 'package:flutter/widgets.dart';

import '../data/player_data_controller.dart';
import '../game/systems/audio_manager.dart';
import '../game/systems/haptics_manager.dart';
import '../services/ads/ad_service.dart';
import '../services/analytics/analytics_service.dart';
import '../services/notifications/push_service.dart';
import '../services/performance/performance_tracer.dart';

/// Which store build this is. Playables (YouTube) hides features that the
/// Playables certification rules forbid (notifications, analytics opt-in,
/// ad privacy forms) and takes pause/resume from the YouTube SDK.
enum AppFlavor { mobile, playables }

/// All app-wide services, created once in `main` (or in tests) and exposed
/// through [AppScope]. No global singletons.
class AppServices {
  AppServices({
    required this.player,
    required this.audio,
    required this.haptics,
    required this.analytics,
    required this.ads,
    required this.crash,
    this.performance = const NoopPerformanceTracer(),
    this.push = const DisabledPushService(),
    this.flavor = AppFlavor.mobile,
    ValueNotifier<bool>? hostPaused,
    Random? random,
    DateTime Function()? clock,
  }) : hostPaused = hostPaused ?? ValueNotifier(false),
       random = random ?? Random(),
       clock = clock ?? DateTime.now;

  final PlayerDataController player;
  final AudioManager audio;
  final HapticsManager haptics;
  final AnalyticsService analytics;
  final AdService ads;
  final CrashReporter crash;
  final PerformanceTracer performance;
  final PushService push;
  final AppFlavor flavor;

  /// True while the host (YouTube Playables onPause) has paused the game.
  /// Mobile builds use the OS app lifecycle instead and leave this false.
  final ValueNotifier<bool> hostPaused;

  bool get isPlayables => flavor == AppFlavor.playables;
  final Random random;
  final DateTime Function() clock;

  bool? _analyticsApplied;

  /// Pushes current settings into audio, haptics and data collection.
  void syncSettings() {
    final s = player.settings;
    audio.apply(soundOn: s.soundOn, musicOn: s.musicOn);
    haptics.enabled = s.hapticsOn;
    if (_analyticsApplied != s.analyticsOn) {
      _analyticsApplied = s.analyticsOn;
      analytics.setEnabled(s.analyticsOn);
      crash.setEnabled(s.analyticsOn);
      performance.setEnabled(s.analyticsOn);
    }
  }

  /// Turns daily reminders on (asking for OS permission) or off.
  /// Returns the resulting state: false if permission was denied.
  Future<bool> setNotifications(bool on) async {
    final granted = on ? await push.enable() : false;
    if (!on) await push.disable();
    player.updateSettings(player.settings.copyWith(notificationsOn: granted));
    return granted;
  }

  /// Standard feedback for UI buttons.
  void buttonFeedback() {
    audio.play(Sfx.button);
    haptics.trigger(HapticKind.selection);
  }

  /// Reduced motion if the player asked for it or the OS requests it.
  bool reducedMotion(BuildContext context) =>
      player.settings.reducedMotion ||
      MediaQuery.maybeDisableAnimationsOf(context) == true;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing from widget tree');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
