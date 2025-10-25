import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

import 'package:card2sheet/src/providers/scan_result_provider.dart';
import 'package:card2sheet/src/providers/history_provider.dart';
import 'package:card2sheet/src/providers/session_provider.dart';
import 'package:card2sheet/src/models/scan_result.dart';
import 'package:card2sheet/src/models/history_item.dart';
import 'package:card2sheet/src/models/sheet_destination.dart';
import 'package:card2sheet/src/models/session_state.dart';

class FakeHistoryNotifier extends HistoryNotifier {
  FakeHistoryNotifier();

  @override
  List<HistoryItem> build() => [];

  @override
  Future<void> addFromScan(ScanResult result) async {
    final item = HistoryItem(
      id: 'test',
      structured: result.structured,
      destination: const SheetDestination(type: SheetType.csv, path: '/tmp/test.csv'),
      rowIndex: -1,
    );
    state = [item, ...state];
  }
}

class FakeSessionNotifier extends SessionNotifier {
  FakeSessionNotifier();

  @override
  SessionState build() => const SessionState();

  @override
  Future<void> updateLastFilePathIfNeeded() async {
    // no-op in fake
  }
}

void main() {
  test('setResult persists to history and updates session', () async {
    final container = ProviderContainer(overrides: [
      historyProvider.overrideWith(FakeHistoryNotifier.new),
      sessionProvider.overrideWith(FakeSessionNotifier.new),
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(scanResultProvider.notifier);

    final sample = ScanResult(
      rawText: 'raw',
      structured: const {'name': 'Jane Doe', 'email': 'jane@example.com'},
    );

    await notifier.setResult(sample, persist: true);

    final hist = container.read(historyProvider);
    expect(hist.length, 1);
    expect(hist.first.structured['name'], 'Jane Doe');
  });
}
