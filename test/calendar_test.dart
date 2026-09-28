import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turneo/src/app.dart';
import 'package:turneo/src/data/turneo_repository.dart';
import 'package:turneo/src/models/turneo_models.dart';

const users = [
  AppUser(id: 'u2', name: 'Carlos', role: 'user', slot: 1, color: '#FFFFFF'),
  AppUser(id: 'u1', name: 'David', role: 'admin', slot: 2, color: '#FFFFFF'),
  AppUser(id: 'u3', name: 'Alejandro', role: 'user', slot: 3, color: '#FFFFFF'),
  AppUser(id: 'u4', name: 'Juan', role: 'user', slot: 4, color: '#FFFFFF'),
];

class CalendarRepository implements TurneoRepository {
  @override
  AppUser? profile = users.first;
  @override
  bool canEdit(String id) => profile?.id == id || profile?.role == 'admin';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  final loads = <DateTime>[];
  final writes = <(String, DateTime, String?)>[];
  bool failWrite = false;
  @override
  Future<MonthData> loadMonth(DateTime month) async {
    loads.add(month);
    return MonthData(
        month: month,
        assignments: {},
        colors: {'MC': '#FFFFFF'},
        users: users,
        holidays: {},
        hours: {'MC': 7.5});
  }

  @override
  Future<List<ServiceOption>> loadServices() async => [
        const ServiceOption(
            code: 'MC', label: 'Mañana corta', hours: 7.5, color: '#FFFFFF'),
      ];
  @override
  Future<String?> saveService(
      String userId, DateTime date, String? code) async {
    if (failWrite) throw StateError('offline');
    writes.add((userId, date, code));
    return code;
  }
}

void main() {
  test('cell patch preserves other users and dates and can clear a cell', () {
    final original = MonthData(
        month: DateTime(2026, 9),
        assignments: {'u1|2026-09-01': 'M', 'u2|2026-09-01': 'DS'},
        colors: {'MC': '#FFFFFF', 'TC': '#FFFFFF'},
        users: users,
        holidays: {});
    final changed = original.withAssignment('u1', DateTime(2026, 9, 1), 'MC');
    expect(original.assignments['u1|2026-09-01'], 'M');
    expect(changed.assignments['u2|2026-09-01'], 'DS');
    expect(changed.withAssignment('u1', DateTime(2026, 9, 1), null).assignments,
        {'u2|2026-09-01': 'DS'});
    expect(changed.serviceTextColor('MC'), Colors.black);
    expect(changed.serviceTextColor('TC'), Colors.black);
  });


  test('balance uses manual PICO only when present', () {
    const automatic = BalanceSnapshot(picoClose: 2);
    const overridden = BalanceSnapshot(picoClose: 2, picoManual: 0);
    expect(automatic.pico, 2);
    expect(overridden.pico, 0);
  });

  test('month patch preserves balance snapshots', () {
    const balance = BalanceSnapshot(
        dasAvailable: 1, dasGenerated: 2, dfAvailable: 3, picoClose: 1);
    final original = MonthData(
        month: DateTime(2026, 9),
        assignments: {'u1|2026-09-01': 'M'},
        colors: const {'M': '#FFFFFF'},
        users: users,
        holidays: const {},
        balances: const {'u1': balance});
    final changed = original.withAssignment('u1', DateTime(2026, 9, 1), 'MC');
    expect(changed.balances['u1'], same(balance));
    expect(changed.assignments['u1|2026-09-01'], 'MC');
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'mobile calendar $width keeps 7 columns and saves without reload',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = CalendarRepository();
      await tester.pumpWidget(MaterialApp(
          home: CalendarScreen(repository: repo, onLogout: () async {})));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          7);
      expect(find.text('CARLOS'), findsOneWidget);
      await tester.tap(find.text('CARLOS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MC'));
      await tester.pumpAndSettle();
      expect(repo.writes.single.$1, 'u2');
      expect(repo.writes.single.$3, 'MC');
      expect(repo.loads.length, 1);
      expect(find.text('MC', findRichText: true), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(repo.loads.length, greaterThanOrEqualTo(1));
      await tester.tap(find.text('DAVID'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      expect(find.text('BORRAR SERVICIO'), findsNothing);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(repo.loads.last,
          DateTime(repo.loads.first.year, repo.loads.first.month + 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('editing David keeps David selected after background refresh',
      (tester) async {
    final repo = CalendarRepository()..profile = users[1];
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAVID'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MC'));
    await tester.pumpAndSettle();
    expect(repo.writes.single.$1, 'u1');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(nav.selectedIndex, 2);
  });

  testWidgets('failed save leaves the cell unchanged and permits retry',
      (tester) async {
    final repo = CalendarRepository()..failWrite = true;
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CARLOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MC'));
    await tester.pumpAndSettle();
    expect(repo.writes, isEmpty);
    expect(find.textContaining('No se ha podido guardar'), findsOneWidget);
    expect(find.text('MC', findRichText: true), findsNothing);
    expect(repo.loads.length, 1);
  });
}
