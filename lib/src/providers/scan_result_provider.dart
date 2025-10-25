import 'package:riverpod/riverpod.dart';
// Using Riverpod v3 Notifier API
import '../models/scan_result.dart';
import 'history_provider.dart';
import 'session_provider.dart';

/// Holds the latest in-memory scan result for the current session
final scanResultProvider = NotifierProvider<ScanResultNotifier, ScanResult?>(
  ScanResultNotifier.new,
);

class ScanResultNotifier extends Notifier<ScanResult?> {
  @override
  ScanResult? build() => null;

  /// Set a fresh result: called after OCR + AI parsing
  Future<void> setResult(ScanResult result, {bool persist = true}) async {
    state = result;
    if (persist) {
      // persist to history & session
  await ref.read(historyProvider.notifier).addFromScan(result);
  await ref.read(sessionProvider.notifier).updateLastFilePathIfNeeded();
    }
  }

  void clear() => state = null;
}
