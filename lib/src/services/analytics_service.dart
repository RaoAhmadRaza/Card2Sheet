import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';

class AnalyticsService {
  void track(String event, {Map<String, Object?>? props}) {
    // Keep it lightweight and PII-free. In production, hook your analytics SDK here.
    if (kDebugMode) {
      debugPrint('[analytics] $event ${props ?? {}}');
    }
  }
}

final analyticsProvider = Provider((ref) => AnalyticsService());
