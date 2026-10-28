import '../models/turneo_models.dart';

/// The Flutter client writes through Supabase; the server-side audit/trigger is
/// responsible for copying accepted planning changes to this spreadsheet.
class TurneoWritePolicy {
  static const targetYear = 2027;
  static const googleSheetsSpreadsheetId =
      '1qL4Wrv9aR-LXlmRME4wMo2-GaVAp3y1jYeqEHT-6_0w';
  static const activeLocalUserIds = {'u1', 'u4', 'u5'};
  static const registrationLocalUserIds = ['u5', 'u4'];

  static bool canWrite(DateTime date) => date.year == targetYear;

  static bool canRegister(String localUserId) =>
      registrationLocalUserIds.contains(localUserId);
}

/// Applies the current roster without rewriting historical planning rows.
/// Retired IDs remain valid keys for historical planning rows, but are not
/// returned as active users. Names never decide whether an ID is retained.
List<AppUser> activeRoster(Iterable<AppUser> users) {
  final result = <AppUser>[];
  final seen = <String>{};
  for (final user in users) {
    if (!TurneoWritePolicy.activeLocalUserIds.contains(user.id) ||
        !seen.add(user.id)) {
      continue;
    }
    result.add(user.id == 'u5'
        ? AppUser(
            id: user.id,
            name: 'Adrián',
            role: user.role,
            slot: user.slot,
            color: user.color,
            sheetName: user.sheetName,
          )
        : user);
  }
  return result;
}
