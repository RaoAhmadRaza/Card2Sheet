import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app.dart';
import 'src/models/scan_result.dart';
import 'src/models/history_item.dart';
import 'src/models/session_state.dart';
import 'src/models/sheet_destination.dart';

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
  await Hive.initFlutter();
  // Register adapters once
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(SheetTypeAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SheetDestinationAdapter());
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ScanResultAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(SessionStateAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(HistoryItemAdapter());
  // Open commonly used boxes eagerly
  await Hive.openBox<SessionState>('session');
  await Hive.openBox<HistoryItem>('history');
  runApp(const ProviderScope(child: Card2SheetApp()));
  // Give the UI a chance to settle; helps reduce first-frame jank on some devices
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // No-op warm up; place small non-blocking work here if needed
  });
}
