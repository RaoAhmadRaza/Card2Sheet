import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/routes.dart';
import '../../core/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CsvUploadScreen extends StatefulWidget {
  const CsvUploadScreen({super.key});

  @override
  State<CsvUploadScreen> createState() => _CsvUploadScreenState();
}

class _CsvUploadScreenState extends State<CsvUploadScreen> {
  bool _isUploading = false;

  Future<void> _setSpreadsheetSelection({
    required String path,
    required String type, // 'csv' | 'xlsx'
    String sheet = 'Sheet1',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('spreadsheet_path', path);
      await prefs.setString('spreadsheet_type', type);
      await prefs.setString('spreadsheet_sheet', sheet);
    } catch (_) {}
  }

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
        // Also persist selection for save flow to bypass popup
        await _setSpreadsheetSelection(path: target.path, type: ext, sheet: 'Sheet1');

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

      // Persist a default spreadsheet selection in app documents dir
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final isCsv = choice == DefaultExportFormat.csv;
        final defaultPath = '${docsDir.path}/Card2Sheet_Default.${isCsv ? 'csv' : 'xlsx'}';
        await _setSpreadsheetSelection(
          path: defaultPath,
          type: isCsv ? 'csv' : 'xlsx',
          sheet: 'Sheet1',
        );
        // Store last path as well for consistency
        await Preferences.setLastSheetPath(defaultPath);
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Color(0xFFF9F9FA),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9F9FA), Color(0xFFF2F2F7)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.network(
                        'https://lottie.host/c77d7165-6254-445c-9119-fd12acefe1d5/JBBG3fA3mQ.json',
                        height: 250,
                        width: 250,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.file_upload_outlined,
                            size: 40,
                            color: Color(0xFF1D1D1F),
                          );
                        },
                      ),
                      Text(
                        'Upload Your Template',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D1D1F),
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
                          color: Color(0xFF1D1D1F).withValues(alpha: 0.6),
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 30,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : () => _pickFile(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1D1D1F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        disabledBackgroundColor: Color(0xFF1D1D1F),
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        overlayColor: Color(0xFF2C2C2E),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.cloud_upload_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Choose Template File',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: _onSkipPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: Color(0xFF1D1D1F),
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
      ),
    );
  }
}
