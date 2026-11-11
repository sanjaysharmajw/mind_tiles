import 'package:flutter/services.dart';

enum HapticKind { tap, match, mismatch, success, failure, selection }

/// Thin wrapper over Flutter's built-in [HapticFeedback] (no plugin needed).
/// Devices without haptics simply ignore the calls.
class HapticsManager {
  HapticsManager({Future<void> Function(HapticKind kind)? performer})
    : _performer = performer ?? _platform;

  final Future<void> Function(HapticKind kind) _performer;
  bool enabled = true;

  void trigger(HapticKind kind) {
    if (!enabled) return;
    _performer(kind).catchError((_) {});
  }

  static Future<void> _platform(HapticKind kind) => switch (kind) {
    HapticKind.tap => HapticFeedback.lightImpact(),
    HapticKind.selection => HapticFeedback.selectionClick(),
    HapticKind.match => HapticFeedback.mediumImpact(),
    HapticKind.mismatch => HapticFeedback.heavyImpact(),
    HapticKind.success => HapticFeedback.heavyImpact(),
    HapticKind.failure => HapticFeedback.vibrate(),
  };
}
