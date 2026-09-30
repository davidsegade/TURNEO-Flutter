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
      await tester.tap(find.descendant(
          of: find.byType(MonthGrid), matching: find.text('1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'MC'));
      await tester.pumpAndSettle();
      expect(repo.writes.single.$1, 'u2');
      expect(repo.writes.single.$3, 'MC');
      expect(repo.loads.length, 1);
      expect(find.text('MC', findRichText: true), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(repo.loads.length, 1);
      await tester.tap(find.text('DAVID'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(MonthGrid), matching: find.text('1')));
      await tester.pumpAndSettle();
      expect(find.text('BORRAR SERVICIO'), findsNothing);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(repo.loads.last,
          DateTime(repo.loads.first.year, repo.loads.first.month + 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('editing David keeps David selected after save', (tester) async {
    final repo = CalendarRepository()..profile = users[1];
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAVID'));
    await tester.pumpAndSettle();
    await tester.tap(
        find.descendant(of: find.byType(MonthGrid), matching: find.text('1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'MC'));
    await tester.pumpAndSettle();
    expect(repo.writes.single.$1, 'u1');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(nav.selectedIndex, 2);
  });

  testWidgets('editing any user keeps that same user selected after save',
      (tester) async {
    final repo = CalendarRepository()..profile = users[1];
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();
    for (var index = 0; index < users.length; index++) {
      await tester.tap(find.text(users[index].name.toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(MonthGrid), matching: find.text('1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'MC'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(nav.selectedIndex, index + 1);
      expect(repo.writes.length, index + 1);
      expect(repo.writes.last.$1, users[index].id);
      expect(repo.writes.last.$3, 'MC');
    }
  });

  testWidgets('changing month keeps the selected user', (tester) async {
    final repo = CalendarRepository()..profile = users[1];
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ALEJANDRO'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(nav.selectedIndex, 3);
  });

  testWidgets(
      'repeated add and clear stays on the same user and writes once per action',
      (tester) async {
    final repo = CalendarRepository()..profile = users[1];
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAVID'));
    await tester.pumpAndSettle();

    for (var round = 0; round < 3; round++) {
      await tester.tap(find.descendant(
          of: find.byType(MonthGrid), matching: find.text('1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'MC'));
      await tester.pumpAndSettle();
      expect(repo.writes.length, round * 2 + 1);
      expect(repo.writes.last.$1, 'u1');
      expect(repo.writes.last.$3, 'MC');
      expect(find.text('MC', findRichText: true), findsOneWidget);
      var nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(nav.selectedIndex, 2);

      await tester.tap(find.descendant(
          of: find.byType(MonthGrid), matching: find.text('1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BORRAR SERVICIO'));
      await tester.pumpAndSettle();
      expect(repo.writes.length, round * 2 + 2);
      expect(repo.writes.last.$1, 'u1');
      expect(repo.writes.last.$3, isNull);
      expect(find.text('MC', findRichText: true), findsNothing);
      nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(nav.selectedIndex, 2);
    }
    expect(repo.loads.length, 1);
  });

  testWidgets('failed save leaves the cell unchanged and permits retry',
      (tester) async {
    final repo = CalendarRepository()..failWrite = true;
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CARLOS'));
    await tester.pumpAndSettle();
    await tester.tap(
        find.descendant(of: find.byType(MonthGrid), matching: find.text('1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'MC'));
    await tester.pumpAndSettle();
    expect(repo.writes, isEmpty);
    expect(find.textContaining('No se ha podido guardar'), findsOneWidget);
    expect(find.text('MC', findRichText: true), findsNothing);
    expect(repo.loads.length, 1);
    repo.failWrite = false;
    await tester.tap(
        find.descendant(of: find.byType(MonthGrid), matching: find.text('1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'MC'));
    await tester.pumpAndSettle();
    expect(repo.writes.single.$1, 'u2');
    expect(repo.writes.single.$3, 'MC');
    expect(find.text('MC', findRichText: true), findsOneWidget);
    expect(repo.loads.length, 1);
  });

  testWidgets('post-save tap guard expires and navigation works again',
      (tester) async {
    final repo = CalendarRepository();
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CARLOS'));
    await tester.pumpAndSettle();
    await tester.tap(
        find.descendant(of: find.byType(MonthGrid), matching: find.text('1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'MC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAVID'));
    await tester.pump();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('DAVID'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2);
    expect(repo.writes.length, 1);
    expect(repo.loads.length, 1);
  });

  testWidgets(
      'all four users (Carlos u2, David u1, Alejandro u3, Juan u4) complete repeated add-clear cycles maintaining selected user and exact writes',
      (tester) async {
    final repo = CalendarRepository()..profile = users[1]; // David (admin)
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();

    var totalWrites = 0;

    for (var uIndex = 0; uIndex < users.length; uIndex++) {
      final user = users[uIndex];
      final expectedNavIndex = uIndex + 1;

      // Esperar a que expire la guarda de navegación previa si la hubiese
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // 1. Seleccionar usuario
      await tester.tap(find.text(user.name.toUpperCase()));
      await tester.pumpAndSettle();
      expect(
          tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          expectedNavIndex);

      // Repite 2 ciclos completos de añadir y borrar por usuario
      for (var cycle = 0; cycle < 2; cycle++) {
        // 2. Abrir un día (día 1)
        await tester.tap(find.descendant(
            of: find.byType(MonthGrid), matching: find.text('1')));
        await tester.pumpAndSettle();

        // 3. Añadir servicio MC
        await tester.tap(find.widgetWithText(FilledButton, 'MC'));
        await tester.pumpAndSettle();

        // 4. Comprobar EXACTAMENTE una nueva escritura
        totalWrites++;
        expect(repo.writes.length, totalWrites);

        // 5. Comprobar user_id correcto
        expect(repo.writes.last.$1, user.id);

        // 6. Comprobar código MC
        expect(repo.writes.last.$3, 'MC');

        // 7. Comprobar que MC aparece inmediatamente
        expect(find.text('MC', findRichText: true), findsOneWidget);

        // 8. Comprobar que el usuario seleccionado NO cambia
        expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            expectedNavIndex);

        // 9. Volver a abrir el día
        await tester.tap(find.descendant(
            of: find.byType(MonthGrid), matching: find.text('1')));
        await tester.pumpAndSettle();

        // 10. BORRAR SERVICIO
        await tester.tap(find.text('BORRAR SERVICIO'));
        await tester.pumpAndSettle();

        // 11. Comprobar EXACTAMENTE una nueva escritura
        totalWrites++;
        expect(repo.writes.length, totalWrites);

        // 12. Comprobar null
        expect(repo.writes.last.$1, user.id);
        expect(repo.writes.last.$3, isNull);

        // 13. Comprobar que MC desaparece inmediatamente
        expect(find.text('MC', findRichText: true), findsNothing);

        // 14. Comprobar que el usuario seleccionado sigue siendo el mismo
        expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            expectedNavIndex);
      }
    }
  });

  testWidgets(
      'sequence: user -> service -> clear -> another day -> another service',
      (tester) async {
    final repo = CalendarRepository()..profile = users[1]; // David
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();

    // Seleccionar Alejandro (u3, índice 3)
    await tester.tap(find.text('ALEJANDRO'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);

    // Día 1: Añadir MC
    await tester.tap(
        find.descendant(of: find.byType(MonthGrid), matching: find.text('1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'MC'));
    await tester.pumpAndSettle();
    expect(repo.writes.length, 1);
    expect(repo.writes.last, ('u3', DateTime(DateTime.now().year, DateTime.now().month, 1), 'MC'));
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);

    // Día 1: Borrar
    await tester.tap(
        find.descendant(of: find.byType(MonthGrid), matching: find.text('1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BORRAR SERVICIO'));
    await tester.pumpAndSettle();
    expect(repo.writes.length, 2);
    expect(repo.writes.last, ('u3', DateTime(DateTime.now().year, DateTime.now().month, 1), null));
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);

    // Día 2: Otro día -> otro servicio
    await tester.tap(
        find.descendant(of: find.byType(MonthGrid), matching: find.text('2')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'MC'));
    await tester.pumpAndSettle();
    expect(repo.writes.length, 3);
    expect(repo.writes.last, ('u3', DateTime(DateTime.now().year, DateTime.now().month, 2), 'MC'));
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);
  });

  testWidgets('sequence: user -> change month -> return keeps selected user',
      (tester) async {
    final repo = CalendarRepository()..profile = users[1];
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();

    // Seleccionar Juan (u4, índice 4)
    await tester.tap(find.text('JUAN'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4);

    // Avanzar mes
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4);

    // Retroceder mes
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4);

    // Editar servicio en el mes retornado
    await tester.tap(
        find.descendant(of: find.byType(MonthGrid), matching: find.text('3')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'MC'));
    await tester.pumpAndSettle();
    expect(repo.writes.single, ('u4', DateTime(DateTime.now().year, DateTime.now().month, 3), 'MC'));
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4);
  });

  testWidgets('sequence: multiple consecutive edits without reload',
      (tester) async {
    final repo = CalendarRepository()..profile = users[1];
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DAVID'));
    await tester.pumpAndSettle();

    // Editar días 1, 2 y 3 consecutivamente
    for (var day = 1; day <= 3; day++) {
      await tester.tap(find.descendant(
          of: find.byType(MonthGrid), matching: find.text('$day')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'MC'));
      await tester.pumpAndSettle();
      expect(repo.writes.length, day);
      expect(repo.writes.last.$1, 'u1');
      expect(
          tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          2);
    }

    expect(repo.loads.length, 1); // No reload occurred
  });

  testWidgets('sequence: rapid taps on day do not open multiple bottom sheets',
      (tester) async {
    final repo = CalendarRepository()..profile = users[1];
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DAVID'));
    await tester.pumpAndSettle();

    // Toque rápido doble en el día 1
    final day1 =
        find.descendant(of: find.byType(MonthGrid), matching: find.text('1'));
    await tester.tap(day1);
    await tester.tap(day1, warnIfMissed: false); // Segundo toque inmediato
    await tester.pumpAndSettle();

    // Debe haber un único bottom sheet activo
    expect(find.widgetWithText(FilledButton, 'MC'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'MC'));
    await tester.pumpAndSettle();

    expect(repo.writes.length, 1);
    expect(repo.writes.single.$1, 'u1');
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2);
  });

  testWidgets(
      'sequence: closing bottom sheet via barrier or drag does not write and preserves user',
      (tester) async {
    final repo = CalendarRepository()..profile = users[1];
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ALEJANDRO'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);

    // 1. Abrir día 1 y cerrar tocando fuera (en la barrera)
    await tester.tap(
        find.descendant(of: find.byType(MonthGrid), matching: find.text('1')));
    await tester.pumpAndSettle();
    expect(find.text('BORRAR SERVICIO'), findsOneWidget);

    // Tocar fuera (barrera modal superior)
    await tester.tapAt(const Offset(100, 50));
    await tester.pumpAndSettle();

    expect(find.text('BORRAR SERVICIO'), findsNothing);
    expect(repo.writes, isEmpty);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);

    // 2. Abrir día 1 y cerrar arrastrando hacia abajo
    await tester.tap(
        find.descendant(of: find.byType(MonthGrid), matching: find.text('1')));
    await tester.pumpAndSettle();
    expect(find.text('BORRAR SERVICIO'), findsOneWidget);

    // Arrastrar hacia abajo para descartar
    await tester.drag(
        find.textContaining('Alejandro'), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.text('BORRAR SERVICIO'), findsNothing);
    expect(repo.writes, isEmpty);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);
  });

  testWidgets(
      'sequence: gesture closing bottom sheet or close to NavigationBar does NOT trigger destination jump to Carlos',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CalendarRepository()..profile = users[1];
    await tester.pumpWidget(MaterialApp(
        home: CalendarScreen(repository: repo, onLogout: () async {})));
    await tester.pumpAndSettle();

    // Seleccionar Juan (u4, índice 4)
    await tester.tap(find.text('JUAN'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4);

    // Abrir día 1
    await tester.tap(
        find.descendant(of: find.byType(MonthGrid), matching: find.text('1')));
    await tester.pumpAndSettle();

    // Tocar 'BORRAR SERVICIO' y simular inmediatamente un toque cercano a NavigationBar (zona de Carlos: x=115, y=810)
    await tester.tap(find.text('BORRAR SERVICIO'));
    // Inmediatamente antes de que expire la animación / guarda, toque en la barra
    await tester.tapAt(const Offset(115, 810));
    await tester.pump();

    // El usuario seleccionado DEBE permanecer en Juan (4), NO saltar a Carlos (1)
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4);

    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4);
    expect(repo.writes.single, ('u4', DateTime(DateTime.now().year, DateTime.now().month, 1), null));

    // Tras expirar la guarda (1s), la navegación voluntaria a Carlos funciona con normalidad
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('CARLOS'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
  });
}
