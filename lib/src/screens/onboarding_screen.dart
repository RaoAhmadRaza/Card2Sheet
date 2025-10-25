import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/routes.dart';
import '../services/local_trust_service.dart';
import '../services/session_id_service.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF9F9FA),
              Color(0xFFF2F2F7),
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
                    color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
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
                        color: Color(0xFF1D1D1F),
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

                // Get Started Button (primary)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000), // ~5% black
                          blurRadius: 30,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        // Ensure a persistent local session token exists before first proxy call
                        await LocalTrustService.getOrCreateToken();
                        // Ensure a persistent anonymous session UUID exists
                        await SessionIdService.getOrCreateSessionId();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacementNamed(AppRoutes.csvUpload);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D1D1F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        overlayColor: const Color(0xFF2C2C2E),
                      ),
                      child: Text(
                        'Get Started',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000), // ~5% black
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 22,
            color: Color(0xFF1D1D1F),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
              letterSpacing: -0.3,
              wordSpacing: -0.8,
            ),
          ),
        ),
      ],
    );
  }
}
