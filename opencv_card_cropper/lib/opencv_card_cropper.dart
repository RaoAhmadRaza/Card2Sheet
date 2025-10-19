
import 'opencv_card_cropper_platform_interface.dart';

class OpencvCardCropper {
  Future<String?> getPlatformVersion() {
    return OpencvCardCropperPlatform.instance.getPlatformVersion();
  }

  Future<String?> deskewCard({required String imagePath, Map<String, num>? roi}) {
    return OpencvCardCropperPlatform.instance.deskewCard(imagePath: imagePath, roi: roi);
  }
}
