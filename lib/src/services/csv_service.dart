import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'file_service.dart';

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
}
