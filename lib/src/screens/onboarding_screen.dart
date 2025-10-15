import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../core/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0 + (_animation.value * 0.3),
                colors: [
                  Color.lerp(
                    const Color(0xFFE5E5E5), // Light gray
                    Colors.white,
                    _animation.value,
                  )!,
                  Color.lerp(
                    const Color(0xFFB0B0B0), // Medium gray
                    const Color(0xFFE5E5E5),
                    _animation.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF909090), // Darker gray
                    const Color(0xFFB0B0B0),
                    _animation.value,
                  )!,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    
                    // Main Title
                    const Text(
                      'Card2Sheet',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D1D1F),
                        letterSpacing: -0.5,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Subtitle
                    const Text(
                      'Transform business cards into organized data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF86868B),
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const Spacer(flex: 1),
                    
                    // Lottie Animation
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: Lottie.network(
                        'https://lottie.host/52e36640-1392-4378-a14e-577cd82744b9/ub9z5yqfAE.json',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.credit_card,
                            size: 120,
                            color: Color(0xFF86868B),
                          );
                        },
                      ),
                    ),
                    
                    const Spacer(flex: 1),
                    
                    // Features List
                    const Column(
                      children: [
                        _FeatureItem(
                          icon: Icons.camera_alt_outlined,
                          text: 'Scan cards with your camera',
                        ),
                        SizedBox(height: 16),
                        _FeatureItem(
                          icon: Icons.psychology_outlined,
                          text: 'AI extracts contact information',
                        ),
                        SizedBox(height: 16),
                        _FeatureItem(
                          icon: Icons.table_chart_outlined,
                          text: 'Export to spreadsheets instantly',
                        ),
                      ],
                    ),
                    
                    const Spacer(flex: 2),
                    
                    // Get Started Button
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF007AFF), Color(0xFF0056CC)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context)
                            .pushReplacementNamed(AppRoutes.home),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF007AFF),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF1D1D1F),
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }
}
