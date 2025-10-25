import 'package:hive/hive.dart';

part 'scan_history.g.dart';

/// Minimal history entry for a saved scan.
/// Note: This project already uses `HistoryItem` for richer history,
/// but this model demonstrates a simple Hive type per the Chunk 4 tutorial.
@HiveType(typeId: 5)
class ScanHistory {
  @HiveField(0)
  final String cardName;

  @HiveField(1)
  final String filePath;

  @HiveField(2)
  final DateTime dateTime;

  const ScanHistory(this.cardName, this.filePath, this.dateTime);
}
