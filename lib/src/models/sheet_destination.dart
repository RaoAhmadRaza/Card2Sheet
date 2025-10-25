import 'package:hive/hive.dart';

part 'sheet_destination.g.dart';

@HiveType(typeId: 4)
enum SheetType {
  @HiveField(0)
  csv,
  @HiveField(1)
  xlsx,
}

@HiveType(typeId: 1)
class SheetDestination {
  @HiveField(0)
  final SheetType type;

  /// Absolute path to the file on device (app documents or user-picked)
  @HiveField(1)
  final String path;

  /// For XLSX: optional sheet/tab name; for CSV: ignored
  @HiveField(2)
  final String? sheetName;

  /// Optional template of headers (values-only flows may ignore this)
  @HiveField(3)
  final List<String> templateHeaders;

  @HiveField(4)
  final int schemaVersion;

  const SheetDestination({
    required this.type,
    required this.path,
    this.sheetName,
    this.templateHeaders = const <String>[],
    this.schemaVersion = 1,
  });

  SheetDestination copyWith({
    SheetType? type,
    String? path,
    String? sheetName,
    List<String>? templateHeaders,
    int? schemaVersion,
  }) => SheetDestination(
        type: type ?? this.type,
        path: path ?? this.path,
        sheetName: sheetName ?? this.sheetName,
        templateHeaders: templateHeaders ?? this.templateHeaders,
        schemaVersion: schemaVersion ?? this.schemaVersion,
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'path': path,
        'sheetName': sheetName,
        'templateHeaders': templateHeaders,
        'schemaVersion': schemaVersion,
      };

  factory SheetDestination.fromJson(Map<String, dynamic> j) => SheetDestination(
        type: (j['type'] as String?) == 'xlsx' ? SheetType.xlsx : SheetType.csv,
        path: j['path'] as String? ?? '',
        sheetName: j['sheetName'] as String?,
        templateHeaders: (j['templateHeaders'] as List?)?.cast<String>() ?? <String>[],
        schemaVersion: j['schemaVersion'] as int? ?? 1,
      );
}
