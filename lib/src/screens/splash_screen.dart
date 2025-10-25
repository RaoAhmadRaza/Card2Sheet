import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routes.dart';
import '../providers/auth_session_provider.dart';
import '../models/session_model.dart';

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
    // Defer to next frame for provider readiness, then route based on auth state
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initial check
      _routeNow();
      // Also listen in case hydration finishes slightly later
      ref.listen<SessionModel?>(authSessionProvider, (prev, next) {
        if (!_navigated) {
          _routeNow();
        }
      });
    });
  }

  void _routeNow() {
    if (!mounted || _navigated) return;
    final session = ref.read(authSessionProvider);
    final loggedIn = session?.isLoggedIn == true;
    final target = loggedIn ? AppRoutes.home : AppRoutes.onboarding;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(target);
  }

  @override
  Widget build(BuildContext context) {
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
