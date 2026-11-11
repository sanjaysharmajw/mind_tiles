import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/local_storage/key_value_store.dart';
import 'playables_platform.dart';

/// [KeyValueStore] backed by YouTube Playables cloud save
/// (`ytgame.game.loadData` / `saveData`).
///
/// Certification rules implemented here:
/// * loadData must succeed before any saveData (Integration 4c).
/// * No other storage mechanism is used (Integration 4b).
/// * Saved data must stay below 3 MiB (Stability 4; we warn at 500 KiB).
/// * Older save formats must keep loading (4d) — the payload is a plain
///   JSON object of string keys → string values, and the game data inside it
///   is versioned by SaveRepository.
///
/// If the initial load fails, saves are attempted again only after a later
/// load succeeds; if that load returns existing progress, this session does
/// not overwrite it.
class PlayablesStore implements KeyValueStore {
  PlayablesStore._(this._platform, this._data, this._loaded);

  static const int maxSaveBytes = 3 * 1024 * 1024;
  static const int recommendedSaveBytes = 500 * 1024;

  final PlayablesPlatform _platform;
  final Map<String, String> _data;
  bool _loaded;
  bool _protectRemote = false;
  Future<void> _chain = Future.value();

  /// Whether cloud save was loaded successfully (so saving is allowed).
  bool get loaded => _loaded;

  static Future<PlayablesStore> open(
    PlayablesPlatform platform, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final raw = await platform.loadData().timeout(timeout);
      return PlayablesStore._(platform, decode(raw), true);
    } catch (e) {
      debugPrint('Playables loadData failed: $e');
      platform.logWarning();
      return PlayablesStore._(platform, {}, false);
    }
  }

  /// Parses the cloud payload. Empty or unreadable data → empty map.
  @visibleForTesting
  static Map<String, String> decode(String raw) {
    if (raw.trim().isEmpty) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      return {
        for (final e in json.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<String?> getString(String key) async => _data[key];

  @override
  Future<void> setString(String key, String value) {
    _data[key] = value;
    return _queueFlush();
  }

  @override
  Future<void> remove(String key) {
    _data.remove(key);
    return _queueFlush();
  }

  /// Saves immediately (used on onPause, where only a short window exists).
  Future<void> flush() => _queueFlush();

  Future<void> _queueFlush() {
    _chain = _chain.then((_) => _flush());
    return _chain;
  }

  Future<void> _flush() async {
    if (_protectRemote) return;
    if (!_loaded) {
      try {
        final remote = decode(await _platform.loadData());
        _loaded = true;
        if (remote.isNotEmpty) {
          // Existing cloud progress we never saw: never overwrite it.
          _protectRemote = true;
          debugPrint(
            'Playables: cloud save exists; not overwriting this session',
          );
          return;
        }
      } catch (_) {
        return; // still unavailable; try again on the next change
      }
    }
    final payload = jsonEncode(_data);
    final bytes = payload.length * 2; // UTF-16 code units
    if (bytes > maxSaveBytes) {
      debugPrint('Playables: save too large ($bytes bytes), skipped');
      _platform.logError();
      return;
    }
    if (bytes > recommendedSaveBytes) _platform.logWarning();
    try {
      await _platform.saveData(payload);
    } catch (e) {
      debugPrint('Playables saveData failed: $e');
      _platform.logWarning();
    }
  }
}
