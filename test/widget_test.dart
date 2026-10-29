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
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('JUAN'), findsOneWidget);
    expect(find.text('ADRIÁN'), findsOneWidget);
    expect(find.text('CARLOS'), findsNothing);
    expect(find.text('ALEJANDRO'), findsNothing);

    await tester.tap(find.text('ADRIÁN'));
    await tester.pumpAndSettle();
    expect(find.text('ADRIÁN'), findsOneWidget);
  });
}
