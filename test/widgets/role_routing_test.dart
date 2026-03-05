import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jombudget/app/app.dart';
import 'package:jombudget/state/app_state.dart';

void main() {
  testWidgets('starts on auth screen', (tester) async {
    await tester.pumpWidget(const JomBudgetApp());

    expect(find.text('JomBudget'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('routes to traveler dashboard after login', (tester) async {
    final state = AppState.seeded();
    await tester.pumpWidget(JomBudgetApp(appState: state));

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'traveler@student.my',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'pass123',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Traveler Dashboard'), findsOneWidget);
  });

  testWidgets('routes to admin dashboard after login', (tester) async {
    final state = AppState.seeded();
    await tester.pumpWidget(JomBudgetApp(appState: state));

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'admin@jombudget.my',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'pass123',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Admin Dashboard'), findsOneWidget);
  });
}
