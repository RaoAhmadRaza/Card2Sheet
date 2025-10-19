import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_card_cropper/opencv_card_cropper.dart';
import 'package:opencv_card_cropper/opencv_card_cropper_platform_interface.dart';
import 'package:opencv_card_cropper/opencv_card_cropper_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOpencvCardCropperPlatform
    with MockPlatformInterfaceMixin
    implements OpencvCardCropperPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<String?> deskewCard({required String imagePath, Map<String, num>? roi}) =>
      Future.value(imagePath);
}

void main() {
  final OpencvCardCropperPlatform initialPlatform = OpencvCardCropperPlatform.instance;

  test('$MethodChannelOpencvCardCropper is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelOpencvCardCropper>());
  });

  test('getPlatformVersion', () async {
    OpencvCardCropper opencvCardCropperPlugin = OpencvCardCropper();
    MockOpencvCardCropperPlatform fakePlatform = MockOpencvCardCropperPlatform();
    OpencvCardCropperPlatform.instance = fakePlatform;

    expect(await opencvCardCropperPlugin.getPlatformVersion(), '42');
  });
}
