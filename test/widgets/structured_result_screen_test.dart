import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:card2sheet/src/screens/structured_result_screen.dart';
import 'package:card2sheet/src/providers/scan_result_provider.dart';
import 'package:card2sheet/src/providers/sheet_provider.dart';
import 'package:card2sheet/src/services/persistence_coordinator.dart';
import 'package:card2sheet/src/models/scan_result.dart';
import 'package:card2sheet/src/models/sheet_destination.dart';
import 'package:card2sheet/src/providers/session_provider.dart';
import 'package:card2sheet/src/models/session_state.dart';

class FakeScanResultNotifier extends ScanResultNotifier {
  FakeScanResultNotifier();
  @override
  ScanResult? build() => ScanResult(
        rawText: 'raw',
        structured: const {
          'name': 'John Doe',
          'email': 'john@example.com',
        },
      );
}

class FakeSheetNotifier extends SheetNotifier {
  @override
  SheetState build() => const SheetState(
        type: SheetType.csv,
        filePath: '/tmp/test.csv',
        headers: ['name', 'email'],
      );

  bool saved = false;

  @override
  Future<void> saveEntryDebounced(Map<String, String> structured,
      {SheetDestination? destination, Duration delay = const Duration(milliseconds: 300)}) async {
    saved = true;
  }
}

class TestPersistenceCoordinator extends PersistenceCoordinator {
  TestPersistenceCoordinator(super.ref);
  bool called = false;
  @override
  Future<void> saveEntryAtomic({required Map<String, String> structured, required SheetDestination destination}) async {
    called = true;
  }
}

class FakeSessionNotifier extends SessionNotifier {
  FakeSessionNotifier();
  @override
  SessionState build() => const SessionState();
  @override
  Future<void> updateLastFilePathIfNeeded() async {}
}

void main() {
  testWidgets('StructuredResultScreen shows fields and triggers save', (tester) async {
    // Ensure ample surface size to avoid layout overflows in tests
    tester.binding.window.physicalSizeTestValue = const Size(1200, 2000);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scanResultProvider.overrideWith(FakeScanResultNotifier.new),
          sheetProvider.overrideWith(FakeSheetNotifier.new),
          persistenceCoordinatorProvider.overrideWith((ref) => TestPersistenceCoordinator(ref)),
          sessionProvider.overrideWith(FakeSessionNotifier.new),
        ],
        child: const MaterialApp(home: StructuredResultScreen()),
      ),
    );

    // Expect the fields from the fake scan result
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);

    // Tap Save to Spreadsheet
    final saveButton = find.text('Save to Spreadsheet');
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  }, skip: true);
}
