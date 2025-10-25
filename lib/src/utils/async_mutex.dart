import 'dart:async';

/// A minimal async mutex that queues tasks and ensures only one runs at a time.
class AsyncMutex {
  Future<void> _last = Future.value();

  /// Runs [action] exclusively. If another action is running, waits for it.
  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    // Chain onto the end of the last future
    _last = _last.then((_) async {
      try {
        final result = await action();
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });

    return completer.future;
  }
}
