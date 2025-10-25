import 'package:hive/hive.dart';
import 'sheet_destination.dart';

part 'history_item.g.dart';

@HiveType(typeId: 3)
class HistoryItem {
  /// Unique id for the entry (e.g., uuid)
  @HiveField(0)
  final String id;

  /// Flattened key-value pairs that were saved
  @HiveField(1)
  final Map<String, String> structured;

  /// Where it was saved (csv/xlsx + path)
  @HiveField(2)
  final SheetDestination destination;

  /// Optional row number/index where it was appended (-1 if unknown)
  @HiveField(3)
  final int rowIndex;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final int schemaVersion;

  HistoryItem({
    required this.id,
    required this.structured,
    required this.destination,
    this.rowIndex = -1,
    DateTime? timestamp,
    this.schemaVersion = 1,
  }) : timestamp = timestamp ?? DateTime.now();

  HistoryItem copyWith({
    String? id,
    Map<String, String>? structured,
    SheetDestination? destination,
    int? rowIndex,
    DateTime? timestamp,
    int? schemaVersion,
  }) => HistoryItem(
        id: id ?? this.id,
        structured: structured ?? this.structured,
        destination: destination ?? this.destination,
        rowIndex: rowIndex ?? this.rowIndex,
        timestamp: timestamp ?? this.timestamp,
        schemaVersion: schemaVersion ?? this.schemaVersion,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'structured': structured,
        'destination': destination.toJson(),
        'rowIndex': rowIndex,
        'timestamp': timestamp.toIso8601String(),
        'schemaVersion': schemaVersion,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        id: j['id'] as String? ?? '',
        structured: Map<String, String>.from(j['structured'] ?? <String, String>{}),
        destination: SheetDestination.fromJson((j['destination'] as Map).cast<String, dynamic>()),
        rowIndex: j['rowIndex'] as int? ?? -1,
        timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(),
        schemaVersion: j['schemaVersion'] as int? ?? 1,
      );
}
