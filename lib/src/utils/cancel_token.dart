class CancelToken {
  bool _cancelled = false;
  final String id;
  CancelToken(this.id);

  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}
