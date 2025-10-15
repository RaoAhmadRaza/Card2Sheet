import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../src/services/file_service.dart';
import '../../src/services/csv_service.dart';
import 'package:flutter/foundation.dart';

/// Small in-memory store for template headers. Uses ValueNotifier so it can
/// be observed via a simple provider.
class TemplateStore extends ValueNotifier<List<String>> {
  TemplateStore() : super([]);

  void setHeaders(List<String> headers) => value = headers;
}

final templateStoreProvider = Provider<TemplateStore>((ref) => TemplateStore());

/// Exposes the current list of headers.
final templateProvider =
    Provider<List<String>>((ref) => ref.read(templateStoreProvider).value);

/// Loader that updates the TemplateStore after picking a CSV.
class TemplateLoader {
  final Ref ref;
  TemplateLoader(this.ref);

  Future<void> loadTemplate() async {
    final fileService = FileService();
    final csvService = CSVService();
    final file = await fileService.pickCsvFile();
    if (file != null) {
      final headers = await csvService.extractHeaders(file);
      ref.read(templateStoreProvider).setHeaders(headers);
    }
  }
}

final templateLoaderProvider = Provider((ref) => TemplateLoader(ref));
