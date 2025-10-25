import 'package:flutter/material.dart';
import '../core/routes.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/csv_upload_screen.dart';
import 'screens/home_screen.dart';
import 'screens/card_scan_screen.dart';
import 'screens/extraction_screen.dart';
import 'screens/results_screen.dart';
import 'screens/spreadsheet_manager_screen.dart';
import 'screens/simple_history_screen.dart';

class Card2SheetApp extends StatelessWidget {
  const Card2SheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card2Sheet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.onboarding: (_) => const OnboardingScreen(),
        AppRoutes.csvUpload: (_) => const CsvUploadScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.scan: (_) => const CardScanScreen(),
        AppRoutes.extraction: (_) => const ExtractionScreen(),
        AppRoutes.result: (_) => const ResultsScreen(),
        AppRoutes.sheets: (_) => const SpreadsheetManagerScreen(),
        AppRoutes.debugSimpleHistory: (_) => const SimpleHistoryScreen(),
      },
    );
  }
}
