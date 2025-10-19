import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'opencv_card_cropper_method_channel.dart';

abstract class OpencvCardCropperPlatform extends PlatformInterface {
  /// Constructs a OpencvCardCropperPlatform.
  OpencvCardCropperPlatform() : super(token: _token);

  static final Object _token = Object();

  static OpencvCardCropperPlatform _instance = MethodChannelOpencvCardCropper();

  /// The default instance of [OpencvCardCropperPlatform] to use.
  ///
  /// Defaults to [MethodChannelOpencvCardCropper].
  static OpencvCardCropperPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OpencvCardCropperPlatform] when
  /// they register themselves.
  static set instance(OpencvCardCropperPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  // Deskew a card image using native OpenCV.
  // imagePath: absolute path to input image file
  // roi: optional map with keys {x, y, width, height} in input image pixel coords
  Future<String?> deskewCard({required String imagePath, Map<String, num>? roi}) {
    throw UnimplementedError('deskewCard() has not been implemented.');
  }
}
