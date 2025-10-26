import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:riverpod/riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../utils/async_mutex.dart';
import '../utils/retry.dart';
import '../services/analytics_service.dart';

import '../models/history_item.dart';
import '../models/scan_result.dart';
import '../models/sheet_destination.dart';
import 'sheet_provider.dart';
import 'session_provider.dart';

const _historyBoxName = 'scan_history';

final historyProvider = NotifierProvider<HistoryNotifier, List<HistoryItem>>(
  HistoryNotifier.new,
);

class HistoryNotifier extends Notifier<List<HistoryItem>> {
  final _lock = AsyncMutex();
  @override
  List<HistoryItem> build() {
    // Hydrate from Hive
    Future.microtask(_loadFromHive);
    return const [];
  }

  Box<HistoryItem>? _box;
  final _uuid = const Uuid();

  Future<void> _ensureBox() async {
    _box ??= Hive.isBoxOpen(_historyBoxName)
        ? Hive.box<HistoryItem>(_historyBoxName)
        : await Hive.openBox<HistoryItem>(_historyBoxName);
  }

  Future<void> _loadFromHive() async {
    await _ensureBox();
    final items = _box!.values.toList(growable: false);
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = items;
  }

  Future<void> _write(HistoryItem item) async {
    await _lock.run(() async {
      await _ensureBox();
      await retry(() => _box!.put(item.id, item));
    });
  }

  String _signatureOf(Map<String, String> structured) {
    // Build a stable signature independent of key order and trivial whitespace
    final entries = structured.entries
        .map((e) => MapEntry(e.key.trim().toLowerCase(), (e.value).trim()))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}=${e.value}').join('|');
  }

  Future<void> addFromScan(ScanResult result) async {
    // Determine destination from current sheet selection or fallback to session
    final sheet = ref.read(sheetProvider);
    SheetDestination? dest = sheet.toDestination();
    dest ??= ref.read(sessionProvider).lastDestination;

    dest ??= SheetDestination(type: SheetType.csv, path: '');
    final now = DateTime.now();

    // De-dupe: if the most recent item has the same structured data and destination
    // within a short window, update it instead of adding a new entry.
    if (state.isNotEmpty) {
      final latest = state.first;
      final sameStruct = _signatureOf(latest.structured) == _signatureOf(result.structured);
      final sameDest = latest.destination.type == dest.type &&
          (latest.destination.path == dest.path) &&
          (latest.destination.sheetName == dest.sheetName);
      final withinWindow = now.difference(latest.timestamp).inSeconds.abs() <= 15;

      if (sameStruct && withinWindow) {
        // Prefer updating destination if the new one is more specific (non-empty path)
        final updated = latest.copyWith(
          destination: sameDest ? latest.destination : dest,
          timestamp: now,
        );
        // Persist update
        await _write(updated);
        // Update state in-place
        final next = [...state];
        next[0] = updated;
        state = next;
        return;
      }
    }

    final item = HistoryItem(
      id: _uuid.v4(),
      structured: result.structured,
      destination: dest,
      rowIndex: -1,
      timestamp: now,
    );
    // Optimistic UI update
    final prev = state;
    state = [item, ...state];
    try {
      await _write(item);
    } catch (e) {
      // Rollback on failure
      state = prev;
      rethrow;
    }
  }

  Future<void> deleteAt(int index) async {
    if (index < 0 || index >= state.length) return;
    final item = state[index];
    await _lock.run(() async {
      await _ensureBox();
      await retry(() => _box!.delete(item.id));
    });
    final next = [...state];
    next.removeAt(index);
    state = next;
  }

  Future<void> deleteById(String id) async {
    await _lock.run(() async {
      await _ensureBox();
      await retry(() => _box!.delete(id));
    });
    state = state.where((e) => e.id != id).toList(growable: false);
  }

  Future<void> clearAll() async {
    await _lock.run(() async {
      await _ensureBox();
      await retry(() => _box!.clear());
    });
    state = const [];
    // Fire analytics (no PII)
    ref.read(analyticsProvider).track('history_cleared');
  }

  /// Optional helper to export history to a file (CSV/XLSX)
  /// Returns a file path or null if not implemented.
  Future<String?> export() async {
    // TODO: Implement if needed by UI
    return null;
  }

  /// Export full history into JSON lines file; returns written file path.
  Future<String> exportToJson(String targetPath) async {
    await _ensureBox();
    final items = state;
    final jsonList = items.map((e) => e.toJson()).toList();
    final file = File(targetPath);
    await file.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
    return file.path;
  }

  /// Export history into CSV (values-only, flattening structured map by headers union)
  Future<String> exportToCsv(String targetPath) async {
    await _ensureBox();
    final items = state;
    // Build union of all keys as headers
    final headers = <String>{};
    for (final it in items) {
      headers.addAll(it.structured.keys);
    }
    final ordered = headers.toList();
    final rows = <List<dynamic>>[];
    rows.add(ordered); // header row for backup/export only
    for (final it in items) {
      rows.add(ordered.map((k) => it.structured[k] ?? '').toList());
    }
    final csv = const ListToCsvConverter().convert(rows);
    final file = File(targetPath);
    await file.create(recursive: true);
    await file.writeAsString(csv);
    return file.path;
  }

  /// Import a JSON backup and merge; returns number of items added.
  Future<int> importFromJson(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) return 0;
    final text = await file.readAsString();
    final list = (jsonDecode(text) as List).cast<Map>();
    int added = 0;
    await _lock.run(() async {
      await _ensureBox();
      final currentIds = state.map((e) => e.id).toSet();
      final next = [...state];
      for (final raw in list) {
        final map = Map<String, dynamic>.from(raw);
        final item = HistoryItem.fromJson(map);
        if (!currentIds.contains(item.id)) {
          await _box!.put(item.id, item);
          next.add(item);
          currentIds.add(item.id);
          added++;
        }
      }
      // Keep sorted newest-first
      next.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = next;
    });
    return added;
  }

  /// Purge history entries older than the provided maxAge. Returns count removed.
  Future<int> purgeOlderThan(Duration maxAge) async {
    final cutoff = DateTime.now().subtract(maxAge);
    int removed = 0;
    await _lock.run(() async {
      await _ensureBox();
      final toRemove = state.where((e) => e.timestamp.isBefore(cutoff)).toList();
      if (toRemove.isEmpty) return;
      for (final it in toRemove) {
        await _box!.delete(it.id);
      }
      removed = toRemove.length;
      final next = state.where((e) => !e.timestamp.isBefore(cutoff)).toList(growable: false);
      state = next;
    });
    if (removed > 0) {
      ref.read(analyticsProvider).track('history_purged', props: {'removed': removed});
    }
    return removed;
  }

  /// Keep only the most recent [keep] items; delete the rest. Returns count removed.
  Future<int> purgeKeepingMostRecent(int keep) async {
    if (keep < 0) keep = 0;
    int removed = 0;
    await _lock.run(() async {
      await _ensureBox();
      if (state.length <= keep) return;
      final sorted = [...state]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final toRemove = sorted.skip(keep).toList();
      for (final it in toRemove) {
        await _box!.delete(it.id);
      }
      removed = toRemove.length;
      state = sorted.take(keep).toList(growable: false);
    });
    if (removed > 0) {
      ref.read(analyticsProvider).track('history_trimmed', props: {'removed': removed});
    }
    return removed;
  }
}
