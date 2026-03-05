import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jombudget/app/app.dart';
import 'package:jombudget/state/app_state.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('traveler and admin login smoke flow', (tester) async {
    final state = AppState.seeded();
    await tester.pumpWidget(JomBudgetApp(appState: state));
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

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
