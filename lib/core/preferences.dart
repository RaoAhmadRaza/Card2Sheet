import 'package:shared_preferences/shared_preferences.dart';

enum DefaultExportFormat { csv, xlsx }

class Preferences {
  static const _keyDefaultFormat = 'default_export_format';
  static const _keyLastSheetPath = 'last_sheet_path';
  static const _keyOnboardingCompleted = 'onboarding_completed';
  static const _keyFirstExportDone = 'first_export_done';

  static Future<void> setDefaultFormat(DefaultExportFormat format) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyDefaultFormat,
        format == DefaultExportFormat.csv ? 'csv' : 'xlsx',
      );
    } catch (_) {
      // Swallow errors to avoid crashing if platform channels aren't ready.
    }
  }

  static Future<DefaultExportFormat?> getDefaultFormat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_keyDefaultFormat);
      if (v == 'csv') return DefaultExportFormat.csv;
      if (v == 'xlsx') return DefaultExportFormat.xlsx;
      return null;
    } catch (_) {
      return null;
    }
  }

  // Persist and retrieve the last saved or selected spreadsheet path (csv/xlsx)
  static Future<void> setLastSheetPath(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSheetPath, path);
    } catch (_) {}
  }

  static Future<String?> getLastSheetPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLastSheetPath);
    } catch (_) {
      return null;
    }
  }

  // Onboarding completion flag
  static Future<void> setOnboardingCompleted(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingCompleted, value);
    } catch (_) {}
  }

  static Future<bool> getOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyOnboardingCompleted) ?? false;
    } catch (_) {
      return false;
    }
  }

  // First export hint (to optionally show SuccessScreen only once)
  static Future<void> setFirstExportDone(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyFirstExportDone, value);
    } catch (_) {}
  }

  static Future<bool> getFirstExportDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyFirstExportDone) ?? false;
    } catch (_) {
      return false;
    }
  }
}
