import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class XlsxService {
  Future<File> saveAsXlsx(
    Map<String, dynamic> data, {
    String sheetName = 'Sheet1',
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel[sheetName];

    // Prepare headers and values
    final headers = data.keys.toList();
    final values = data.values.map((v) => v?.toString() ?? '').toList();

    // Write headers with bold style
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // Write values in the next row
    for (int i = 0; i < values.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(values[i]);
    }

    final bytes = excel.encode()!;
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/card_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Create a new XLSX file with a header row and a single values row.
  Future<File> saveRowToNewXlsx(
    List<String> headers,
    List<String> values, {
    String sheetName = 'Sheet1',
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel[sheetName];

    // Write headers
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // Write values
    for (int i = 0; i < values.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(values[i]);
    }

    final bytes = excel.encode()!;
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/card_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Append a row to an existing XLSX file while preserving header order and
  /// adding any missing headers to the end of the header row.
  ///
  /// [desiredHeaders] represents the app's expected header labels order.
  /// [values] must be aligned with [desiredHeaders]. This method will map
  /// values into the existing file's header order and extend the header row
  /// with any missing headers before appending.
  Future<void> appendRowToExistingXlsx({
    required List<String> desiredHeaders,
    required List<String> values,
    required String filePath,
    String sheetName = 'Sheet1',
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      // If the file doesn't exist, create a new workbook with headers + row
      final newFile = await saveRowToNewXlsx(desiredHeaders, values, sheetName: sheetName);
      if (newFile.path != filePath) {
        await newFile.copy(filePath);
      }
      return;
    }

    List<int> originalBytes = await file.readAsBytes();
    Excel excel;
    try {
      excel = Excel.decodeBytes(originalBytes);
    } catch (e) {
      // Corrupted or unreadable workbook: rebuild a new one while preserving nothing else
      final newFile = await saveRowToNewXlsx(desiredHeaders, values, sheetName: sheetName);
      if (newFile.path != filePath) {
        // Backup the corrupted file
        final backupPath = p.setExtension(filePath, '.bak');
        try { await file.copy(backupPath); } catch (_) {}
        await newFile.copy(filePath);
      }
      return;
    }

    // Determine the working sheet: prefer provided sheetName, otherwise first sheet
    final availableSheets = excel.tables.keys.toList(growable: false);
    final selectedSheetName = availableSheets.contains(sheetName)
        ? sheetName
        : (availableSheets.isNotEmpty ? availableSheets.first : sheetName);
    final sheet = excel[selectedSheetName];

    // Helper to read a header row into strings, trimming trailing empties
    String _cellValueToString(dynamic v) {
      if (v == null) return '';
      final s = v.toString();
      // Extract inner text from wrappers like TextCellValue(value)
      final m = RegExp(r'TextCellValue\((.*)\)').firstMatch(s);
      final extracted = m != null ? (m.group(1) ?? '') : s;
      return extracted;
    }

    List<String> _readHeaderRow() {
      // Try using rows API if present
      final rows = sheet.rows;
      if (rows.isNotEmpty) {
        final first = rows.first;
        final List<String> raw = first
            .map((data) => _cellValueToString(data?.value))
            .toList()
            .cast<String>();
        // Trim trailing empties
        int end = raw.length;
        while (end > 0 && (raw[end - 1].trim().isEmpty)) {
          end--;
        }
        return raw.sublist(0, end);
      }
      return <String>[];
    }

    // Read existing headers (may be empty/malformed)
    List<String> existingHeaders = _readHeaderRow();

    // Ensure desiredHeaders and values lengths align
    if (values.length < desiredHeaders.length) {
      values = [...values, ...List<String>.filled(desiredHeaders.length - values.length, '')];
    } else if (values.length > desiredHeaders.length) {
      values = values.sublist(0, desiredHeaders.length);
    }

    // Build a value map keyed by desired headers
    final Map<String, String> desiredMap = {
      for (int i = 0; i < desiredHeaders.length; i++) desiredHeaders[i]: values[i]
    };

    // If no existing headers or malformed (all empty), initialize with desired headers
    List<String> finalHeaderOrder;
    final bool hasAnyHeader = existingHeaders.any((h) => h.trim().isNotEmpty);
    if (!hasAnyHeader) {
      finalHeaderOrder = List<String>.from(desiredHeaders);
      // Write header row
      for (int i = 0; i < finalHeaderOrder.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(finalHeaderOrder[i]);
        cell.cellStyle = CellStyle(bold: true);
      }
    } else {
      // Start with existing order, then append any missing desired headers at the end
      finalHeaderOrder = List<String>.from(existingHeaders);
      for (final h in desiredHeaders) {
        if (!finalHeaderOrder.contains(h)) {
          finalHeaderOrder.add(h);
        }
      }
      // If header row grew, write newly added headers to sheet
      for (int i = existingHeaders.length; i < finalHeaderOrder.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(finalHeaderOrder[i]);
        cell.cellStyle = CellStyle(bold: true);
      }
    }

    // Map to final header order
    final List<String> rowValues = finalHeaderOrder.map((h) => desiredMap[h] ?? '').toList();

    // Find first empty row after existing data
    int targetRowIndex = 1; // row 0 is header
    final rows = sheet.rows;
  if (rows.length > 1) {
      // Find last non-empty row
      int last = rows.length - 1;
  bool isRowEmpty(List<Data?> r) => r.every((c) {
    final v = c?.value;
    if (v == null) return true;
    final s = _cellValueToString(v).trim();
    return s.isEmpty;
      });
      // Move up until we find a non-empty row
      while (last >= 1 && isRowEmpty(rows[last])) {
        last--;
      }
      targetRowIndex = last + 1;
    }

    // Validate counts: pad rowValues to header length
    if (rowValues.length < finalHeaderOrder.length) {
      rowValues.addAll(List<String>.filled(finalHeaderOrder.length - rowValues.length, ''));
    } else if (rowValues.length > finalHeaderOrder.length) {
      // Truncate if somehow longer
      rowValues.removeRange(finalHeaderOrder.length, rowValues.length);
    }

    // Write the values row
    for (int i = 0; i < rowValues.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: targetRowIndex));
      cell.value = TextCellValue(rowValues[i]);
    }

    // Encode and write back, handling potential file locks by writing to a temp file first
    final bytes = excel.encode()!;
    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      // Attempt temp write and replace
      final dir = await getApplicationDocumentsDirectory();
      final tmpPath = p.join(dir.path, 'tmp_${DateTime.now().microsecondsSinceEpoch}.xlsx');
      final tmpFile = File(tmpPath);
      await tmpFile.writeAsBytes(bytes, flush: true);
      try {
        await file.delete();
      } catch (_) {}
      await tmpFile.copy(filePath);
      try { await tmpFile.delete(); } catch (_) {}
    }
  }
}
