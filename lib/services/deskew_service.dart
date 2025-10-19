import 'package:card2sheet/services/opencv_cropper.dart';

class DeskewService {
  // Returns output image path (for now same as input until native implemented)
  static Future<String?> deskew(String imagePath, {Map<String, num>? roi}) async {
    // Note: current wrapper passes only the path; ROI currently unused in channel API here.
    return OpencvCropper.deskewCard(imagePath);
  }
}
