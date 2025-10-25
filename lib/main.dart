import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app.dart';
import 'src/utils/provider_logger.dart';
import 'src/models/scan_result.dart';
import 'src/models/history_item.dart';
import 'src/models/session_state.dart';
import 'src/models/sheet_destination.dart';
import 'src/models/scan_history.dart';
import 'src/models/session_model.dart';
import 'src/services/migration_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables safely; if missing, continue with defaults.
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('[startup] dotenv load failed: $e (continuing with defaults)');
  }
  final fbOptions = DefaultFirebaseOptions.maybePlatform;
  if (fbOptions != null) {
    await Firebase.initializeApp(options: fbOptions);
  }
  // Initialize Hive for typed local storage
  // Prefer initializing Hive in an OS-safe app documents directory
  final dir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(dir.path);
  // Register adapters once
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(SheetTypeAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SheetDestinationAdapter());
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ScanResultAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(SessionStateAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(HistoryItemAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(ScanHistoryAdapter());
  if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(SessionModelAdapter());
  // Open meta box and run migrations before opening other boxes
  await Hive.openBox('app_meta');
  await MigrationService.migrateIfNeeded();
  // Open commonly used boxes eagerly (post-migration)
  await Hive.openBox<SessionState>('session');
  await Hive.openBox<HistoryItem>('scan_history');
  // Open simple tutorial/demo box (separate from the richer 'scan_history')
  await Hive.openBox<ScanHistory>('scanHistory');
  // Open auth session box (tutorial/optional; stores SessionModel)
  await Hive.openBox<SessionModel>('user_session');
  runApp(ProviderScope(
    observers: [DebugProviderLogger()],
    child: const Card2SheetApp(),
  ));
  // Give the UI a chance to settle; helps reduce first-frame jank on some devices
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // No-op warm up; place small non-blocking work here if needed
  });
}
