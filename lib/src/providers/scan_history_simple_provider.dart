import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:riverpod/riverpod.dart';
import 'package:hive/hive.dart';

import '../models/scan_history.dart';

/// A simple provider for a minimal ScanHistory list using Hive.
/// Note: This co-exists with the richer `historyProvider` (HistoryItem-based).
final scanHistoryProvider =
    NotifierProvider<ScanHistoryNotifier, List<ScanHistory>>(
  ScanHistoryNotifier.new,
);

class ScanHistoryNotifier extends Notifier<List<ScanHistory>> {
  Box<ScanHistory>? _box;
  StreamSubscription<BoxEvent>? _sub;

  @override
  List<ScanHistory> build() {
    Future.microtask(_init);
    // Ensure we cancel the watcher when provider is disposed
    ref.onDispose(() => _sub?.cancel());
    return const [];
  }

  Future<void> _init() async {
    _box = Hive.isBoxOpen('scanHistory')
        ? Hive.box<ScanHistory>('scanHistory')
        : await Hive.openBox<ScanHistory>('scanHistory');
    _reload();
    // Optional: react to external changes as well
    _sub = _box!.watch().listen((_) => _reload());
  }

  Future<void> _ensureBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = Hive.isBoxOpen('scanHistory')
          ? Hive.box<ScanHistory>('scanHistory')
          : await Hive.openBox<ScanHistory>('scanHistory');
    }
  }

  void _reload() {
    final items = _box!.values.toList(growable: false);
    // Newest-first ordering if desired; here we keep insertion order
    state = items;
  }

  Future<void> addHistory(ScanHistory item) async {
    await _ensureBox();
    // De-dup: if the most-recent entry matches same name+file within a few seconds, skip
    final items = _box!.values.toList(growable: false);
    if (items.isNotEmpty) {
      final last = items.last;
      final sameName = last.cardName.trim().toLowerCase() == item.cardName.trim().toLowerCase();
      final sameFile = last.filePath == item.filePath;
      final closeInTime = (item.dateTime.difference(last.dateTime).inSeconds).abs() <= 3;
      if (sameName && sameFile && closeInTime) {
        return; // likely double-tap or double-call; ignore duplicate
      }
    }
    await _box!.add(item);
    // Rely on watcher to reload; also force reload immediately to reflect UI fast
    _reload();
  }

  Future<void> clearHistory() async {
    await _box!.clear();
    state = const [];
  }

  /// Export all entries to a pretty-printed JSON file at [targetPath].
  /// Returns the written file path.
  Future<String> exportToJson(String targetPath) async {
    await _ensureBox();
    final items = _box!.values.toList(growable: false);
    final list = items
        .map((e) => {
              'cardName': e.cardName,
              'filePath': e.filePath,
              'dateTime': e.dateTime.toIso8601String(),
            })
        .toList(growable: false);
    final file = File(targetPath);
    await file.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(list));
    return file.path;
  }
}
