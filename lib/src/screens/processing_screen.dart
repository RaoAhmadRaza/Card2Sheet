import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:card2sheet/src/services/ocr_service.dart';
import 'package:card2sheet/src/services/ai_processing_service.dart';
import 'structured_result_screen.dart';
import '../models/scan_result.dart';
import '../providers/scan_result_provider.dart';
import '../services/analytics_service.dart';

enum RecoveryAction { retry, fallback, dismiss }

class ProcessingScreen extends ConsumerStatefulWidget {
  final String imagePath;
  const ProcessingScreen({super.key, required this.imagePath});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _stepController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _exitController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _exitFadeAnimation;
  
  int _currentStep = 0;
  bool _isCompleting = false;
  bool _progressComplete = false;
  List<ProcessingStep> _steps = [
    const ProcessingStep('Extracting text...', false),
    const ProcessingStep('Structuring data with AI...', false),
    const ProcessingStep('Finalizing results...', false),
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );
    _stepController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController, 
        curve: Curves.easeOutCubic,
      ),
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutQuart,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutCubic,
      ),
    );
    _exitFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInCubic,
      ),
    );
    
    // Schedule processing after first frame to avoid mutating providers during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startProcessing();
    });
    _pulseController.repeat(reverse: true);
    _fadeController.forward();
  }

  Future<void> _startProcessing() async {
  // Initialize progress at 0; progress advances only after each step completes.
    // Reset any previous result
  ref.read(scanResultProvider.notifier).clear();
    ref.read(analyticsProvider).track('scan_started');
    
    // Step 1: Extracting text
    setState(() {
      _currentStep = 0;
    });
    
  await Future.delayed(const Duration(milliseconds: 800));
    
  try {
      // Actually extract text
      final svc = OCRService();
      // Guard against device stalls: time out OCR after 20s
      String extractedText;
      try {
        extractedText = await svc
            .extractTextFromImage(File(widget.imagePath))
            .timeout(const Duration(seconds: 20));
      } on TimeoutException {
        // Specific OCR timeout handling: offer retry or skip OCR
        if (!mounted) return;
        final action = await _showOcrRecoveryDialog();
        if (action == RecoveryAction.retry) {
          extractedText = await svc
              .extractTextFromImage(File(widget.imagePath))
              .timeout(const Duration(seconds: 20));
        } else if (action == RecoveryAction.fallback) {
          extractedText = '';
        } else {
          rethrow;
        }
      }
      
      // Mark step 1 (OCR) complete and advance progress to ~33%
      setState(() {
        _steps[0] = const ProcessingStep('Extracting text...', true);
        _currentStep = 1;
      });
      await _advanceProgressTo(1 / 3);
      
      // Light haptic for step completion
      HapticFeedback.selectionClick();
      
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Step 2 & 3: Call backend to structure and finalize
      setState(() {
        _currentStep = 1; // now processing/structuring
      });

    final aiSvc = AIProcessingService();
    // If proxy/API key are not configured, this returns fast; otherwise cap to 25s
    AIProcessingResult result;
    try {
      result = await aiSvc
          .processOcrText(extractedText)
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      // Network/proxy error: present a recovery UI and act based on selection
      if (!mounted) return;
      final action = await _showConnectivityRecoveryDialog(error: e.toString());
      if (action == RecoveryAction.fallback) {
        result = AIProcessingResult(
          cleanedText: extractedText,
          structuredJson: const {},
          finalJson: const {},
        );
      } else if (action == RecoveryAction.retry) {
        // Try once more
        result = await aiSvc
            .processOcrText(extractedText)
            .timeout(const Duration(seconds: 25));
      } else {
        rethrow;
      }
    }

      // Mark structuring complete and advance progress to ~66%
      setState(() {
        _steps[1] = const ProcessingStep('Structuring data with AI...', true);
        _currentStep = 2; // finalizing
      });
      await _advanceProgressTo(2 / 3);

      // Light haptic for step completion
      HapticFeedback.selectionClick();

      // Complete final step and advance progress to 100%
      setState(() {
        _steps[2] = const ProcessingStep('Finalizing results...', true);
        _isCompleting = true;
        _progressComplete = true;
      });
      await _advanceProgressTo(1.0);

      // Haptic feedback at 100%
      HapticFeedback.lightImpact();

      // Wait for completion pause
      await Future.delayed(const Duration(milliseconds: 400));

      // Transition to results
      if (mounted) {
        _exitController.forward();
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Always navigate to the StructuredResultScreen. If AI output is empty
        // (e.g., no API key/proxy configured), derive a minimal structured map
        // so the new screen still appears instead of the legacy text screen.
        final structured = result.finalJson.isNotEmpty
            ? result.finalJson
            : _deriveFallbackStructuredData(
                result.cleanedText.isNotEmpty ? result.cleanedText : extractedText,
              );

    // Persist structured result via provider so the next screen can read it
    final sr = ScanResult(rawText: result.cleanedText.isNotEmpty ? result.cleanedText : extractedText,
      structured: Map<String, String>.from(structured.map((k, v) => MapEntry(k, v?.toString() ?? ''))));
    // Avoid writing to history here; history is recorded atomically on export
    await ref.read(scanResultProvider.notifier).setResult(sr, persist: false);
    ref.read(analyticsProvider).track('scan_completed');

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const StructuredResultScreen(),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
  } on TimeoutException {
      // Safety net: if OCR/AI hangs on some devices, fail soft and return
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Processing timed out. Please try again.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      // Handle error
      if (mounted) {
        await _showErrorWithActions(message: _mapBackendError(e.toString()));
        Navigator.of(context).pop();
      }
    }
  }

  

  String _mapBackendError(String raw) {
    // Map common backend statuses to friendly messages
    if (raw.contains('429') || raw.toLowerCase().contains('rate')) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (raw.contains('402') || raw.toLowerCase().contains('quota')) {
      return 'Monthly quota exceeded. Try again later or adjust usage.';
    }
    if (raw.contains('401') || raw.toLowerCase().contains('signature')) {
      return 'Secure connection validation failed. Please retry.';
    }
    if (raw.toLowerCase().contains('timeout')) {
      return 'The request timed out. Check your internet connection and try again.';
    }
    return 'Processing failed. Check your connection and try again.';
  }

  Future<RecoveryAction> _showConnectivityRecoveryDialog({required String error}) async {
    final result = await showDialog<RecoveryAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Connection Issue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  _mapBackendError(error),
                  style: TextStyle(color: Colors.black.withOpacity(0.7)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(RecoveryAction.retry);
                        },
                        child: const Text('Retry'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(RecoveryAction.fallback);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D1D1F),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Use Basic Extraction'),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
    return result ?? RecoveryAction.dismiss;
  }

  Future<RecoveryAction> _showOcrRecoveryDialog() async {
    return showDialog<RecoveryAction>(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OCR taking longer than expected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      'This can happen on first run while the on-device OCR model downloads. You can retry or continue without OCR.',
                      style: TextStyle(color: Colors.black.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(RecoveryAction.retry),
                            child: const Text('Retry OCR'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(RecoveryAction.fallback),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D1D1F),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Skip for now'),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ).then((v) => v ?? RecoveryAction.dismiss);
  }

  Future<void> _showErrorWithActions({required String message}) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFF2F2F7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(60, 60, 67, 0.3),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Dismiss'),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // Derive a minimal structured map from raw text when AI output is unavailable.
  // This keeps UX consistent by always showing the StructuredResultScreen.
  Map<String, dynamic> _deriveFallbackStructuredData(String text) {
    final map = <String, dynamic>{};
    final lines = text.split(RegExp(r"[\r\n]+")).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // Email
    final emailMatch = RegExp(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}").firstMatch(text);
    if (emailMatch != null) map['email'] = emailMatch.group(0);

    // Phone (loose)
    final phoneMatch = RegExp(r"(?:(?:\+|00)\d{1,3}[\s-]?)?(?:\(?\d{2,4}\)?[\s-]?)?\d[\d\s-]{6,}\d").firstMatch(text);
    if (phoneMatch != null) map['phone'] = phoneMatch.group(0);

    // Website
    final urlMatch = RegExp(r"(?:(?:https?:\/\/)?(?:www\.)?[A-Za-z0-9.-]+\.[A-Za-z]{2,})(?:\/[\w\-._~:\/?#\[\]@!$&'()*+,;=%]*)?").firstMatch(text);
    if (urlMatch != null) {
      var v = urlMatch.group(0) ?? '';
      v = v.replaceAll(RegExp(r"\s"), '');
      map['website'] = v;
    }

    // Name heuristic: first uppercase-dominant line without digits/@ and not looking like a URL
    String? candidateName;
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (RegExp(r"[@\d]").hasMatch(line)) continue;
      if (lower.contains('www') || lower.contains('http')) continue;
      // Prefer lines with 2-4 words capitalized
      final words = line.split(RegExp(r"\s+")).where((w) => w.isNotEmpty).toList();
      if (words.length >= 1 && words.length <= 5) {
        final capped = words.where((w) => w.isNotEmpty && w[0].toUpperCase() == w[0]).length;
        if (capped >= (words.length / 2)) {
          candidateName = line;
          break;
        }
      }
    }
    if (candidateName != null) map['name'] = candidateName;

    // Title: any line with role keywords
    final titleLine = lines.firstWhere(
      (l) => RegExp(r"manager|director|engineer|designer|developer|lead|sales|marketing|officer|consultant",
              caseSensitive: false)
          .hasMatch(l),
      orElse: () => '',
    );
    if (titleLine.isNotEmpty) map['title'] = titleLine;

    return map;
  }

  Future<void> _advanceProgressTo(double target) async {
    final clamped = target.clamp(0.0, 1.0);
    if (_progressController.value < clamped) {
      try {
        await _progressController.animateTo(
          clamped,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {
        // ignore if animation cancelled due to dispose/navigation
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _stepController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: AnimatedBuilder(
        animation: _exitController,
        builder: (context, child) {
          return Stack(
            children: [
              // Main content with fade
              AnimatedBuilder(
                animation: _exitFadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _exitFadeAnimation.value,
                    child: _buildMainContent(),
                  );
                },
              ),
              
              // Completion overlay
              if (_isCompleting)
                Container(
                  color: Colors.black.withOpacity(0.05),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          children: [
            const Spacer(flex: 3),
            
            // Title
            Text(
              'Processing',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                letterSpacing: -0.4,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              'Extracting text from your image',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: Colors.black.withOpacity(0.6),
                letterSpacing: -0.2,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 64),
            
            // Progress section
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Progress bar
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                            child: Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(2.5),
                                  ),
                                ),
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _progressAnimation.value,
                                  child: Container(
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(2.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      final progress = _progressAnimation.value;
                      final displayProgress = _progressComplete ? 100 : (progress * 100).round();
                      return Text(
                        '$displayProgress%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.5),
                          letterSpacing: 0.1,
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Friendly microcopy
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      String microcopy = "Preparing your document...";
                      if (_progressAnimation.value > 0.3) {
                        microcopy = "Hang tight — your document is being polished by AI 🤖";
                      }
                      if (_progressComplete) {
                        microcopy = "All done! ✨";
                      }
                      
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          microcopy,
                          key: ValueKey(microcopy),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.black.withOpacity(0.4),
                            letterSpacing: 0.1,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 56),
            
            // Processing steps
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: _steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    final isActive = index == _currentStep;
                    final isCompleted = step.isCompleted;
                    
                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 400 + (index * 100)),
                      tween: Tween<double>(
                        begin: 0.0,
                        end: _currentStep >= index ? 1.0 : 0.3,
                      ),
                      curve: Curves.easeOutCubic,
                      builder: (context, opacity, child) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          margin: EdgeInsets.symmetric(
                            vertical: 12.0,
                            horizontal: _currentStep >= index ? 0.0 : 8.0,
                          ),
                          child: Opacity(
                            opacity: opacity,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  // Step icon
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 600),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: animation,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      key: ValueKey('step_${index}_${isCompleted}_$isActive'),
                                      height: 32,
                                      width: 32,
                                      decoration: BoxDecoration(
                                        color: isCompleted ? Colors.black.withOpacity(0.6) : Colors.transparent,
                                        border: Border.all(
                                          color: isCompleted 
                                              ? Colors.black.withOpacity(0.6)
                                              : isActive 
                                                  ? Colors.black.withOpacity(0.4)
                                                  : Colors.black.withOpacity(0.2),
                                          width: isCompleted ? 0 : 1.5,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: isCompleted
                                          ? TweenAnimationBuilder<double>(
                                              duration: const Duration(milliseconds: 400),
                                              tween: Tween(begin: 0.0, end: 1.0),
                                              curve: Curves.easeOutBack,
                                              builder: (context, value, child) {
                                                return Transform.scale(
                                                  scale: value,
                                                  child: Icon(
                                                    Icons.check_rounded,
                                                    color: Colors.white,
                                                    size: 16,
                                                    weight: 600,
                                                  ),
                                                );
                                              },
                                            )
                                          : isActive
                                              ? AnimatedBuilder(
                                                  animation: _pulseAnimation,
                                                  builder: (context, child) {
                                                    return Container(
                                                      margin: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withOpacity(_pulseAnimation.value),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : null,
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 16),
                                  
                                  // Step text
                                  Expanded(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 400),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        color: isCompleted 
                                            ? Colors.black.withOpacity(0.4) // Dimmed completed steps
                                            : isActive 
                                                ? Colors.black.withOpacity(0.8) // Highlighted active step
                                                : Colors.black.withOpacity(0.3), // Pending steps
                                        letterSpacing: -0.2,
                                        height: 1.3,
                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                        decorationColor: Colors.black.withOpacity(0.2),
                                      ),
                                      child: Text(step.title),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            
            const Spacer(flex: 4),
          ],
        ),
      ),
    );
  }
}

class ProcessingStep {
  final String title;
  final bool isCompleted;
  
  const ProcessingStep(this.title, this.isCompleted);
}