import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
// Cropping is invoked inline via ImageCropper for seamless UX
import 'package:image_cropper/image_cropper.dart';
// import 'manual_crop_screen.dart';
import 'processing_screen.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _showTips = false;
  XFile? _capturedImage;
  bool _isCapturing = false;
  String? _errorMessage;
  // Preferred: use camera's native preview aspect (full photo, no stretch)
  // Set to true if you want to force a 4:3 letterboxed preview box
  final bool _useFourThreePreview = false;
  // Tap-to-focus visual feedback
  bool _showFocusIndicator = false;
  Offset? _focusIndicatorPos; // in preview-box coordinates
  // Show guidance if last detection failed
  // Auto-detect removed; no failure state needed

  // Animation controllers for the overlay
  late AnimationController _borderAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _borderAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _borderAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _borderAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _borderAnimationController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeCamera() async {
    try {
      // Check camera permission first
      if (Platform.isIOS || Platform.isAndroid) {
        // Add a small delay to ensure the app is fully initialized
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Try highest quality first (better detail, likely 4:3 on many sensors) using JPEG
        // Fallback to slightly lower presets if initialization fails
        Future<void> initWith(ResolutionPreset preset, ImageFormatGroup fmt) async {
          _cameraController = CameraController(
            _cameras.first,
            preset,
            enableAudio: false,
            imageFormatGroup: fmt,
          );
          await _cameraController!.initialize();
        }

        try {
          // Prefer veryHigh first (more stable on some devices), then max
          await initWith(ResolutionPreset.veryHigh, ImageFormatGroup.jpeg);
        } catch (e) {
          debugPrint('Init with veryHigh/jpeg failed: $e');
          try {
            await initWith(ResolutionPreset.max, ImageFormatGroup.jpeg);
          } catch (e2) {
            debugPrint('Init with max/jpeg failed: $e2');
            try {
              await initWith(ResolutionPreset.high, ImageFormatGroup.yuv420);
            } catch (e3) {
              debugPrint('Init with high/yuv420 failed: $e3');
              rethrow;
            }
          }
        }

        if (mounted) {
          try {
            final pv = _cameraController!.value.previewSize;
            final ar = _cameraController!.value.aspectRatio;
            debugPrint('Camera initialized. previewSize=${pv?.width}x${pv?.height}, aspectRatio=${ar.toStringAsFixed(4)}');
            // Ensure autofocus/exposure are enabled
            await _cameraController!.setFocusMode(FocusMode.auto);
            await _cameraController!.setExposureMode(ExposureMode.auto);
            // Force flash OFF by default (some devices default to AUTO)
            await _cameraController!.setFlashMode(FlashMode.off);
            _isFlashOn = false;
          } catch (_) {}
          setState(() {
            _isCameraInitialized = true;
            _errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'No cameras available on this device';
          });
        }
      }
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera initialization failed.\nPlease check camera permissions in Settings.';
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController?.value.isInitialized == true) {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController?.value.isInitialized != true || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      // Make sure flash follows our toggle state (no AUTO flash)
      await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      final image = await _cameraController!.takePicture();
      // Optional small settle delay to let focus lock
      await Future.delayed(const Duration(milliseconds: 150));

      // Auto-detect temporarily disabled: open cropper directly (no intermediate screen flicker)
      XFile resulting = image;
      final edited = await _openCropper(image.path);
      if (edited != null) {
        resulting = XFile(edited);
      }

      setState(() {
        _capturedImage = resulting;
        _isCapturing = false;
      });
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      debugPrint('Capture failed: $e');
    }
  }

  // Card detect/crop handled by CardDetectorService
  // Auto-detect temporarily disabled; manual crop used instead

  void _retakeImage() {
    setState(() {
      _capturedImage = null;
    });
  }

  void _useImage() {
    if (_capturedImage != null) {
      final path = _capturedImage!.path;
      // Validate file existence before navigating
      final f = File(path);
      if (!f.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Captured image unavailable. Please try again.')),
        );
        return;
      }
      // Navigate to processing screen with the selected image
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProcessingScreen(imagePath: path),
        ),
      );
    }
  }

  Future<void> _adjustCrop() async {
    if (_capturedImage == null) return;
    final currentPath = _capturedImage!.path;
    final edited = await _openCropper(currentPath);
    if (!mounted) return;
    if (edited != null) {
      if (!mounted) return;
      // Use exactly what the user cropped (no auto processing)
      setState(() {
        _capturedImage = XFile(edited);
      });
    }
  }

  Future<void> _handleFocusTap(TapDownDetails details, Size previewBoxSize) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      // Convert local tap to normalized point (0..1)
      final localPos = details.localPosition;
      final nx = (localPos.dx / previewBoxSize.width).clamp(0.0, 1.0);
      final ny = (localPos.dy / previewBoxSize.height).clamp(0.0, 1.0);

      setState(() {
        _showFocusIndicator = true;
        _focusIndicatorPos = Offset(localPos.dx, localPos.dy);
      });

      await _cameraController!.setFocusPoint(Offset(nx, ny));
      await _cameraController!.setExposurePoint(Offset(nx, ny));
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);

      // Hide indicator shortly after
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _showFocusIndicator = false);
        }
      });
    } catch (e) {
      debugPrint('Tap-to-focus failed: $e');
    }
  }

  // (unused) aspect ratio helper removed after switching to BoxFit.cover approach

  @override
  void dispose() {
    _borderAnimationController.dispose();
    _pulseAnimationController.dispose();
    // Dispose camera controller after attempting to turn off torch (don't await in dispose)
    try {
      final controller = _cameraController;
      if (controller != null && controller.value.isInitialized) {
        // ignore: unawaited_futures
        controller.setFlashMode(FlashMode.off);
      }
    } catch (_) {}
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedImage != null) {
      return _buildImagePreview();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview is rendered inside the overlay area (aligned and letterboxed)

          // Loading indicator or error message
          if (!_isCameraInitialized)
            Center(
              child: _errorMessage != null
                  ? _buildErrorScreen()
                  : const CircularProgressIndicator(
                      color: Colors.white,
                    ),
            ),

          // Overlay UI
          if (_isCameraInitialized) _buildOverlay(),

          // Tips modal
          if (_showTips) _buildTipsOverlay(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Top controls and instructions
          _buildTopControls(),

          // Expanded camera area with guide
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_cameraController == null || !_cameraController!.value.isInitialized) {
                  return const SizedBox.shrink();
                }
                final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
                final pvSize = _cameraController!.value.previewSize!; // landscape-oriented values

                if (_useFourThreePreview) {
                  // 4:3 letterboxed preview box (preferred classic photo ratio)
                  const desiredAspect = 4 / 3;
                  final maxW = constraints.maxWidth;
                  final maxH = constraints.maxHeight;
                  double boxW, boxH;
                  if (maxW / maxH > desiredAspect) {
                    boxH = maxH;
                    boxW = boxH * desiredAspect;
                  } else {
                    boxW = maxW;
                    boxH = boxW / desiredAspect;
                  }

                  // Native preview dimensions oriented to current device orientation
                  final nativeW = isPortrait ? pvSize.height : pvSize.width;
                  final nativeH = isPortrait ? pvSize.width : pvSize.height;

                  return Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: boxW,
                      height: boxH,
                      child: Stack(
                        children: [
                          // Tap-to-focus layer + preview
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) => _handleFocusTap(details, Size(boxW, boxH)),
                            child: ClipRect(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: nativeW,
                                  height: nativeH,
                                  child: CameraPreview(_cameraController!),
                                ),
                              ),
                            ),
                          ),
                          // Focus indicator
                          if (_showFocusIndicator && _focusIndicatorPos != null)
                            Positioned(
                              left: _focusIndicatorPos!.dx - 30,
                              top: _focusIndicatorPos!.dy - 30,
                              child: IgnorePointer(
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.yellowAccent, width: 2),
                                  ),
                                ),
                              ),
                            ),
                          // Overlay guide
                          Positioned.fill(
                            child: CustomPaint(
                              painter: CardGuidePainter(
                                borderAnimation: _borderAnimation,
                                pulseAnimation: _pulseAnimation,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  // Native aspect preview (no stretch), orientation-aware using previewSize
                  final effectiveAspect = isPortrait
                      ? (pvSize.height / pvSize.width) // width/height in portrait
                      : (pvSize.width / pvSize.height); // width/height in landscape

                  return Center(
                    child: AspectRatio(
                      aspectRatio: effectiveAspect,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) => _handleFocusTap(details, Size(constraints.maxWidth, constraints.maxHeight)),
                            child: CameraPreview(_cameraController!),
                          ),
                          CustomPaint(
                            painter: CardGuidePainter(
                              borderAnimation: _borderAnimation,
                              pulseAnimation: _pulseAnimation,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),

          // Bottom controls
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Close and flash buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              IconButton(
                onPressed: _toggleFlash,
                icon: Icon(
                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: _isFlashOn ? Colors.yellow : Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Instructions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Align your card within the frame. Use flash in low light.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _showTips = true),
                  child: const Icon(
                    Icons.info_outline,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),

          // Detection failure banner removed (auto-detect disabled)
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left spacer to keep capture centered
          const SizedBox(width: 80, height: 80),
          // Capture button
          GestureDetector(
            onTap: _captureImage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
                color: _isCapturing ? Colors.grey : Colors.transparent,
              ),
              child: _isCapturing
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          // Gallery pick button (right side)
          InkWell(
            onTap: _pickFromGalleryAndCrop,
            borderRadius: BorderRadius.circular(40),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Center(
                child: Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showTips = false),
        child: Container(
          color: Colors.black.withOpacity(0.8),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(40),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scanning Tips',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTip('💡', 'Ensure good lighting'),
                  const SizedBox(height: 12),
                  _buildTip('✨', 'Avoid glare or reflections'),
                  const SizedBox(height: 12),
                  _buildTip('📄', 'Keep the card flat and centered'),
                  const SizedBox(height: 12),
                  _buildTip('🎯', 'Fill the frame with the card'),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => setState(() => _showTips = false),
                    child: Text(
                      'Got it!',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTip(String emoji, String text) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF666666),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image preview
          Center(
            child: Image.file(
              File(_capturedImage!.path),
              fit: BoxFit.contain,
            ),
          ),

          // Top close button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: IconButton(
                onPressed: _retakeImage,
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),

          // Bottom action buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: _adjustCrop,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        icon: const Icon(Icons.crop_rounded),
                        label: Text(
                          'Adjust Crop',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Retake button
                        Expanded(
                          child: Container(
                            height: 50,
                            margin: const EdgeInsets.only(right: 10),
                            child: TextButton(
                              onPressed: _retakeImage,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  side: const BorderSide(color: Colors.white),
                                ),
                              ),
                              child: Text(
                                'Retake',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Use photo button
                        Expanded(
                          child: Container(
                            height: 50,
                            margin: const EdgeInsets.only(left: 10),
                            child: ElevatedButton(
                              onPressed: _useImage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: Text(
                                'Use Photo',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            size: 80,
            color: Colors.white54,
          ),
          const SizedBox(height: 24),
          Text(
            'Camera Not Available',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Unable to access camera',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white70,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
            child: Text(
              'Go Back',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _isCameraInitialized = false;
              });
              _initializeCamera();
            },
            child: Text(
              'Try Again',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _pickImageFromGallery,
            child: Text(
              'Pick from Gallery',
              style: GoogleFonts.inter(
                color: const Color(0xFF007AFF),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null && mounted) {
        Navigator.of(context).pop(result.files.single.path!);
      }
    } catch (e) {
      debugPrint('Gallery pick failed: $e');
    }
  }

  Future<void> _pickFromGalleryAndCrop() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      final path = result?.files.single.path;
      if (path == null) return;
      // Crop flow same as capture — open cropper inline
      final edited = await _openCropper(path);
      if (!mounted) return;
      final chosen = edited ?? path;
      if (!File(chosen).existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected image not found.')),
        );
        return;
      }
      setState(() {
        _capturedImage = XFile(chosen);
      });
    } catch (e) {
      debugPrint('Gallery pick/crop failed: $e');
    }
  }

  // Open the native/ImageCropper UI directly without a wrapper route.
  Future<String?> _openCropper(String path) async {
    try {
      final cropper = ImageCropper();
      final CroppedFile? cropped = await cropper.cropImage(
        sourcePath: path,
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
      return cropped?.path;
    } catch (e) {
      debugPrint('Cropper error: $e');
      return null;
    }
  }
}

// Custom painter for the card guide overlay
class CardGuidePainter extends CustomPainter {
  final Animation<double> borderAnimation;
  final Animation<double> pulseAnimation;

  CardGuidePainter({
    required this.borderAnimation,
    required this.pulseAnimation,
  }) : super(repaint: borderAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Card dimensions (3.5:2 aspect ratio), using preview size (size is preview box)
    const cardAspectRatio = 3.5 / 2.0;
    // Keep guide within the preview box with consistent margins
    final maxGuideWidth = size.width * 0.85;
    final tentativeHeight = maxGuideWidth / cardAspectRatio;
    final maxGuideHeight = size.height * 0.6;
    double cardWidth = maxGuideWidth;
    double cardHeight = tentativeHeight;
    if (tentativeHeight > maxGuideHeight) {
      cardHeight = maxGuideHeight;
      cardWidth = cardHeight * cardAspectRatio;
    }

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: cardWidth,
        height: cardHeight,
      ),
      const Radius.circular(12),
    );

    // Semi-transparent overlay (everything except the card area)
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cardRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(overlayPath, overlayPaint);

    // Animated dashed border
    _drawAnimatedBorder(canvas, cardRect);

    // Glowing edge effect
    _drawGlowingEdge(canvas, cardRect);
  }

  void _drawAnimatedBorder(Canvas canvas, RRect cardRect) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()..addRRect(cardRect);
    final pathMetrics = path.computeMetrics();

    for (final pathMetric in pathMetrics) {
      final totalLength = pathMetric.length;
      final dashLength = 10.0;
      final gapLength = 8.0;
      final segmentLength = dashLength + gapLength;

      // Animate the dash offset
      final animatedOffset = borderAnimation.value * segmentLength;

      for (double distance = -animatedOffset;
          distance < totalLength;
          distance += segmentLength) {
        final startDistance = distance.clamp(0.0, totalLength);
        final endDistance = (distance + dashLength).clamp(0.0, totalLength);

        if (startDistance < endDistance) {
          final extractPath = pathMetric.extractPath(
            startDistance,
            endDistance,
          );
          canvas.drawPath(extractPath, paint);
        }
      }
    }
  }

  void _drawGlowingEdge(Canvas canvas, RRect cardRect) {
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(pulseAnimation.value * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);

    canvas.drawRRect(cardRect, glowPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}