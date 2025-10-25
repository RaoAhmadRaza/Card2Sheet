import 'package:hive/hive.dart';
part 'scan_result.g.dart';



@HiveType(typeId: 0)
class ScanResult {
  @HiveField(0)
  final String rawText;

  /// Normalized, display/export-ready values
  @HiveField(1)
  final Map<String, String> structured;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final int schemaVersion;

  ScanResult({
    required this.rawText,
    required this.structured,
    DateTime? timestamp,
    this.schemaVersion = 1,
  }) : timestamp = timestamp ?? DateTime.now();

  ScanResult copyWith({
    String? rawText,
    Map<String, String>? structured,
    DateTime? timestamp,
    int? schemaVersion,
  }) => ScanResult(
        rawText: rawText ?? this.rawText,
        structured: structured ?? this.structured,
        timestamp: timestamp ?? this.timestamp,
        schemaVersion: schemaVersion ?? this.schemaVersion,
      );

  Map<String, dynamic> toJson() => {
        'rawText': rawText,
        'structured': structured,
        'timestamp': timestamp.toIso8601String(),
        'schemaVersion': schemaVersion,
      };

  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
        rawText: j['rawText'] as String? ?? '',
        structured: Map<String, String>.from(j['structured'] ?? <String, String>{}),
        timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(),
        schemaVersion: j['schemaVersion'] as int? ?? 1,
      );
}
