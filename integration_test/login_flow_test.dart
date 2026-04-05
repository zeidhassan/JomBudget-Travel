// =============================================================================
// integration_test/login_flow_test.dart
//
// Scope: End-to-end integration tests that exercise the complete authentication
// and navigation lifecycle of JomBudgetApp running against the real widget
// tree, including Provider state propagation and Navigator routing.
//
// What this file tests:
//   Multi-user login and logout lifecycle:
//     - A traveler can log in, see the correct dashboard, and log out back to
//       the authentication screen.
//     - An admin can log in immediately after the traveler has logged out,
//       confirming the state is fully reset between sessions.
//     - A vendor can log in and is routed to the Vendor Dashboard.
//
//   New user registration end-to-end:
//     - A brand-new account can be registered through the Register tab.
//     - Registration auto-logs the user in and routes to the correct dashboard.
//     - After logout, the same credentials can be used for a normal login,
//       confirming the account was persisted in the in-memory repository for
//       the duration of the app session.
//
// Why integration tests are used here:
//   Unlike widget tests that isolate individual widgets, integration tests run
//   the full app binary. This verifies that Provider/ChangeNotifier wiring,
//   AppState lifecycle, and bottom-navigation routing work together as a unit
//   — not just in isolation.
//
// Test design constraints:
//   - AppState.seeded() is used so Firebase initialisation is skipped and the
//     tests run fully offline.
//   - A fresh AppState is provided per test group to prevent cross-test
//     state leakage.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jombudget/app/app.dart';
import 'package:jombudget/state/app_state.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Helpers shared across tests
  // ---------------------------------------------------------------------------

  Future<void> loginAs(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      email,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      password,
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
  }

  Future<void> logout(WidgetTester tester) async {
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Multi-user login and logout lifecycle
  // ───────────────────────────────────────────────────────────────────────────

  group('Multi-user login and logout lifecycle', () {
    testWidgets(
      'traveler logs in, sees the Traveler Dashboard, navigates to the '
      'Bookings tab, then logs out and returns to the auth screen',
      (tester) async {
        final state = AppState.seeded();
        await tester.pumpWidget(JomBudgetApp(appState: state));
        await tester.pumpAndSettle();

        // 1. Verify the auth screen is shown on launch.
        expect(find.text('JomBudget'), findsOneWidget);

        // 2. Log in as the seeded traveler.
        await loginAs(
          tester,
          email: 'traveler@student.my',
          password: 'pass123',
        );

        // 3. Traveler-specific dashboard and bottom nav should be present.
        expect(find.text('Traveler Dashboard'), findsOneWidget);
        expect(find.text('Browse'), findsOneWidget);
        expect(find.text('Planner'), findsOneWidget);

        // 4. Navigate to the Bookings tab and verify seed bookings are shown.
        await tester.tap(find.text('Bookings'));
        await tester.pumpAndSettle();

        // Traveler-1 has bookings in the seed data (b-1 is the newest: pending).
        expect(find.text('Batu Ferringhi Budget Stay'), findsOneWidget);

        // 5. Log out and confirm the auth screen returns.
        await logout(tester);

        expect(find.text('JomBudget'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Traveler Dashboard'), findsNothing);
      },
    );

    testWidgets(
      'admin can log in immediately after the traveler logs out, confirming '
      'AppState session is fully cleared between users',
      (tester) async {
        // This test is an explicit regression guard: an earlier bug class
        // in similar apps leaves stale user references after logout, causing
        // the next user to inherit the previous session's role and data.
        final state = AppState.seeded();
        await tester.pumpWidget(JomBudgetApp(appState: state));
        await tester.pumpAndSettle();

        // 1. Traveler logs in.
        await loginAs(
          tester,
          email: 'traveler@student.my',
          password: 'pass123',
        );
        expect(find.text('Traveler Dashboard'), findsOneWidget);

        // 2. Traveler logs out.
        await logout(tester);
        expect(find.text('JomBudget'), findsOneWidget);

        // 3. Admin logs in with the same AppState instance.
        await loginAs(
          tester,
          email: 'admin@jombudget.my',
          password: 'pass123',
        );

        // Admin should see the Admin Dashboard, not the Traveler Dashboard.
        expect(find.text('Admin Dashboard'), findsOneWidget);
        expect(find.text('Traveler Dashboard'), findsNothing);

        // Admin-specific bottom nav destinations.
        expect(find.text('Users'), findsOneWidget);
        expect(find.text('Listings'), findsOneWidget);
        expect(find.text('Destinations'), findsOneWidget);
      },
    );

    testWidgets(
      'vendor logs in and is routed to the Vendor Dashboard with the correct '
      'bottom navigation destinations',
      (tester) async {
        final state = AppState.seeded();
        await tester.pumpWidget(JomBudgetApp(appState: state));
        await tester.pumpAndSettle();

        await loginAs(
          tester,
          email: 'vendor@borneo.my', // u-vendor-3: Borneo Student Trails
          password: 'pass123',
        );

        expect(find.text('Vendor Dashboard'), findsOneWidget);
        // Vendor-specific tabs.
        expect(find.text('Listings'), findsOneWidget);
        expect(find.text('Earnings'), findsOneWidget);
        expect(find.text('Feedback'), findsOneWidget);

        // Vendor should not see Traveler or Admin dashboards.
        expect(find.text('Traveler Dashboard'), findsNothing);
        expect(find.text('Admin Dashboard'), findsNothing);

        // Log out verifies the session terminates cleanly.
        await logout(tester);
        expect(find.text('JomBudget'), findsOneWidget);
        expect(find.text('Vendor Dashboard'), findsNothing);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // New user registration end-to-end
  // ───────────────────────────────────────────────────────────────────────────

  group('New user registration end-to-end', () {
    testWidgets(
      'registering a new traveler account routes to the Traveler Dashboard, '
      'and the account can be used to log in again after logout',
      (tester) async {
        // Use a fresh AppState so the new account persists for the re-login step.
        final state = AppState.seeded();
        await tester.pumpWidget(JomBudgetApp(appState: state));
        await tester.pumpAndSettle();

        // 1. Switch to Register tab.
        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        // 2. Fill in the registration form.
        //    'Name' is unique to the Register form — use it as the anchor.
        await tester.enterText(
          find.widgetWithText(TextField, 'Name'),
          'Integration Test Traveler',
        );
        // 'Email' and 'Password' appear in both Login and Register forms.
        // The Register form is the second tab, so .last selects its fields.
        await tester.enterText(
          find.widgetWithText(TextField, 'Email').last,
          'integration@test.my',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Password').last,
          'integrationpass',
        );
        // Default role is 'traveler' — no change needed.

        // 3. Submit.
        await tester.tap(find.text('Create Account'));
        await tester.pumpAndSettle();

        // 4. Auto-login should route to Traveler Dashboard.
        expect(find.text('Traveler Dashboard'), findsOneWidget);

        // 5. Log out.
        await logout(tester);
        expect(find.text('JomBudget'), findsOneWidget);

        // 6. Re-login with the newly created credentials.
        await loginAs(
          tester,
          email: 'integration@test.my',
          password: 'integrationpass',
        );

        // The account must survive logout and be usable for a normal login.
        expect(find.text('Traveler Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'attempting to register with an already-registered e-mail shows an error '
      'and does not create a duplicate account',
      (tester) async {
        final state = AppState.seeded();
        await tester.pumpWidget(JomBudgetApp(appState: state));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Name'),
          'Duplicate Attempt',
        );
        // traveler@student.my already exists in the seed data.
        await tester.enterText(
          find.widgetWithText(TextField, 'Email').last,
          'traveler@student.my',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Password').last,
          'pass123',
        );

        await tester.tap(find.text('Create Account'));
        await tester.pumpAndSettle();

        // An error must surface — user must stay on the auth screen.
        expect(find.textContaining('already registered'), findsOneWidget);
        expect(find.text('Traveler Dashboard'), findsNothing);
        expect(find.text('JomBudget'), findsOneWidget);
      },
    );
  });
}
