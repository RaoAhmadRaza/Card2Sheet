import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

class ManualCropScreen extends StatefulWidget {
  final String imagePath;
  const ManualCropScreen({super.key, required this.imagePath});

  @override
  State<ManualCropScreen> createState() => _ManualCropScreenState();
}

class _ManualCropScreenState extends State<ManualCropScreen> {
  bool _cropping = false;

  Future<void> _startCrop() async {
    setState(() => _cropping = true);
    try {
      final cropper = ImageCropper();
      final CroppedFile? cropped = await cropper.cropImage(
        sourcePath: widget.imagePath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 95,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust Crop',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: Colors.teal,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Adjust Crop',
            aspectRatioLockEnabled: false,
          ),
          WebUiSettings(context: context),
        ],
      );
      if (cropped != null && mounted) {
        Navigator.of(context).pop<String>(cropped.path);
      }
    } finally {
      if (mounted) setState(() => _cropping = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Kick off the cropper immediately for a one-tap UX
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCrop());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Crop')),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
          ),
          if (_cropping)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
