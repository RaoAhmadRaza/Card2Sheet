import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:exif/exif.dart' as exif;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class CardDetectorResult {
  final String? croppedFilePath;
  final Rect? boundingBox; // in original image pixel coordinates
  final String? error;

  CardDetectorResult({this.croppedFilePath, this.boundingBox, this.error});
}

class CardDetectorService {
  final ObjectDetector _objectDetector;
  final TextRecognizer _textRecognizer;

  CardDetectorService()
      : _objectDetector = ObjectDetector(
          options: ObjectDetectorOptions(
            mode: DetectionMode.single,
            classifyObjects: false,
            multipleObjects: false,
          ),
        ),
        _textRecognizer = TextRecognizer();

  Future<CardDetectorResult> detectAndCrop(File imageFile) async {
    try {
      // 1) Run object detection
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final objects = await _objectDetector.processImage(inputImage);

      Rect? bestBox;
      if (objects.isNotEmpty) {
        bestBox = objects.first.boundingBox;
      }

      // 2) If no object detected, do text-based fallback to find card region
      if (bestBox == null) {
        final fallbackBox = await _detectUsingTextBlocks(inputImage);
        if (fallbackBox != null) bestBox = fallbackBox;
      } else {
        // Optional: refine bounding box by union with text blocks
        final refined = await _refineWithTextBlocks(inputImage, bestBox);
        if (refined != null) bestBox = refined;
      }

      if (bestBox == null) {
        return CardDetectorResult(error: 'No card-like object detected');
      }

  // 3) Load image with EXIF-aware decode
  final original = await _decodeWithOrientation(imageFile);
  if (original == null) return CardDetectorResult(error: 'Cannot decode image');

      // Reject tiny detections relative to image area
      final imgArea = (original.width * original.height).toDouble();
      final boxArea = (bestBox.width * bestBox.height).toDouble();
      final areaRatio = boxArea / imgArea;
      if (areaRatio < 0.08) { // < 8% of image considered unreliable
        return CardDetectorResult(error: 'Detected area too small');
      }

      // Expand a small padding around detected box with a minimum
      final pad = math.max(8, (math.min(bestBox.width, bestBox.height) * 0.05).toInt());
      final left = (bestBox.left - pad).clamp(0, original.width - 1).toInt();
      final top = (bestBox.top - pad).clamp(0, original.height - 1).toInt();
      final right = (bestBox.right + pad).clamp(0, original.width).toInt();
      final bottom = (bestBox.bottom + pad).clamp(0, original.height).toInt();
      final cropW = (right - left).clamp(1, original.width).toInt();
      final cropH = (bottom - top).clamp(1, original.height).toInt();

      final cropped = img.copyCrop(
        original,
        x: left,
        y: top,
        width: cropW,
        height: cropH,
      );

      img.Image finalImage = cropped;

      // 4) Save to temp
      final dir = await getTemporaryDirectory();
      final outPath = '${dir.path}/${const Uuid().v4()}.jpg';
      final outFile = File(outPath);
      await outFile.writeAsBytes(img.encodeJpg(finalImage, quality: 92));

      return CardDetectorResult(
        croppedFilePath: outPath,
        boundingBox: bestBox,
      );
    } catch (e, st) {
      debugPrint('CardDetectorService error: $e\n$st');
      return CardDetectorResult(error: e.toString());
    }
  }

  // EXIF-aware decode to ensure orientation matches ML Kit bounding boxes
  Future<img.Image?> _decodeWithOrientation(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return null;

      try {
        final tags = await exif.readExifFromBytes(bytes);
        final orientation = tags['Image Orientation']?.printable;
        if (orientation != null) {
          if (orientation.contains('Rotated 90')) {
            return img.copyRotate(original, angle: 90);
          }
          if (orientation.contains('Rotated 180')) {
            return img.copyRotate(original, angle: 180);
          }
          if (orientation.contains('Rotated 270')) {
            return img.copyRotate(original, angle: 270);
          }
        }
      } catch (_) {}
      // Fallback to bakeOrientation which handles common EXIF flags
      return img.bakeOrientation(original);
    } catch (_) {
      return null;
    }
  }

  Future<Rect?> _detectUsingTextBlocks(InputImage inputImage) async {
    final recognized = await _textRecognizer.processImage(inputImage);
    if (recognized.blocks.isEmpty) return null;

    double left = double.infinity, top = double.infinity, right = 0, bottom = 0;
    for (final block in recognized.blocks) {
      final rect = block.boundingBox;
      left = math.min(left, rect.left);
      top = math.min(top, rect.top);
      right = math.max(right, rect.right);
      bottom = math.max(bottom, rect.bottom);
    }
    if (left == double.infinity) return null;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Future<Rect?> _refineWithTextBlocks(InputImage inputImage, Rect box) async {
    final recognized = await _textRecognizer.processImage(inputImage);
    if (recognized.blocks.isEmpty) return box;

    double left = box.left, top = box.top, right = box.right, bottom = box.bottom;
    for (final block in recognized.blocks) {
      final r = block.boundingBox;
      // Expand the object box slightly if text blocks extend outside
      left = math.min(left, r.left);
      top = math.min(top, r.top);
      right = math.max(right, r.right);
      bottom = math.max(bottom, r.bottom);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void dispose() {
    _objectDetector.close();
    _textRecognizer.close();
  }
}

// Notes:
// InputImage.fromFilePath generally provides bounding boxes aligned with the
// decoded image orientation (ML Kit accounts for EXIF). If crops appear rotated
// on specific devices, consider applying orientation transforms to the image
// bytes before decoding and/or mapping coordinates accordingly.
