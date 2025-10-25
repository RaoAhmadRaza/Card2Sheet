import 'package:hive/hive.dart';
import '../models/history_item.dart';

/// Centralized schema migration runner
class MigrationService {
  static const int currentSchema = 1;
  static const String metaBoxName = 'app_meta';
  static const String schemaKey = 'schemaVersion';

  /// Run idempotent migrations and bump schema in meta box
  static Future<void> migrateIfNeeded() async {
    final meta = await _openMetaBox();
    final fromVersion = (meta.get(schemaKey) as int?) ?? 0;

    if (fromVersion >= currentSchema) {
      return; // nothing to do
    }

    // Example migration: move entries from legacy 'history' box to 'scan_history'
    if (fromVersion < 1) {
      await _migrateHistoryBoxToScanHistory();
    }

    await meta.put(schemaKey, currentSchema);
  }

  static Future<Box> _openMetaBox() async {
    return Hive.isBoxOpen(metaBoxName)
        ? Hive.box(metaBoxName)
        : await Hive.openBox(metaBoxName);
  }

  static Future<void> _migrateHistoryBoxToScanHistory() async {
    const legacyName = 'history';
    const targetName = 'scan_history';

    if (!Hive.isBoxOpen(targetName)) {
      await Hive.openBox<HistoryItem>(targetName);
    }
    final target = Hive.box<HistoryItem>(targetName);

    // If legacy doesn't exist on disk, nothing to migrate
    if (!Hive.isBoxOpen(legacyName)) {
      // Try opening if present on disk
      try {
        await Hive.openBox<HistoryItem>(legacyName);
      } catch (_) {
        return; // no legacy box
      }
    }
    if (!Hive.isBoxOpen(legacyName)) return;

    final legacy = Hive.box<HistoryItem>(legacyName);
    if (legacy.isEmpty) {
      await legacy.close();
      try { await Hive.deleteBoxFromDisk(legacyName); } catch (_) {}
      return;
    }

    // Copy entries idempotently (skip keys that already exist in target)
    for (final key in legacy.keys) {
      if (!target.containsKey(key)) {
        final value = legacy.get(key);
        if (value is HistoryItem) {
          await target.put(key, value);
        }
      }
    }

    // Attempt to delete old box from disk
    await legacy.close();
    try {
      await Hive.deleteBoxFromDisk(legacyName);
    } catch (_) {
      // ignore
    }
  }
}
