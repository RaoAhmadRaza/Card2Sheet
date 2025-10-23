import 'dart:io';
import 'package:flutter/material.dart';
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
  late Animation<double> _progressAnimation;
  
  int _currentStep = 0;
  final List<ProcessingStep> _steps = [
    ProcessingStep('Extracting text...', false),
    ProcessingStep('Structuring data with AI...', false),
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
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
    
    _startProcessing();
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
      
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Step 2: Structuring data (simulate AI processing)
      await Future.delayed(const Duration(milliseconds: 1200));
      
      setState(() {
        _steps[1] = ProcessingStep('Structuring data with AI...', true);
      });
      
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Navigate to results
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TextResultScreen(
              imagePath: widget.imagePath,
              extractedText: extractedText,
            ),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
              Column(
                children: [
                  // Progress bar
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      color: Colors.black.withOpacity(0.08),
                    ),
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progressAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1),
                              color: Colors.black,
                            ),
                          ),
                        );
                      },
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
              
              const SizedBox(height: 56),
              
              // Processing steps
              Column(
                children: _steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;
                  final isActive = index == _currentStep;
                  final isCompleted = step.isCompleted;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      children: [
                        // Step icon
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted 
                                ? Colors.black
                                : isActive 
                                    ? Colors.black.withOpacity(0.15)
                                    : Colors.black.withOpacity(0.06),
                          ),
                          child: isCompleted
                              ? Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                )
                              : isActive
                                  ? Container(
                                      padding: const EdgeInsets.all(3),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.black.withOpacity(0.4),
                                        ),
                                      ),
                                    )
                                  : null,
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
                  );
                }).toList(),
              ),
              
              const Spacer(flex: 4),
            ],
          ),
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