import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

class SuccessScreen extends StatefulWidget {
  final String? filePath;
  final String? type; // 'csv' | 'xlsx'

  const SuccessScreen({super.key, this.filePath, this.type});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  @override
  void initState() {
    super.initState();
    // Subtle success haptic
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath?.split('/').last ?? 
        (widget.type == 'csv' ? 'BusinessCards.csv' : 'BusinessCards.xlsx');

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // systemGroupedBackground
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title
                  const Text(
                    'Exported Data',
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // File card
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Document icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.description,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Filename
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            fileName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: '.SF Pro Text',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1D1D1F),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Open with button
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Open the file with system default app
                        if (widget.filePath != null) {
                          HapticFeedback.lightImpact();
                          try {
                            final result = await OpenFilex.open(widget.filePath!);
                            if (result.type != ResultType.done) {
                              // If opening fails, show a message
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Unable to open file: ${result.message}'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error opening file: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        } else {
                          HapticFeedback.lightImpact();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B), // Coral/salmon color
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Open with...',
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Description text
                  const Text(
                    'Your file updates automatically with every new scan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Done button (subtle)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontFamily: '.SF Pro Text',
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF007AFF), // iOS blue
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
}
