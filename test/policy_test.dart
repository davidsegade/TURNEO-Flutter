import 'package:flutter_test/flutter_test.dart';
import 'package:turneo/src/data/balance_calculator.dart';
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
    expect(roster.where((user) => user.name == 'ADRIÁN'), hasLength(1));
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

  test('u5 starts with zero DAS and the shared calculator preserves it', () {
    expect(TurneoWritePolicy.dasInitialFor('u5'), 0);
    final balance = computeBalance(const BalanceInputs(
      localUserId: 'u5',
      dasInitial: 0,
      dasGenerated: 2,
      dasTaken: 1,
      holidayEntitlements: [],
    ));
    expect(balance.dasAvailable, 1);
    expect(balance.dfAvailable, 0);
  });

  test('u5 rejects a non-zero DAS baseline', () {
    expect(
        () => computeBalance(const BalanceInputs(
              localUserId: 'u5',
              dasInitial: 1,
              dasGenerated: 0,
              dasTaken: 0,
              holidayEntitlements: [],
            )), throwsArgumentError);
  });

  test('DF stays unknown until holiday coverage is resolved', () {
    final balance = computeBalance(BalanceInputs(
      localUserId: 'u5',
      dasInitial: TurneoWritePolicy.dasInitialFor('u5')!,
      dasGenerated: 0,
      dasTaken: 0,
      holidayEntitlements: [
        HolidayEntitlement(
            date: DateTime(2027, 1, 1), scope: 'national', enjoyed: null),
      ],
    ));
    expect(balance.dasAvailable, 0);
    expect(balance.dfAvailable, isNull);
  });

  test('DF counts resolved un-enjoyed entitlements', () {
    final balance = computeBalance(BalanceInputs(
      localUserId: 'u1',
      dasInitial: 3,
      dasGenerated: 0,
      dasTaken: 0,
      holidayEntitlements: [
        HolidayEntitlement(
            date: DateTime(2027, 1, 1), scope: 'national', enjoyed: false),
        HolidayEntitlement(
            date: DateTime(2027, 1, 6), scope: 'autonomic', enjoyed: true),
        HolidayEntitlement(
            date: DateTime(2027, 9, 8), scope: 'local', enjoyed: false),
      ],
    ));
    expect(balance.dasAvailable, 3);
    expect(balance.dfAvailable, 2);
  });
}
