import 'dart:async';
import 'package:hive/hive.dart';
import 'package:riverpod/riverpod.dart';

import '../models/sheet_destination.dart';
import '../services/persistence_coordinator.dart';

/// A lightweight, durable queue for persistence operations.
/// Stores pending operations in the 'app_meta' box under the 'op_queue' key.
class OperationQueueState {
  final List<Map<String, dynamic>> pending;
  const OperationQueueState(this.pending);
}

final operationQueueProvider =
    NotifierProvider<OperationQueueNotifier, OperationQueueState>(
  OperationQueueNotifier.new,
);

class OperationQueueNotifier extends Notifier<OperationQueueState> {
  static const _boxName = 'app_meta';
  static const _key = 'op_queue';

  Box? _box;
  bool _processing = false;

  @override
  OperationQueueState build() {
    Future.microtask(_hydrate);
    return const OperationQueueState([]);
  }

  Future<void> _hydrate() async {
    _box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : await Hive.openBox(_boxName);
    final list = (_box!.get(_key) as List?)?.cast<Map>() ?? [];
    state = OperationQueueState(list.map((e) => Map<String, dynamic>.from(e)).toList());
    // Auto-process on startup
    unawaited(processPending());
  }

  Future<void> _persist() async {
    await _box!.put(_key, state.pending);
  }

  Future<void> enqueueSave(Map<String, String> structured, SheetDestination dest) async {
    final op = {
      'type': 'save_entry',
      'structured': structured,
      'destination': dest.toJson(),
      'ts': DateTime.now().toIso8601String(),
      'retries': 0,
    };
    state = OperationQueueState([...state.pending, op]);
    await _persist();
    unawaited(processPending());
  }

  Future<void> processPending() async {
    if (_processing) return;
    _processing = true;
    try {
      while (state.pending.isNotEmpty) {
        final next = state.pending.first;
        final type = next['type'] as String?;
        if (type == 'save_entry') {
          final structured = Map<String, String>.from(next['structured'] as Map);
          final dest = SheetDestination.fromJson(Map<String, dynamic>.from(next['destination'] as Map));
          try {
            final pc = ref.read(persistenceCoordinatorProvider);
            await pc.saveEntryAtomic(structured: structured, destination: dest);
            // Remove from queue
            state = OperationQueueState(state.pending.sublist(1));
            await _persist();
          } catch (_) {
            // Exponential backoff via simple delay based on retries
            final retries = (next['retries'] as int? ?? 0) + 1;
            next['retries'] = retries;
            await _persist();
            await Future.delayed(Duration(milliseconds: 300 * retries));
          }
        } else {
          // Unknown op; drop it
          state = OperationQueueState(state.pending.sublist(1));
          await _persist();
        }
      }
    } finally {
      _processing = false;
    }
  }
}
