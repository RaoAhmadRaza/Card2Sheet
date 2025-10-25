import 'package:riverpod/riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/history_item.dart';
import '../models/scan_result.dart';
import '../models/sheet_destination.dart';
import 'sheet_provider.dart';
import 'session_provider.dart';

const _historyBoxName = 'history';

final historyProvider = NotifierProvider<HistoryNotifier, List<HistoryItem>>(
  HistoryNotifier.new,
);

class HistoryNotifier extends Notifier<List<HistoryItem>> {
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
    await _ensureBox();
    await _box!.put(item.id, item);
  }

  Future<void> addFromScan(ScanResult result) async {
    // Determine destination from current sheet selection or fallback to session
    final sheet = ref.read(sheetProvider);
    SheetDestination? dest = sheet.toDestination();
    dest ??= ref.read(sessionProvider).lastDestination;

    dest ??= SheetDestination(type: SheetType.csv, path: '');

    final item = HistoryItem(
      id: _uuid.v4(),
      structured: result.structured,
      destination: dest,
      rowIndex: -1,
      timestamp: DateTime.now(),
    );
    await _write(item);
    // Prepend to state
    state = [item, ...state];
  }

  Future<void> deleteAt(int index) async {
    if (index < 0 || index >= state.length) return;
    final item = state[index];
    await _ensureBox();
    await _box!.delete(item.id);
    final next = [...state];
    next.removeAt(index);
    state = next;
  }

  Future<void> deleteById(String id) async {
    await _ensureBox();
    await _box!.delete(id);
    state = state.where((e) => e.id != id).toList(growable: false);
  }

  Future<void> clearAll() async {
    await _ensureBox();
    await _box!.clear();
    state = const [];
  }

  /// Optional helper to export history to a file (CSV/XLSX)
  /// Returns a file path or null if not implemented.
  Future<String?> export() async {
    // TODO: Implement if needed by UI
    return null;
  }
}
