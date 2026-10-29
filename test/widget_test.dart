import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turneo/src/auth/login_screen.dart';
import 'package:turneo/src/models/turneo_models.dart';

void main() {
  test('month title uses Spanish month name', () {
    final d = MonthData(
        month: DateTime(2026, 9),
        assignments: {},
        colors: {},
        users: const [],
        holidays: {});
    expect(d.title, 'SEPTIEMBRE 2026');
  });

  testWidgets('registration selector exposes only the ordered active users',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: LoginScreen(onSignedIn: () {})));
    await tester.tap(find.text('REGISTRO INICIAL'));
    await tester.pump();

    final options = tester
        .widgetList<DropdownMenuItem<String>>(find.byType(DropdownMenuItem))
        .toList();
    expect(options.map((item) => item.value), ['u4', 'u5']);
    expect(find.text('JUAN'), findsOneWidget);
    expect(find.text('ADRIÁN'), findsOneWidget);
    expect(find.text('DAVID'), findsNothing);
  });
}
