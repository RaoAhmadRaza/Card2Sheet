import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

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
}
