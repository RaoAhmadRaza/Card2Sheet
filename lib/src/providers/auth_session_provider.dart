import 'package:riverpod/riverpod.dart';
import 'package:hive/hive.dart';

import '../models/session_model.dart';

/// Auth session provider: persists login state (tokens, email, flags) to Hive and
/// exposes a reactive SessionModel? for the UI.
final authSessionProvider = NotifierProvider<AuthSessionNotifier, SessionModel?>(
  AuthSessionNotifier.new,
);

class AuthSessionNotifier extends Notifier<SessionModel?> {
  static const _boxName = 'user_session';
  static const _key = 'state';
  Box<SessionModel>? _box;

  @override
  SessionModel? build() {
    // Lazy-hydrate without blocking provider creation
    Future.microtask(_hydrate);
    return null;
  }

  Future<void> _hydrate() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<SessionModel>(_boxName)
        : await Hive.openBox<SessionModel>(_boxName);
    final s = _box!.get(_key);
    if (s != null) state = s;
  }

  Future<void> _ensureBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = Hive.isBoxOpen(_boxName)
          ? Hive.box<SessionModel>(_boxName)
          : await Hive.openBox<SessionModel>(_boxName);
    }
  }

  Future<void> saveSession(SessionModel session) async {
    await _ensureBox();
    await _box!.put(_key, session);
    state = session;
  }

  Future<void> clearSession() async {
    await _ensureBox();
    await _box!.delete(_key);
    state = null;
  }

  bool get isLoggedIn => state?.isLoggedIn ?? false;

  /// Simple validity helper based on age; in real apps, decode JWT exp or call backend.
  bool isSessionValid({Duration maxAge = const Duration(hours: 24)}) {
    final s = state;
    if (s == null || !s.isLoggedIn) return false;
    final age = DateTime.now().difference(s.loggedInAt);
    return age <= maxAge;
  }

  /// Refresh session using a provided token fetcher. Returns true if refreshed.
  Future<bool> refreshSession(Future<String?> Function(String refreshToken) fetchNewAccessToken) async {
    final s = state;
    if (s == null || !s.isLoggedIn) return false;
    final newToken = await fetchNewAccessToken(s.refreshToken);
    if (newToken == null || newToken.isEmpty) {
      // Consider session invalid
      return false;
    }
    final updated = SessionModel(
      accessToken: newToken,
      refreshToken: s.refreshToken,
      userEmail: s.userEmail,
      loggedInAt: DateTime.now(),
      isLoggedIn: true,
    );
    await saveSession(updated);
    return true;
  }
}
