import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

class OCRService {
  Future<String> extractTextFromImage(File imageFile) async {
    if (!await imageFile.exists()) {
      throw FileSystemException('Image file not found', imageFile.path);
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await recognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      // Ensure native resources are released even if processing throws
      await recognizer.close();
    }
  }
}
