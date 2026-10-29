import 'package:flutter_test/flutter_test.dart';
import 'package:turneo/src/data/turneo_policy.dart';
import 'package:turneo/src/models/turneo_models.dart';

void main() {
  const users = [
    AppUser(id: 'u2', name: 'Carlos', role: 'user', slot: 1, color: '#111111'),
    AppUser(
        id: 'u3', name: 'Alejandro', role: 'user', slot: 2, color: '#222222'),
    AppUser(id: 'u1', name: 'DAVID', role: 'admin', slot: 2, color: '#222222'),
    AppUser(
        id: 'u5',
        name: 'Adrián',
        role: 'user',
        slot: 5,
        color: '#333333',
        sheetName: 'Santa Eufemia'),
    AppUser(id: 'u4', name: 'Juan', role: 'user', slot: 4, color: '#444444'),
  ];

  test('roster uses active IDs and preserves the Excel alias', () {
    final roster = activeRoster(users);

    expect(roster.map((user) => user.name), ['DAVID', 'JUAN', 'ADRIÁN']);
    expect(roster.map((user) => user.id), ['u1', 'u4', 'u5']);
    expect(roster.singleWhere((user) => user.id == 'u1').role, 'admin');
    expect(roster.singleWhere((user) => user.id == 'u5').syncIdentity,
        'Santa Eufemia');
    expect(roster.where((user) => user.name == 'Adrián'), hasLength(1));
    expect(roster.map((user) => user.id), isNot(contains('u2')));
    expect(roster.map((user) => user.id), isNot(contains('u3')));
  });

  test('registration only offers u4 and u5 in roster order', () {
    expect(TurneoWritePolicy.registrationLocalUserIds, ['u4', 'u5']);
    expect(TurneoWritePolicy.activeLocalUserOrder, ['u1', 'u4', 'u5']);
    expect(TurneoWritePolicy.canRegister('u5'), isTrue);
    expect(TurneoWritePolicy.canRegister('u4'), isTrue);
    expect(TurneoWritePolicy.canRegister('u1'), isFalse);
    expect(TurneoWritePolicy.canRegister('u2'), isFalse);
    expect(TurneoWritePolicy.canRegister('u3'), isFalse);
  });

  test('write policy protects 2026 and only permits 2027', () {
    expect(TurneoWritePolicy.canWrite(DateTime(2026, 12, 31)), isFalse);
    expect(TurneoWritePolicy.canWrite(DateTime(2027, 1, 1)), isTrue);
    expect(TurneoWritePolicy.canWrite(DateTime(2028, 1, 1)), isFalse);
    expect(TurneoWritePolicy.googleSheetsSpreadsheetId,
        '1qL4Wrv9aR-LXlmRME4wMo2-GaVAp3y1jYeqEHT-6_0w');
  });
}
