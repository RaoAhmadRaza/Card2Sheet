import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../src/services/ocr_service.dart';

final ocrServiceProvider = Provider((ref) => OCRService());

/// Holds last extracted text (nullable).
/// In-memory store for the last extracted text
class ExtractedTextStore extends ValueNotifier<String?> {
  ExtractedTextStore() : super(null);
  void setText(String? t) => value = t;
}

final extractedTextStoreProvider =
    Provider<ExtractedTextStore>((ref) => ExtractedTextStore());

final ocrProvider = Provider((ref) {
  return (File image) async {
    final service = ref.read(ocrServiceProvider);
    final text = await service.extractTextFromImage(image);
    ref.read(extractedTextStoreProvider).setText(text);
    return text;
  };
});
