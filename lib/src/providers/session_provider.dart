import 'package:riverpod/riverpod.dart';
import 'package:hive/hive.dart';
import '../utils/async_mutex.dart';

import '../models/session_state.dart';
import '../models/sheet_destination.dart';
import 'sheet_provider.dart';
import 'history_provider.dart';
import '../services/analytics_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

const _sessionBoxName = 'session';
const _sessionKey = 'state';

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);

class SessionNotifier extends Notifier<SessionState> {
  final _lock = AsyncMutex();
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
    await _lock.run(() async {
      await _ensureBox();
      await _box!.put(_sessionKey, state);
    });
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

  /// Danger zone: deletes all locally stored app data (Hive boxes and session state).
  /// By default, this does NOT delete any exported CSV/XLSX files on disk.
  /// Set [deleteExports] to true if you want to attempt deleting last known export file
  /// paths (use with caution).
  Future<void> deleteAllData({bool deleteExports = false}) async {
    // Attempt to delete last image and optionally export files
    if (deleteExports) {
      try {
        final lastDest = state.lastDestination;
        if (lastDest != null && lastDest.path.isNotEmpty) {
          final f = File(lastDest.path);
          if (await f.exists()) {
            await f.delete();
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[deleteAllData] export file delete failed: $e');
      }
    }

    // Clear providers and Hive boxes
    try {
      // Clear history first
      await ref.read(historyProvider.notifier).clearAll();
    } catch (e) {
      if (kDebugMode) debugPrint('[deleteAllData] history clear failed: $e');
    }

    try {
      // Clear session box and reset state
      await _ensureBox();
      await _box!.clear();
      state = const SessionState();
    } catch (e) {
      if (kDebugMode) debugPrint('[deleteAllData] session clear failed: $e');
    }

    try {
      // Clear app_meta (operation queue, flags)
      final meta = Hive.isBoxOpen('app_meta') ? Hive.box('app_meta') : await Hive.openBox('app_meta');
      await meta.clear();
    } catch (e) {
      if (kDebugMode) debugPrint('[deleteAllData] app_meta clear failed: $e');
    }

    // Reset sheet selection provider
    try {
      ref.invalidate(sheetProvider);
    } catch (_) {}

    // Track analytics
    ref.read(analyticsProvider).track('data_deleted');
  }
}
