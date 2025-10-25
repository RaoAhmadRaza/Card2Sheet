import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';

/// Provides a lightweight local identity for the app without user login.
/// A random token is generated once and stored in the untyped 'app_meta' box.
class LocalTrustService {
  static const _boxName = 'app_meta';
  static const _key = 'session_token';

  /// Returns the existing token or generates and persists a new one.
  static Future<String> getOrCreateToken() async {
    final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : await Hive.openBox(_boxName);
    final existing = box.get(_key);
    if (existing is String && existing.isNotEmpty) return existing;

    final token = _generateToken();
    await box.put(_key, token);
    return token;
  }

  /// Generate a 32-byte secure random token, base64url without padding.
  static String _generateToken({int length = 32}) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
