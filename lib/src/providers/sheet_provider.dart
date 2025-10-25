import 'package:riverpod/riverpod.dart';
import '../models/sheet_destination.dart';

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
  @override
  SheetState build() =>
      const SheetState(type: SheetType.csv, headers: ['Name', 'Company', 'Email']);

  void setType(SheetType t) =>
    state = SheetState(type: t, filePath: state.filePath, headers: state.headers);

  void setFilePath(String path) => state =
    SheetState(type: state.type, filePath: path, headers: state.headers);

  void setHeaders(List<String> h) => state =
    SheetState(type: state.type, filePath: state.filePath, headers: h);
}
