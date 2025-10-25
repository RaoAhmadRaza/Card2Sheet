import 'package:riverpod/riverpod.dart';
import 'package:hive/hive.dart';

import '../models/session_state.dart';
import '../models/sheet_destination.dart';
import 'sheet_provider.dart';

const _sessionBoxName = 'session';
const _sessionKey = 'state';

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    // Kick off async hydration without blocking provider creation
    Future.microtask(_loadFromHive);
    return const SessionState();
  }

  Box<SessionState>? _box;

  Future<void> _ensureBox() async {
    _box ??= Hive.isBoxOpen(_sessionBoxName)
        ? Hive.box<SessionState>(_sessionBoxName)
        : await Hive.openBox<SessionState>(_sessionBoxName);
  }

  Future<void> _loadFromHive() async {
    await _ensureBox();
    final stored = _box!.get(_sessionKey);
    if (stored != null) {
      state = stored;
    }
  }

  Future<void> _persist() async {
    await _ensureBox();
    await _box!.put(_sessionKey, state);
  }

  Future<void> setOnboardingComplete(bool value) async {
    state = state.copyWith(hasCompletedOnboarding: value);
    await _persist();
  }

  Future<void> setLastImagePath(String? path) async {
    state = state.copyWith(lastImagePath: path);
    await _persist();
  }

  Future<void> setLastDestination(SheetDestination? dest) async {
    state = state.copyWith(lastDestination: dest);
    await _persist();
  }

  /// Capture the current sheet selection (type/path) into session if changed
  Future<void> updateLastFilePathIfNeeded() async {
  final sheet = ref.read(sheetProvider);
    final dest = sheet.toDestination();

    // Only persist if a concrete path is available and changed
    if (dest != null) {
      final prev = state.lastDestination;
      final changed = prev == null ||
          prev.type != dest.type ||
          prev.path != dest.path ||
          prev.sheetName != dest.sheetName;
      if (changed) {
        state = state.copyWith(lastDestination: dest);
        await _persist();
      }
    }
  }
}
