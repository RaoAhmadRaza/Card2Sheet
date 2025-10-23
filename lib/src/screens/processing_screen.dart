import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:card2sheet/src/services/ocr_service.dart';
import 'text_result_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final String imagePath;
  const ProcessingScreen({super.key, required this.imagePath});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
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
  late Animation<double> _blurAnimation;
  
  int _currentStep = 0;
  bool _isCompleting = false;
  List<ProcessingStep> _steps = [
    const ProcessingStep('Analyzing image...', false),
    const ProcessingStep('Extracting text...', false),
    const ProcessingStep('Finalizing results...', false),
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2800),
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
    _blurAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInOut,
      ),
    );
    
    _startProcessing();
    _pulseController.repeat(reverse: true);
    _fadeController.forward();
  }

  Future<void> _startProcessing() async {
    // Start progress animation
    _progressController.forward();
    
    // Step 1: Extracting text
    setState(() {
      _currentStep = 0;
    });
    
    await Future.delayed(const Duration(milliseconds: 800));
    
    try {
      // Actually extract text
      final svc = OCRService();
      final extractedText = await svc.extractTextFromImage(File(widget.imagePath));
      
      // Mark step 1 complete
      setState(() {
        _steps[0] = ProcessingStep('Extracting text...', true);
        _currentStep = 1;
      });
      
      // Light haptic for step completion
      HapticFeedback.selectionClick();
      
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Step 2: Structuring data (simulate AI processing)
      await Future.delayed(const Duration(milliseconds: 1200));
      
      setState(() {
        _steps[1] = ProcessingStep('Structuring data with AI...', true);
        _currentStep = 2;
      });
      
      // Light haptic for step completion
      HapticFeedback.selectionClick();
      
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Complete final step
      setState(() {
        _steps[2] = ProcessingStep('Complete!', true);
        _isCompleting = true;
      });
      
      // Haptic feedback at 100%
      HapticFeedback.lightImpact();
      
      // Wait for completion pause
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Start exit animation with blur
      if (mounted) {
        _exitController.forward();
        
        // Wait for exit animation to complete
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Navigate to results
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => TextResultScreen(
              imagePath: widget.imagePath,
              extractedText: extractedText,
            ),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing failed: $e')),
        );
        Navigator.of(context).pop();
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
              // Main content with fade and blur
              AnimatedBuilder(
                animation: _exitFadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _exitFadeAnimation.value,
                    child: AnimatedBuilder(
                      animation: _blurAnimation,
                      builder: (context, child) {
                        return BackdropFilter(
                          filter: ui.ImageFilter.blur(
                            sigmaX: _blurAnimation.value,
                            sigmaY: _blurAnimation.value,
                          ),
                          child: _buildMainContent(),
                        );
                      },
                    ),
                  );
                },
              ),
              
              // Processing blur overlay with subtle animation
              if (_currentStep >= 0 && !_isCompleting)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: 2.5 + (_pulseAnimation.value * 0.5),
                        sigmaY: 2.5 + (_pulseAnimation.value * 0.5),
                      ),
                      child: Container(
                        color: Colors.white.withOpacity(0.05 + (_pulseAnimation.value * 0.05)),
                      ),
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
                          return LinearProgressIndicator(
                            value: _progressAnimation.value,
                            backgroundColor: Colors.black.withOpacity(0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                            minHeight: 5,
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Text(
                        '${(_progressAnimation.value * 100).round()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.5),
                          letterSpacing: 0.1,
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
                                    duration: const Duration(milliseconds: 400),
                                    child: Container(
                                      key: ValueKey('step_${index}_${isCompleted}_$isActive'),
                                      height: 32,
                                      width: 32,
                                      decoration: BoxDecoration(
                                        color: isCompleted ? Colors.black : Colors.transparent,
                                        border: Border.all(
                                          color: isCompleted 
                                              ? Colors.black 
                                              : isActive 
                                                  ? Colors.black.withOpacity(0.4)
                                                  : Colors.black.withOpacity(0.2),
                                          width: isCompleted ? 0 : 1.5,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: isCompleted
                                          ? Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 16,
                                              weight: 600,
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
                                      duration: const Duration(milliseconds: 300),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        color: isCompleted || isActive 
                                            ? Colors.black.withOpacity(0.8)
                                            : Colors.black.withOpacity(0.4),
                                        letterSpacing: -0.2,
                                        height: 1.3,
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