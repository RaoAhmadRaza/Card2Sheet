import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Safe access to environment variables that won't throw if dotenv not initialized.
String? env(String key) {
  try {
    if (dotenv.isInitialized) {
      final v = dotenv.maybeGet(key);
      if (v != null) return v;
    }
  } catch (_) {
    // ignore
  }
  // Fallback to process environment if present.
  return Platform.environment[key];
}

bool envIsTrue(String key) => (env(key) ?? '').toLowerCase() == 'true';
