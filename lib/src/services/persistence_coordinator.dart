import 'dart:io';

import 'package:riverpod/riverpod.dart';
import 'package:csv/csv.dart';

import '../models/sheet_destination.dart';
import '../models/scan_result.dart';
import '../providers/history_provider.dart';
import '../providers/session_provider.dart';
import 'csv_service.dart';
import 'xlsx_service.dart';
import '../utils/schema.dart';

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
      // Normalize incoming map to strict schema and include notes if present
      final normalized = normalizeToStrictSchema(structured);
      // Always include Personal Thoughts as the 8th column (even if empty)
      List<String> desiredHeaders = destination.templateHeaders.isNotEmpty
          ? List<String>.from(destination.templateHeaders)
          : defaultExportHeaders(includeNotes: true);
      if (!desiredHeaders.contains(kNotesHeaderLabel)) {
        desiredHeaders.add(kNotesHeaderLabel);
      }

      switch (destination.type) {
        case SheetType.csv:
          file = File(destination.path);
          if (await file.exists()) {
            originalBytes = await file.readAsBytes();
          }
          final csvService = CSVService();
          // Determine header order (existing file header takes precedence)
          List<String> headerOrder = desiredHeaders;
          if (await file.exists()) {
            final existing = await csvService.extractHeaders(file);
            if (existing.isNotEmpty) {
              headerOrder = existing;
            }
          } else {
            await file.create(recursive: true);
            final headerCsv = const ListToCsvConverter().convert([headerOrder]);
            await file.writeAsString(headerCsv);
          }
          // Build row values aligned with header order
          final values = valuesForHeaders(headerOrder, normalized);
          await csvService.appendRowValues(file, values);
          break;
        case SheetType.xlsx:
          // For xlsx, we need to append a row to an existing sheet or create a new one
          // Use XlsxService minimally by creating/merging
          final xlsxService = XlsxService();
          // Fallback simple path: if file exists, we cannot easily append without reading it fully.
          // Create new file if not exists; otherwise, append to the existing workbook using header reconciliation.
          file = File(destination.path);
          if (!await file.exists()) {
            final values = valuesForHeaders(desiredHeaders, normalized);
            final temp = await xlsxService.saveRowToNewXlsx(desiredHeaders, values, sheetName: destination.sheetName ?? 'Sheet1');
            await temp.copy(destination.path);
            file = File(destination.path);
          } else {
            final values = valuesForHeaders(desiredHeaders, normalized);
            await xlsxService.appendRowToExistingXlsx(
              desiredHeaders: desiredHeaders,
              values: values,
              filePath: destination.path,
              sheetName: destination.sheetName ?? 'Sheet1',
            );
          }
          break;
      }

      // Record in history
      final result = ScanResult(rawText: '', structured: normalized);
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
