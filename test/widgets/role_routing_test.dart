// =============================================================================
// test/widgets/role_routing_test.dart
//
// Scope: Widget tests that verify the top-level routing logic of JomBudgetApp
// — specifically, that the correct dashboard is shown for each user role after
// login, that authentication errors surface clearly to the user, and that
// logout correctly returns to the authentication screen.
//
// What this file tests:
//   - Authentication screen: correct structure (Login / Register tabs,
//     demo credentials card) before any login.
//   - Role-based routing: traveler → Traveler Dashboard, vendor → Vendor
//     Dashboard, admin → Admin Dashboard.
//   - Error handling: wrong password and unknown e-mail each produce a
//     descriptive SnackBar; the user stays on the auth screen.
//   - Logout: tapping "Log Out" from the traveler and vendor profile pages
//     returns the user to the login screen.
//   - Registration: creating a new account immediately routes to the
//     appropriate dashboard without requiring a separate login.
//
// All tests create a fresh AppState.seeded() instance so that state mutations
// from one test can never bleed into another. The seeded state uses
// enableCloudSync: false (default), meaning no Firebase calls are made.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jombudget/app/app.dart';
import 'package:jombudget/state/app_state.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Signs in with [email] and [password] from the login tab.
Future<void> _login(
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

/// Navigates to the Profile tab and taps "Log Out".
/// Works for any dashboard that has a 'Profile' bottom-nav destination.
Future<void> _logout(WidgetTester tester) async {
  await tester.tap(find.text('Profile'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Log Out'));
  await tester.pumpAndSettle();
}

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // Authentication screen structure
  // ───────────────────────────────────────────────────────────────────────────

  group('Authentication screen', () {
    testWidgets(
      'shows the JomBudget title and Login / Register tabs on first launch',
      (tester) async {
        // On a fresh launch with no logged-in user, the app should always
        // land on the authentication screen — never on a role dashboard.
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        expect(find.text('JomBudget'), findsOneWidget);
        expect(find.text('Login'), findsOneWidget);
        expect(find.text('Register'), findsOneWidget);
      },
    );

    testWidgets(
      'login tab displays the demo credentials card for easy test access',
      (tester) async {
        // The demo card lists all seeded accounts so that during development
        // and grading the app is trivially accessible without memorising creds.
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        expect(find.textContaining('traveler@student.my'), findsOneWidget);
        expect(find.textContaining('admin@jombudget.my'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Role-based dashboard routing
  // ───────────────────────────────────────────────────────────────────────────

  group('Role-based dashboard routing', () {
    testWidgets(
      'routes a traveler to the Traveler Dashboard after successful login',
      (tester) async {
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        await _login(
          tester,
          email: 'traveler@student.my',
          password: 'pass123',
        );

        expect(find.text('Traveler Dashboard'), findsOneWidget);
        // Bottom-nav destinations specific to the traveler shell.
        expect(find.text('Browse'), findsOneWidget);
        expect(find.text('Planner'), findsOneWidget);
      },
    );

    testWidgets(
      'routes a vendor to the Vendor Dashboard after successful login',
      (tester) async {
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        await _login(
          tester,
          email: 'vendor@langkawi.my',
          password: 'pass123',
        );

        expect(find.text('Vendor Dashboard'), findsOneWidget);
        // Bottom-nav destinations specific to the vendor shell.
        expect(find.text('Listings'), findsOneWidget);
        expect(find.text('Earnings'), findsOneWidget);
      },
    );

    testWidgets(
      'routes an admin to the Admin Dashboard after successful login',
      (tester) async {
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        await _login(
          tester,
          email: 'admin@jombudget.my',
          password: 'pass123',
        );

        expect(find.text('Admin Dashboard'), findsOneWidget);
        // Bottom-nav destinations specific to the admin shell.
        expect(find.text('Users'), findsOneWidget);
        expect(find.text('Reports'), findsOneWidget);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Authentication error handling
  // ───────────────────────────────────────────────────────────────────────────

  group('Authentication error handling', () {
    testWidgets(
      'shows an error SnackBar and stays on auth screen for a wrong password',
      (tester) async {
        // The AuthService throws AuthException('Invalid password.') which
        // AppState maps to lastError; the UI surfaces it in a SnackBar.
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        await _login(
          tester,
          email: 'traveler@student.my',
          password: 'wrongpassword',
        );

        // Error text should appear inside the SnackBar.
        expect(find.text('Invalid password.'), findsOneWidget);
        // User must NOT have been routed to any dashboard.
        expect(find.text('Traveler Dashboard'), findsNothing);
        expect(find.text('JomBudget'), findsOneWidget);
      },
    );

    testWidgets(
      'shows an error SnackBar for an e-mail address that is not registered',
      (tester) async {
        // AuthService throws AuthException('No account found for …') when the
        // e-mail lookup returns null.
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        await _login(
          tester,
          email: 'nobody@nowhere.my',
          password: 'pass123',
        );

        // The SnackBar content must reference the unknown e-mail address.
        expect(
          find.textContaining('No account found'),
          findsOneWidget,
        );
        expect(find.text('Traveler Dashboard'), findsNothing);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Logout flow
  // ───────────────────────────────────────────────────────────────────────────

  group('Logout flow', () {
    testWidgets(
      'traveler tapping Log Out on the Profile tab returns to the auth screen',
      (tester) async {
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        await _login(
          tester,
          email: 'traveler@student.my',
          password: 'pass123',
        );
        expect(find.text('Traveler Dashboard'), findsOneWidget);

        await _logout(tester);

        // After logout the user should see the auth screen again.
        expect(find.text('JomBudget'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Traveler Dashboard'), findsNothing);
      },
    );

    testWidgets(
      'vendor tapping Log Out on the Profile tab returns to the auth screen',
      (tester) async {
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        await _login(
          tester,
          email: 'vendor@klfood.my',
          password: 'pass123',
        );
        expect(find.text('Vendor Dashboard'), findsOneWidget);

        await _logout(tester);

        expect(find.text('JomBudget'), findsOneWidget);
        expect(find.text('Vendor Dashboard'), findsNothing);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // New user registration
  // ───────────────────────────────────────────────────────────────────────────

  group('New user registration', () {
    testWidgets(
      'registering a new traveler account auto-logs in and shows the '
      'Traveler Dashboard',
      (tester) async {
        // Registration in AppState immediately sets _currentUser and calls
        // notifyListeners, which triggers the _HomeRouter to route to RoleShell.
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        // Switch to the Register tab.
        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        // 'Name' label is unique to the Register form — use it as an anchor.
        await tester.enterText(
          find.widgetWithText(TextField, 'Name'),
          'Test Traveler',
        );

        // Both Login and Register forms contain 'Email' and 'Password' fields.
        // The Register form renders after the Login form in the PageView, so
        // .last selects the Register tab's field in the widget tree.
        await tester.enterText(
          find.widgetWithText(TextField, 'Email').last,
          'newstudent@test.my',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Password').last,
          'newpass456',
        );

        await tester.tap(find.text('Create Account'));
        await tester.pumpAndSettle();

        // Default role in the Register form is UserRole.traveler.
        expect(find.text('Traveler Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'registering with an already-used e-mail shows an error SnackBar',
      (tester) async {
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Name'),
          'Duplicate User',
        );
        // traveler@student.my is already seeded — registration must fail.
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

        expect(find.textContaining('already registered'), findsOneWidget);
        expect(find.text('Traveler Dashboard'), findsNothing);
      },
    );
  });
}
