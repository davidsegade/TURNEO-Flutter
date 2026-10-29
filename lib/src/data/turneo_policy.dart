import '../models/turneo_models.dart';

/// The Flutter client writes through Supabase; the server-side audit/trigger is
/// responsible for copying accepted planning changes to this spreadsheet.
class TurneoWritePolicy {
  static const targetYear = 2027;
  static const googleSheetsSpreadsheetId =
      '1qL4Wrv9aR-LXlmRME4wMo2-GaVAp3y1jYeqEHT-6_0w';
  static const activeLocalUserIds = {'u1', 'u4', 'u5'};
  static const activeLocalUserOrder = ['u1', 'u4', 'u5'];
  static const registrationLocalUserIds = ['u4', 'u5'];
  static const dasInitialByLocalUser = {'u5': 0};

  static bool canWrite(DateTime date) => date.year == targetYear;

  static bool canRegister(String localUserId) =>
      registrationLocalUserIds.contains(localUserId);

  /// u5 has an explicit zero baseline. Other users use the value supplied by
  /// the existing operator/backend process; this app does not guess it.
  static int? dasInitialFor(String localUserId) =>
      dasInitialByLocalUser[localUserId];
}

/// Applies the current roster without rewriting historical planning rows.
/// Retired IDs remain valid keys for historical planning rows, but are not
/// returned as active users. Names never decide whether an ID is retained.
List<AppUser> activeRoster(Iterable<AppUser> users) {
  final byId = <String, AppUser>{};
  for (final user in users) {
    if (TurneoWritePolicy.activeLocalUserIds.contains(user.id)) {
      byId.putIfAbsent(user.id, () => user);
    }
  }
  const names = {'u1': 'DAVID', 'u4': 'JUAN', 'u5': 'ADRIÁN'};
  return [
    for (final id in TurneoWritePolicy.activeLocalUserOrder)
      if (byId[id] case final user)
        AppUser(
          id: user.id,
          name: names[id]!,
          role: user.role,
          slot: user.slot,
          color: user.color,
          sheetName: user.sheetName,
        )
  ];
}
