import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../src/services/ai_service.dart';
import 'package:flutter/foundation.dart';

final aiProvider = Provider((ref) => AIService());

class StructuredDataStore extends ValueNotifier<Map<String, dynamic>?> {
  StructuredDataStore() : super(null);
  void setData(Map<String, dynamic>? d) => value = d;
}

final structuredDataStoreProvider =
    Provider<StructuredDataStore>((ref) => StructuredDataStore());

class ProcessingStore extends ValueNotifier<bool> {
  ProcessingStore() : super(false);
  void setProcessing(bool v) => value = v;
}

final aiProcessingStoreProvider =
    Provider<ProcessingStore>((ref) => ProcessingStore());
