import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'opencv_card_cropper_platform_interface.dart';

/// An implementation of [OpencvCardCropperPlatform] that uses method channels.
class MethodChannelOpencvCardCropper extends OpencvCardCropperPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('opencv_card_cropper');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<String?> deskewCard({required String imagePath, Map<String, num>? roi}) async {
    final result = await methodChannel.invokeMethod<String>('deskewCard', {
      'imagePath': imagePath,
      if (roi != null) 'roi': {
        'x': roi['x'],
        'y': roi['y'],
        'width': roi['width'],
        'height': roi['height'],
      },
    });
    return result;
  }
}
