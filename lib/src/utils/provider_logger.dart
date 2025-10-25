import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';

/// Debug-only provider observer to log state changes for critical providers.
final class DebugProviderLogger extends ProviderObserver {
  @override
  void didUpdateProvider(ProviderObserverContext context, Object? previousValue, Object? newValue) {
    if (!kDebugMode) return;
    // Avoid logging very noisy internals; keep it lightweight
    final provider = context.provider;
    final name = provider.name ?? provider.runtimeType.toString();
    debugPrint('[prov] $name: ${_summary(previousValue)} -> ${_summary(newValue)}');
  }

  String _summary(Object? value) {
    if (value == null) return 'null';
    final s = value.toString();
    return s.length > 120 ? s.substring(0, 117) + '...' : s;
  }
}
