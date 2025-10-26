import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routes.dart';
import '../../core/preferences.dart';
import '../providers/auth_session_provider.dart';
import '../models/session_model.dart';
import '../services/local_trust_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;
  @override
  void initState() {
    super.initState();
    // Defer to next frame for initial routing and token bootstrap
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await LocalTrustService.getOrCreateToken();
      _routeNow();
    });
  }

  void _routeNow() {
    if (!mounted || _navigated) return;
    // Skip onboarding if user has completed it previously.
    // Fall back to onboarding otherwise.
    _navigated = true;
    _decideInitialRoute();
  }

  Future<void> _decideInitialRoute() async {
    // If onboardingCompleted, jump to either csv upload or home depending on prior template choice.
    final done = await Preferences.getOnboardingCompleted();
    if (!mounted) return;
    if (done) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for session hydration changes and route once when ready
    ref.listen<SessionModel?>(authSessionProvider, (prev, next) {
      if (!_navigated) {
        _routeNow();
      }
    });
    return const Scaffold(
      body: Center(
        child: Text(
          'Card2Sheet',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
