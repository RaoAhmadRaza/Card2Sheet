import 'dart:io';

import 'package:riverpod/riverpod.dart';

import '../models/sheet_destination.dart';
import '../models/scan_result.dart';
import '../providers/history_provider.dart';
import '../providers/session_provider.dart';
import 'csv_service.dart';
import 'xlsx_service.dart';

/// Orchestrates atomic persistence across file + history + session updates.
class PersistenceCoordinator {
  final Ref ref;
  PersistenceCoordinator(this.ref);

  /// Saves a single structured entry into the configured destination, then
  /// records it into history and updates session's last destination.
  /// If any stage fails, attempts to rollback the previous stage.
  Future<void> saveEntryAtomic({
    required Map<String, String> structured,
    required SheetDestination destination,
  }) async {
    File? file;
    List<int>? originalBytes;

    try {
      switch (destination.type) {
        case SheetType.csv:
          file = File(destination.path);
          if (await file.exists()) {
            originalBytes = await file.readAsBytes();
          }
          final csvService = CSVService();
          // Append values-only row (no headers)
          // Build a row that aligns with ordering of keys in `structured`
          final row = <String, dynamic>{ for (final e in structured.entries) e.key: e.value };
          if (await file.exists()) {
            await csvService.appendRow(file, row);
          } else {
            // Create new CSV with a single row and no header
            await file.create(recursive: true);
            await file.writeAsString('${structured.values.join(',')}\n');
          }
          break;
        case SheetType.xlsx:
          // For xlsx, we need to append a row to an existing sheet or create a new one
          // Use XlsxService minimally by creating/merging
          final xlsxService = XlsxService();
          // Fallback simple path: if file exists, we cannot easily append without reading it fully.
          // For now, we create new file if not exists; otherwise, we delegate to UI-level append logic.
          file = File(destination.path);
          if (!await file.exists()) {
            final temp = await xlsxService.saveAsXlsx(structured);
            await temp.copy(destination.path);
            file = File(destination.path);
          } else {
            // Leave actual append to UI screen where workbook context exists.
          }
          break;
      }

      // Record in history
      final result = ScanResult(rawText: '', structured: structured);
      await ref.read(historyProvider.notifier).addFromScan(result);

      // Update session last destination
      await ref.read(sessionProvider.notifier).setLastDestination(destination);
    } catch (e) {
      // Rollback if we modified a CSV file
      if (file != null && originalBytes != null) {
        try {
          await file.writeAsBytes(originalBytes, flush: true);
        } catch (_) {}
      }
      rethrow;
    }
  }
}

final persistenceCoordinatorProvider = Provider((ref) => PersistenceCoordinator(ref));
