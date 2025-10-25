import 'package:hive/hive.dart';
import 'sheet_destination.dart';

part 'session_state.g.dart';

@HiveType(typeId: 2)
class SessionState {
  /// Last captured/cropped image path (if any)
  @HiveField(0)
  final String? lastImagePath;

  /// Last saved spreadsheet selection (type/path/sheet)
  @HiveField(1)
  final SheetDestination? lastDestination;

  /// Whether user completed onboarding
  @HiveField(2)
  final bool hasCompletedOnboarding;

  /// For future migrations
  @HiveField(3)
  final int schemaVersion;

  const SessionState({
    this.lastImagePath,
    this.lastDestination,
    this.hasCompletedOnboarding = false,
    this.schemaVersion = 1,
  });

  SessionState copyWith({
    String? lastImagePath,
    SheetDestination? lastDestination,
    bool? hasCompletedOnboarding,
    int? schemaVersion,
  }) => SessionState(
        lastImagePath: lastImagePath ?? this.lastImagePath,
        lastDestination: lastDestination ?? this.lastDestination,
        hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
        schemaVersion: schemaVersion ?? this.schemaVersion,
      );

  Map<String, dynamic> toJson() => {
        'lastImagePath': lastImagePath,
        'lastDestination': lastDestination?.toJson(),
        'hasCompletedOnboarding': hasCompletedOnboarding,
        'schemaVersion': schemaVersion,
      };

  factory SessionState.fromJson(Map<String, dynamic> j) => SessionState(
        lastImagePath: j['lastImagePath'] as String?,
        lastDestination: j['lastDestination'] is Map<String, dynamic>
            ? SheetDestination.fromJson(j['lastDestination'] as Map<String, dynamic>)
            : null,
        hasCompletedOnboarding: j['hasCompletedOnboarding'] as bool? ?? false,
        schemaVersion: j['schemaVersion'] as int? ?? 1,
      );
}
