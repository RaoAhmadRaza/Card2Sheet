import 'package:hive/hive.dart';

part 'session_model.g.dart';

// NOTE: typeId must be unique across all Hive types in this app.
// Existing ids: 0 ScanResult, 1 SheetDestination, 2 SessionState, 3 HistoryItem, 4 SheetType, 5 ScanHistory.
// Use 6 for SessionModel (auth session data).
@HiveType(typeId: 6)
class SessionModel {
  @HiveField(0)
  final String accessToken;

  @HiveField(1)
  final String refreshToken;

  @HiveField(2)
  final String userEmail;

  @HiveField(3)
  final DateTime loggedInAt;

  @HiveField(4)
  final bool isLoggedIn;

  SessionModel({
    required this.accessToken,
    required this.refreshToken,
    required this.userEmail,
    required this.loggedInAt,
    required this.isLoggedIn,
  });
}
