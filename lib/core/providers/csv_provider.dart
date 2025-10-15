import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../src/services/csv_service.dart';

final csvServiceProvider = Provider((ref) => CSVService());

final csvProvider =
    FutureProvider.family<File, Map<String, dynamic>>((ref, data) async {
  final csvService = ref.read(csvServiceProvider);
  return csvService.saveAsCsv(data);
});
