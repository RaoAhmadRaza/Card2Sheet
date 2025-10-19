import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/routes.dart';
import '../../core/preferences.dart';

class CsvUploadScreen extends StatefulWidget {
  const CsvUploadScreen({super.key});

  @override
  State<CsvUploadScreen> createState() => _CsvUploadScreenState();
}

class _CsvUploadScreenState extends State<CsvUploadScreen> {
  bool _isUploading = false;

  Future<void> _pickFile(BuildContext context) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        // Copy the picked file into the app's documents directory
        final pickedPath = result.files.single.path!;
        final pickedFile = File(pickedPath);
        final ext = pickedPath.toLowerCase().endsWith('.xlsx') ? 'xlsx' : 'csv';
        final docsDir = await getApplicationDocumentsDirectory();
        final target = File('${docsDir.path}/template_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await pickedFile.copy(target.path);
        // Persist last sheet path for quick open
        await Preferences.setLastSheetPath(target.path);

        // Navigate to home
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        }
      }
    } catch (e) {
      // Handle error if needed
      print('Error picking file: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _onSkipPressed() async {
    // If user already chose a default format before, just proceed.
    final existing = await Preferences.getDefaultFormat();
    if (existing != null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      return;
    }

    if (!mounted) return;
    final choice = await showCupertinoModalPopup<DefaultExportFormat>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Choose default export format'),
        message: const Text('We\'ll remember this choice for future exports.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(DefaultExportFormat.csv),
            child: const Text('CSV (.csv)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(DefaultExportFormat.xlsx),
            child: const Text('Excel (.xlsx)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (choice != null) {
      await Preferences.setDefaultFormat(choice);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(
        255,
        255,
        255,
        255,
      ), // iOS light gray background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Template Setup',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1D1D1F),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hero Card
              
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lottie Animation in Card
                    Lottie.network(
                      'https://lottie.host/c77d7165-6254-445c-9119-fd12acefe1d5/JBBG3fA3mQ.json',
                      height: 250,
                      width: 250,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.file_upload_outlined,
                          size: 40,
                          color: Color(0xFF007AFF),
                        );
                      },
                    ),

                    Text(
                      'Upload Your Template',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D1D1F),
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Customize how your scanned business cards are organized by uploading a template file(.csv or .xlsx).',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF86868B),
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Upload Button
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(
                        255,
                        15,
                        15,
                        16,
                      ).withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                    onPressed: _isUploading ? () {} : () => _pickFile(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      disabledBackgroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Color.fromARGB(255, 0, 0, 0),
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.cloud_upload_outlined,
                                color: Color(0xFF007AFF),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Choose Template File',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

              const SizedBox(height: 16),

              // Skip Button
              Container(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: _onSkipPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Skip - Use Default Template',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 150),
            ],
          ),
        ),
      ),
    );
  }
}
