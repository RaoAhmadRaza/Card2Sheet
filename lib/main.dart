export 'src/app.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app.dart';

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
  runApp(const ProviderScope(child: Card2SheetApp()));
}
