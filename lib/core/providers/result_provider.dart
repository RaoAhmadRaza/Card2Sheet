import 'dart:io';
import 'package:flutter/foundation.dart';

class ScanResultState {
  final String recognizedText;
  final Map<String, dynamic>? aiResult;
  final File? savedCsv;

  const ScanResultState({
    this.recognizedText = '',
    this.aiResult,
    this.savedCsv,
  });

  ScanResultState copyWith({
    String? recognizedText,
    Map<String, dynamic>? aiResult,
    File? savedCsv,
  }) => ScanResultState(
    recognizedText: recognizedText ?? this.recognizedText,
    aiResult: aiResult ?? this.aiResult,
    savedCsv: savedCsv ?? this.savedCsv,
  );
}

class ScanResultStore extends ChangeNotifier {
  ScanResultStore._();
  static final ScanResultStore instance = ScanResultStore._();

  ScanResultState _state = const ScanResultState();
  ScanResultState get state => _state;

  void setRecognizedText(String text) {
    _state = _state.copyWith(
      recognizedText: text,
      aiResult: null,
      savedCsv: null,
    );
    notifyListeners();
  }

  void setAiResult(Map<String, dynamic> result) {
    _state = _state.copyWith(aiResult: result);
    notifyListeners();
  }

  void setSavedCsv(File file) {
    _state = _state.copyWith(savedCsv: file);
    notifyListeners();
  }
}
