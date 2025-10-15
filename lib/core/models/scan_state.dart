enum ScanStatus { idle, scanning, processing, done, error }

class ScanState {
  final ScanStatus status;
  final String message;

  ScanState({required this.status, this.message = ''});

  factory ScanState.idle() => ScanState(status: ScanStatus.idle);
  factory ScanState.scanning() => ScanState(status: ScanStatus.scanning);
  factory ScanState.processing() => ScanState(status: ScanStatus.processing);
  factory ScanState.done([String message = '']) =>
      ScanState(status: ScanStatus.done, message: message);
  factory ScanState.error(String message) =>
      ScanState(status: ScanStatus.error, message: message);
}
