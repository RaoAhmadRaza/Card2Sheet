import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Manages a persistent, anonymous session UUID stored locally.
/// This ID is used as a stable session_id for proxy calls until app uninstall.
class SessionIdService {
  static const _boxName = 'app_meta';
  static const _key = 'session_uuid';

  /// Returns an existing session UUID or creates and persists a new one.
  static Future<String> getOrCreateSessionId() async {
    final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : await Hive.openBox(_boxName);
    final existing = box.get(_key) as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final uuid = const Uuid().v4();
    await box.put(_key, uuid);
    return uuid;
  }
}
