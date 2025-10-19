import 'package:flutter/services.dart';

class OpencvCropper {
  static const _channel = MethodChannel('opencv_card_cropper');

  static Future<String?> deskewCard(String path) async {
    try {
      final result = await _channel.invokeMethod('deskewCard', {'path': path});
      return result as String?;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('Deskew failed: ${e.message}');
      return null;
    }
  }
}
