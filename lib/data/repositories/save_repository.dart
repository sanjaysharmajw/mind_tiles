import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/save_data.dart';
import '../local_storage/key_value_store.dart';

/// Upgrades a raw save document from version N to N+1.
typedef SaveMigration =
    Map<String, Object?> Function(Map<String, Object?> json);

class SaveLoadResult {
  const SaveLoadResult(
    this.data, {
    this.recoveredFromCorruption = false,
    this.migratedFrom,
  });
  final SaveData data;

  /// True if the stored document could not be parsed and defaults were used.
  final bool recoveredFromCorruption;

  /// Original version when a migration ran.
  final int? migratedFrom;
}

/// Loads and saves [SaveData] as a single versioned JSON document.
///
/// Migration strategy:
/// * Every document stores `version`.
/// * On load, migrations `migrations[v]` (v → v+1) run in order until the
///   document reaches [SaveData.currentVersion].
/// * Unknown/missing fields fall back to defaults (tolerant parsing), so
///   adding optional fields never needs a migration.
/// * Corrupted documents are copied to [backupKey] (for support/debugging)
///   and the game starts with fresh defaults instead of crashing.
class SaveRepository {
  SaveRepository(this.store, {Map<int, SaveMigration>? migrations})
    : migrations = migrations ?? defaultMigrations;

  static const String key = 'mind_tiles.save';
  static const String backupKey = 'mind_tiles.save.corrupt_backup';

  /// Real migrations for shipped schema changes go here, keyed by the
  /// version they upgrade *from*. Schema v1 is the first released format.
  static const Map<int, SaveMigration> defaultMigrations = {};

  final KeyValueStore store;
  final Map<int, SaveMigration> migrations;
  Future<void> _writeChain = Future.value();

  Future<SaveLoadResult> load() async {
    String? raw;
    try {
      raw = await store.getString(key);
    } catch (e) {
      debugPrint('SaveRepository: read failed: $e');
      return SaveLoadResult(SaveData());
    }
    if (raw == null || raw.isEmpty) return SaveLoadResult(SaveData());
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('save root is not an object');
      }
      var json = Map<String, Object?>.from(decoded);
      final version = json['version'] is int ? json['version'] as int : 0;
      int? migratedFrom;
      if (version < SaveData.currentVersion) {
        migratedFrom = version;
        json = migrate(
          json,
          from: version,
          to: SaveData.currentVersion,
          migrations: migrations,
        );
      }
      return SaveLoadResult(
        SaveData.fromJson(json),
        migratedFrom: migratedFrom,
      );
    } catch (e) {
      debugPrint('SaveRepository: corrupt save, starting fresh: $e');
      try {
        await store.setString(backupKey, raw);
      } catch (_) {}
      return SaveLoadResult(SaveData(), recoveredFromCorruption: true);
    }
  }

  /// Applies migrations from [from] up to [to]. Missing steps are skipped
  /// (tolerant parsing handles additive changes).
  static Map<String, Object?> migrate(
    Map<String, Object?> json, {
    required int from,
    required int to,
    required Map<int, SaveMigration> migrations,
  }) {
    var current = json;
    for (var v = from; v < to; v++) {
      final step = migrations[v];
      if (step != null) current = step(Map<String, Object?>.from(current));
      current['version'] = v + 1;
    }
    return current;
  }

  /// Queues a write. Writes are serialized so an older state can never
  /// overwrite a newer one.
  Future<void> save(SaveData data) {
    final encoded = jsonEncode(data.toJson());
    _writeChain = _writeChain.then((_) async {
      try {
        await store.setString(key, encoded);
      } catch (e) {
        debugPrint('SaveRepository: write failed: $e');
      }
    });
    return _writeChain;
  }

  Future<void> flush() => _writeChain;
}
