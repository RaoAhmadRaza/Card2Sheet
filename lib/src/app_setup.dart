import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';

/// Minimal app setup: loads .env and initializes Firebase if configured.
class AppSetup {
  /// Call early in main() before runApp
  static Future<void> initialize() async {
    // load environment (no-op if .env missing)
    await dotenv.load();

    // try to initialize Firebase — if Firebase isn't configured this will
    // throw; callers can ignore that and continue without Firebase.
    try {
      await Firebase.initializeApp();
      debugPrint('Firebase initialized');
    } catch (e) {
      debugPrint('Firebase initialization skipped or failed: $e');
    }
  }
}
