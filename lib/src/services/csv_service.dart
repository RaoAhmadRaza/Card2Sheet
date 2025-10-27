import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'file_service.dart';
import '../utils/schema.dart';

class CSVService {
  Future<File> saveAsCsv(Map<String, dynamic> data) async {
    final headers = data.keys.toList();
    final row = data.values.map((v) => v?.toString() ?? '').toList();
    final csv = const ListToCsvConverter().convert([headers, row]);

    final bytes = utf8.encode(csv);
    final fileService = FileService();
    final file = await fileService.writeFile(
        bytes, 'card_${DateTime.now().millisecondsSinceEpoch}.csv');
    return file;
  }

  Future<List<String>> extractHeaders(File csvFile) async {
    final content = await csvFile.readAsString();
    final List<List<dynamic>> rows =
        const CsvToListConverter().convert(content);
    if (rows.isNotEmpty) {
      return rows.first.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<void> appendRow(File csvFile, Map<String, dynamic> rowData) async {
    final content = await csvFile.readAsString();
    final List<List<dynamic>> rows =
        const CsvToListConverter().convert(content);
    final newRow = rowData.values.map((e) => e?.toString() ?? '').toList();
    rows.add(newRow);

    final updated = const ListToCsvConverter().convert(rows);
    await csvFile.writeAsString(updated);
  }

  /// Append a row using a pre-ordered list of values (aligned with header order).
  Future<void> appendRowValues(File csvFile, List<dynamic> values) async {
    final content = await csvFile.readAsString();
    final List<List<dynamic>> rows = const CsvToListConverter().convert(content);
    rows.add(values);

    final updated = const ListToCsvConverter().convert(rows);
    await csvFile.writeAsString(updated);
  }

  /// Remove the first row in the CSV that matches the normalized structured map
  /// according to the CSV's own header row. Returns true if a row was removed.
  Future<bool> removeRowMatchingNormalized(File csvFile, Map<String, String> normalized) async {
    if (!await csvFile.exists()) return false;
    final content = await csvFile.readAsString();
    final List<List<dynamic>> rows = const CsvToListConverter().convert(content);
    if (rows.isEmpty) return false;
  final header = rows.first.map((e) => e.toString()).toList();

    // Build target values in the file's header order
    final target = header.map((h) {
      final key = headerLabelToKey(h);
      if (key == kNotesKey) return normalized[kNotesKey] ?? '';
      return normalized[key] ?? 'NONE';
    }).toList();

    int matchIndex = -1;
    // Build header -> index map for fallback matching
    final headerIndex = <String, int>{};
    for (int i = 0; i < header.length; i++) {
      headerIndex[header[i]] = i;
    }
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i].map((e) => (e?.toString() ?? '')).toList();
      if (row.length != target.length) {
        // Normalize length for comparison
        final len = header.length;
        while (row.length < len) row.add('');
        if (row.length > len) row.removeRange(len, row.length);
      }
      bool equal = true;
      for (int c = 0; c < target.length; c++) {
        if (row[c].toString().trim() != target[c].toString().trim()) {
          equal = false;
          break;
        }
      }
      if (equal) {
        matchIndex = i;
        break;
      }
    }

    // Fallback strategies: match by Email, then by Phone, else by Name+Company
    String normEmail = (normalized['email'] ?? '').trim();
    String normPhone = (normalized['phone'] ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    String normName = (normalized['name'] ?? '').trim();
    String normCompany = (normalized['company'] ?? '').trim();

    String? headerEmail = header.firstWhere((h) => headerLabelToKey(h) == 'email', orElse: () => '');
    String? headerPhone = header.firstWhere((h) => headerLabelToKey(h) == 'phone', orElse: () => '');
    String? headerName = header.firstWhere((h) => headerLabelToKey(h) == 'name', orElse: () => '');
    String? headerCompany = header.firstWhere((h) => headerLabelToKey(h) == 'company', orElse: () => '');

    if (matchIndex == -1 && headerEmail.isNotEmpty && normEmail.isNotEmpty && normEmail.toUpperCase() != 'NONE') {
      final idx = headerIndex[headerEmail]!;
      for (int i = 1; i < rows.length; i++) {
        final cell = (rows[i].length > idx ? rows[i][idx] : '').toString().trim();
        if (cell.toLowerCase() == normEmail.toLowerCase()) {
          matchIndex = i;
          break;
        }
      }
    }
    if (matchIndex == -1 && headerPhone.isNotEmpty && normPhone.isNotEmpty && normPhone.toUpperCase() != 'NONE') {
      final idx = headerIndex[headerPhone]!;
      for (int i = 1; i < rows.length; i++) {
        final cell = (rows[i].length > idx ? rows[i][idx] : '').toString();
        final cellDigits = cell.replaceAll(RegExp(r'[^\d+]'), '');
        if (cellDigits == normPhone) {
          matchIndex = i;
          break;
        }
      }
    }
    if (matchIndex == -1 && headerName.isNotEmpty && headerCompany.isNotEmpty && normName.isNotEmpty) {
      final idxN = headerIndex[headerName]!;
      final idxC = headerIndex[headerCompany]!;
      for (int i = 1; i < rows.length; i++) {
        final nameCell = (rows[i].length > idxN ? rows[i][idxN] : '').toString().trim().toLowerCase();
        final compCell = (rows[i].length > idxC ? rows[i][idxC] : '').toString().trim().toLowerCase();
        if (nameCell == normName.toLowerCase() &&
            (normCompany.isEmpty || compCell == normCompany.toLowerCase())) {
          matchIndex = i;
          break;
        }
      }
    }

    // If still not found, treat as already deleted
    if (matchIndex == -1) return true;
    rows.removeAt(matchIndex);
    final updated = const ListToCsvConverter().convert(rows);
    await csvFile.writeAsString(updated);
    return true;
  }
}
