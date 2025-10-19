import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/routes.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [
              Color(0xFFB0B0B0), // Gray bottom left
              Colors.white, // White top right
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Main Title
                Text(
                  'Card2Sheet',
                  style: GoogleFonts.poppins(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D1D1F),
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Transform business cards into organized data',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF86868B),
                    letterSpacing: -0.3,
                    wordSpacing: -0.8,
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
                      colors: [
                        Color.fromARGB(255, 220, 222, 224),
                        Color.fromARGB(255, 255, 255, 255),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(
                          255,
                          81,
                          83,
                          84,
                        ).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pushReplacementNamed(AppRoutes.csvUpload),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Get Started',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
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
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color.fromARGB(
              255,
              255,
              255,
              255,
            ).withValues(alpha: 10.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 22,
            color: const Color.fromARGB(255, 0, 0, 0),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF1D1D1F),
              letterSpacing: -0.3,
              wordSpacing: -0.8,
            ),
          ),
        ),
      ],
    );
  }
}
