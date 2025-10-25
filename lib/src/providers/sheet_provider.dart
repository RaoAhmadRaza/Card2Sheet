import 'package:riverpod/riverpod.dart';
import '../models/sheet_destination.dart';
import 'dart:async';
import '../services/persistence_coordinator.dart';

class SheetState {
  final SheetType type;
  final String? filePath; // null if new/unsaved
  final List<String> headers; // user selected headers

  const SheetState({
    required this.type,
    this.filePath,
    required this.headers,
  });

  SheetState copyWith({
    SheetType? type,
    String? filePath,
    List<String>? headers,
  }) => SheetState(
        type: type ?? this.type,
        filePath: filePath ?? this.filePath,
        headers: headers ?? this.headers,
      );

  /// Convert provider state to a persistable destination model when possible
  SheetDestination? toDestination({String? sheetName}) {
    final p = filePath;
    if (p == null || p.isEmpty) return null;
    return SheetDestination(
      type: type,
      path: p,
      sheetName: sheetName,
      templateHeaders: headers,
    );
  }
}

final sheetProvider = NotifierProvider<SheetNotifier, SheetState>(
  SheetNotifier.new,
);

class SheetNotifier extends Notifier<SheetState> {
  Timer? _debounceTimer;
  @override
  SheetState build() =>
      const SheetState(type: SheetType.csv, headers: ['Name', 'Company', 'Email']);

  void setType(SheetType t) =>
    state = SheetState(type: t, filePath: state.filePath, headers: state.headers);

  void setFilePath(String path) => state =
    SheetState(type: state.type, filePath: path, headers: state.headers);

  void setHeaders(List<String> h) => state =
    SheetState(type: state.type, filePath: state.filePath, headers: h);

  /// Debounced save of a structured entry into the current destination.
  /// Only the last call within [delay] window will execute.
  Future<void> saveEntryDebounced(
    Map<String, String> structured, {
    SheetDestination? destination,
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    final completer = Completer<void>();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () async {
      try {
        final dest = destination ?? state.toDestination();
        if (dest == null || dest.path.isEmpty) {
          throw Exception('No destination configured');
        }
        final pc = ref.read(persistenceCoordinatorProvider);
        await pc.saveEntryAtomic(structured: structured, destination: dest);
        if (!completer.isCompleted) completer.complete();
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
