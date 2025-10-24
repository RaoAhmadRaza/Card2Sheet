import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/routes.dart';
import '../../core/preferences.dart';
import 'dart:math' as math;

class SuccessScreen extends StatefulWidget {
  final String? filePath;
  final String? type; // 'csv' | 'xlsx'

  const SuccessScreen({super.key, this.filePath, this.type});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _titleOpacity;
  late Animation<double> _titleScale;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _cardOpacity;
  late Animation<Offset> _cardOffset;
  late Animation<double> _cardScale;
  late Animation<double> _checkmarkOpacity;
  late Animation<double> _checkmarkScale;
  late AnimationController _confettiController;
  late List<ConfettiParticle> _confettiParticles;
  late Animation<double> _buttonsOpacity;
  late Animation<double> _footerOpacity;

  @override
  void initState() {
    super.initState();
    // Subtle success haptic
    HapticFeedback.heavyImpact();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Title animations (starts immediately)
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    
    _titleScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    
    // Subtitle animation (staggered after title)
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    
    // Card animations (fade + upward lift)
    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    
    _cardOffset = Tween<Offset>(
      begin: const Offset(0, 20),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    
    // Card scale with subtle bounce
    _cardScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );
    
    // Checkmark animations (appears after card)
    _checkmarkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.6, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    
    _checkmarkScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.6, 0.9, curve: Curves.elasticOut),
      ),
    );
    
    // Button animations (appear after checkmark)
    _buttonsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    
    // Footer text animation (300ms delay after buttons start)
    _footerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.8, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    
    // Confetti controller
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // Initialize confetti particles
    _confettiParticles = List.generate(6, (index) {
      final random = math.Random();
      return ConfettiParticle(
        x: 200 + (random.nextDouble() - 0.5) * 100, // Around card center
        y: 200 + (random.nextDouble() - 0.5) * 50,
        vx: (random.nextDouble() - 0.5) * 3,
        vy: -random.nextDouble() * 3 - 2,
        opacity: 1.0,
        size: random.nextDouble() * 3 + 2,
        color: Color.lerp(
          const Color(0xFFE5E5EA),
          const Color(0xFFF2F2F7),
          random.nextDouble(),
        )!,
      );
    });
    
    // Start the main animation
    _animationController.forward();
    
    // Start confetti animation after a delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _confettiController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath?.split('/').last ?? 
        (widget.type == 'csv' ? 'BusinessCards.csv' : 'BusinessCards.xlsx');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF9F9FA), // Very subtle lighter top
              Color(0xFFF2F2F7), // systemGroupedBackground bottom
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main content
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title with animation
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _titleOpacity.value,
                        child: Transform.scale(
                          scale: _titleScale.value,
                          child: const Text(
                            'Export Complete',
                            style: TextStyle(
                              fontFamily: '.SF Pro Text',
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              color: Color(0xFF1D1D1F),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  
                  // Subtitle with staggered animation
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _subtitleOpacity.value,
                        child: Text(
                          'Your data file is ready to view.',
                          style: TextStyle(
                            fontFamily: '.SF Pro Text',
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.2,
                            color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                  
                  // File card with animation
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _cardOpacity.value,
                        child: Transform.translate(
                          offset: _cardOffset.value,
                          child: Transform.scale(
                            scale: _cardScale.value,
                            child: Container(
                              width: 215,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 30,
                                    offset: const Offset(0, 8),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Animated checkmark circle
                                  AnimatedBuilder(
                                    animation: _animationController,
                                    builder: (context, child) {
                                      return Opacity(
                                        opacity: _checkmarkOpacity.value,
                                        child: Transform.scale(
                                          scale: _checkmarkScale.value,
                                          child: Container(
                                            width: 80,
                                            height: 80,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF000000),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 40,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
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
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Open with button with fade animation
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _buttonsOpacity.value,
                        child: _OpenFileButton(
                          onPressed: _openFileLikeHomeScreen,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Description text with fade animation
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _footerOpacity.value,
                        child: Text(
                          'Any new scans will be added automatically.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: '.SF Pro Text',
                            fontSize: 13, // Smaller size
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF8E8E93).withValues(alpha: 0.55), // Reduced opacity
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  
                  // Done button with fade animation
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _buttonsOpacity.value,
                        child: TextButton(
                          onPressed: () {
                            // Pop all and go to Home using named route
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              AppRoutes.home,
                              (route) => false,
                            );
                          },
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              fontFamily: '.SF Pro Text',
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF1D1D1F), // Updated SF Blue
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          ),
              
              // Confetti overlay (non-interactive)
              IgnorePointer(
                ignoring: true,
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, child) {
                    // Update particle positions
                    for (var particle in _confettiParticles) {
                      particle.update();
                    }
                    
                    return CustomPaint(
                      size: MediaQuery.of(context).size,
                      painter: ConfettiPainter(_confettiParticles),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFileLikeHomeScreen() async {
    HapticFeedback.lightImpact();
    try {
      // 1) Prefer the file from this success context if available
      final path = widget.filePath;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final isCsv = path.toLowerCase().endsWith('.csv');
          final mime = isCsv
              ? 'text/csv'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          final res = await OpenFilex.open(path, type: mime);
          if (res.type != ResultType.done) {
            _showSnack('Could not open file (code: ${res.type.name})');
          }
          return;
        }
      }

      // 2) Try last saved/uploaded path from preferences
      final lastPath = await Preferences.getLastSheetPath();
      if (lastPath != null) {
        final file = File(lastPath);
        if (await file.exists()) {
          final isCsv = lastPath.toLowerCase().endsWith('.csv');
          final mime = isCsv
              ? 'text/csv'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          final res = await OpenFilex.open(lastPath, type: mime);
          if (res.type != ResultType.done) {
            _showSnack('Could not open file (code: ${res.type.name})');
          }
          return;
        }
      }

      // 3) Fallback: scan app documents directory for latest csv/xlsx
      final dir = await getApplicationDocumentsDirectory();
      final directory = Directory(dir.path);
      if (!await directory.exists()) {
        _showSnack('No saved files found');
        return;
      }

      final files = await directory
          .list()
          .where((e) => e is File && (e.path.endsWith('.csv') || e.path.endsWith('.xlsx')))
          .cast<File>()
          .toList();

      if (files.isEmpty) {
        _showSnack('No CSV or Excel files found');
        return;
      }

      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final latest = files.first;

      final isCsv = latest.path.toLowerCase().endsWith('.csv');
      final mime = isCsv
          ? 'text/csv'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      final result = await OpenFilex.open(latest.path, type: mime);
      if (result.type != ResultType.done) {
        _showSnack('Could not open file (code: ${result.type.name})');
      }
    } catch (e) {
      _showSnack('Failed to open file');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// Custom open file button with scale animation
class _OpenFileButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _OpenFileButton({required this.onPressed});

  @override
  State<_OpenFileButton> createState() => _OpenFileButtonState();
}

class _OpenFileButtonState extends State<_OpenFileButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Listener(
            onPointerDown: (_) => _scaleController.forward(),
            onPointerUp: (_) => _scaleController.reverse(),
            onPointerCancel: (_) => _scaleController.reverse(),
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D1D1F), // Monochrome black
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28), // Fully rounded pill
                  ),
                  overlayColor: const Color(0xFF2C2C2E), // Pressed color
                ),
                child: const Text(
                  'Open File',
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Custom painter for minimalist document icon (SF Symbol style)
class DocumentIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    
    // Document body (rounded rectangle)
    final docRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.2,
        size.height * 0.15,
        size.width * 0.6,
        size.height * 0.7,
      ),
      const Radius.circular(3),
    );
    
    // Document folded corner
    final cornerSize = size.width * 0.12;
    final cornerPath = Path()
      ..moveTo(docRect.right - cornerSize, docRect.top)
      ..lineTo(docRect.right, docRect.top + cornerSize)
      ..lineTo(docRect.right - cornerSize, docRect.top + cornerSize)
      ..close();
    
    // Draw document body
    canvas.drawRRect(docRect, paint);
    
    // Draw folded corner
    canvas.drawPath(cornerPath, paint);
    
    // Draw corner fold line
    canvas.drawLine(
      Offset(docRect.right - cornerSize, docRect.top),
      Offset(docRect.right - cornerSize, docRect.top + cornerSize),
      strokePaint..strokeWidth = 1.0..color = Colors.white.withValues(alpha: 0.3),
    );
    
    // Draw text lines
    final lineY1 = docRect.top + size.height * 0.25;
    final lineY2 = docRect.top + size.height * 0.35;
    final lineY3 = docRect.top + size.height * 0.45;
    
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    
    // First line (longest)
    canvas.drawLine(
      Offset(docRect.left + size.width * 0.08, lineY1),
      Offset(docRect.right - size.width * 0.15, lineY1),
      linePaint,
    );
    
    // Second line (medium)
    canvas.drawLine(
      Offset(docRect.left + size.width * 0.08, lineY2),
      Offset(docRect.right - size.width * 0.2, lineY2),
      linePaint,
    );
    
    // Third line (short)
    canvas.drawLine(
      Offset(docRect.left + size.width * 0.08, lineY3),
      Offset(docRect.right - size.width * 0.3, lineY3),
      linePaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Confetti particle class for animation
class ConfettiParticle {
  late double x;
  late double y;
  late double vx;
  late double vy;
  late double opacity;
  late double size;
  late Color color;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.opacity,
    required this.size,
    required this.color,
  });

  void update() {
    x += vx;
    y += vy;
    vy += 0.5; // gravity
    opacity = math.max(0, opacity - 0.02);
  }
}

// Custom painter for confetti particles
class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      if (particle.opacity > 0) {
        final paint = Paint()
          ..color = particle.color.withValues(alpha: particle.opacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          Offset(particle.x, particle.y),
          particle.size,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
