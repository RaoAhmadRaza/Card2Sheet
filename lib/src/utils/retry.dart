import 'dart:async';

Future<T> retry<T>(Future<T> Function() task,
    {int maxAttempts = 3, Duration initialDelay = const Duration(milliseconds: 200)}) async {
  assert(maxAttempts >= 1);
  var attempt = 0;
  var delay = initialDelay;
  while (true) {
    attempt++;
    try {
      return await task();
    } catch (e) {
      if (attempt >= maxAttempts) rethrow;
      await Future.delayed(delay);
      delay *= 2;
    }
  }
}
