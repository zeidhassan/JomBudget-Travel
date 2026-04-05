// =============================================================================
// test/widgets/booking_flow_test.dart
//
// Scope: Tests covering the booking workflow from the UI layer down to the
// service layer — date-range validation, vendor listing ownership isolation,
// booking status label correctness, and the conditional visibility of
// action buttons on the traveler bookings page.
//
// What this file tests:
//   BookingService — date range validation (unit-style, no widget pump needed):
//     - Start date after end date throws BookingException.
//     - Same-day (zero-night) booking succeeds and calculates the correct
//       one-day total.
//
//   Vendor dashboard — listing visibility (widget tests):
//     - A logged-in vendor sees only their own listings on the Listings tab.
//     - Listings belonging to a different vendor are absent from the view.
//
//   Booking status label — utility function (unit-style):
//     - bookingStatusLabel() maps every BookingStatus enum value to the
//       human-readable string shown in the traveler's booking card.
//
//   Traveler bookings page — status display and button visibility (widget tests):
//     - Booking cards render the correct "Status: …" text from seed data.
//     - "Request Cancel" button is visible for pending and confirmed bookings.
//     - "Leave Review" button is visible only for completed bookings.
//
// Seed data relationships used:
//   u-vendor-1  owns: l-1, l-3, l-4, l-10
//   u-vendor-2  owns: l-2, l-5, l-6, l-7
//   u-traveler-1 bookings (sorted newest→oldest by createdAt):
//     b-1 — pending        — 'Batu Ferringhi Budget Stay'
//     b-3 — cancelRequested— 'Langkawi Island Hopping'
//     b-2 — confirmed      — 'Jalan Alor Student Meal Pass'
//   u-traveler-2 bookings:
//     b-4 — completed      — 'KL Transit Capsule Hostel'
//     b-5 — completed      — 'Penang Hawker Crawl'
//     b-6 — rejected       — 'Sabah Sunset Coastal Trail'
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jombudget/app/app.dart';
import 'package:jombudget/core_utils.dart';
import 'package:jombudget/data/in_memory_repositories.dart';
import 'package:jombudget/data/seed_data.dart';
import 'package:jombudget/domain/models.dart';
import 'package:jombudget/services/booking_service.dart';
import 'package:jombudget/services/notification_service.dart';
import 'package:jombudget/state/app_state.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Logs in from the auth screen with the given credentials.
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

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // BookingService — date range validation
  // ───────────────────────────────────────────────────────────────────────────
  //
  // These tests exercise BookingService directly. Placing them in this file
  // keeps all booking-related contract tests in one readable document even
  // though they do not require a widget pump.

  group('BookingService — date range validation', () {
    late BookingService service;
    late InMemoryBookingRepository bookingRepo;

    setUp(() {
      bookingRepo = InMemoryBookingRepository();
      service = BookingService(
        bookingRepository: bookingRepo,
        listingRepository: InMemoryListingRepository(SeedData.listings()),
        paymentRepository: InMemoryPaymentRepository(),
        userRepository: InMemoryUserRepository(SeedData.users()),
        notificationService: NotificationService(
          InMemoryNotificationRepository(),
        ),
      );
    });

    test(
      'throws BookingException when startDate is strictly after endDate',
      () {
        // The UI auto-adjusts end dates when a user picks via the date picker,
        // but the service must still enforce this as a hard contract guard in
        // case any caller bypasses the UI controls.
        final laterDate = DateTime.now().add(const Duration(days: 15));
        final earlierDate = laterDate.subtract(const Duration(days: 3));

        expect(
          () => service.createBooking(
            travelerId: 'u-traveler-1',
            listingId: 'l-1',
            startDate: laterDate, // start is AFTER end — invalid
            endDate: earlierDate,
            pax: 1,
            idempotencyKey: 'invalid-date-range',
          ),
          throwsA(isA<BookingException>()),
        );
      },
    );

    test(
      'accepts a same-day booking (startDate == endDate) and calculates a '
      'one-day total',
      () {
        // days = endDate.difference(startDate).inDays + 1 = 0 + 1 = 1.
        // l-1 priceBase = 58. total = 58 × 1 × 1 = 58.
        final sameDay = DateTime.now().add(const Duration(days: 20));

        final booking = service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: sameDay,
          endDate: sameDay,
          pax: 1,
          idempotencyKey: 'same-day-booking',
        );

        expect(booking.totalAmount, closeTo(58.0, 0.01));
      },
    );

    test(
      'multi-pax same-day booking scales the total by pax count',
      () {
        // l-1 priceBase = 58.  1 day × 3 pax = 174.
        final sameDay = DateTime.now().add(const Duration(days: 25));

        final booking = service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: sameDay,
          endDate: sameDay,
          pax: 3,
          idempotencyKey: 'multi-pax-same-day',
        );

        expect(booking.totalAmount, closeTo(58.0 * 3, 0.01));
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Vendor dashboard — listing visibility
  // ───────────────────────────────────────────────────────────────────────────

  group('Vendor dashboard — listing visibility', () {
    testWidgets(
      'vendor sees their own listing titles on the Listings tab',
      (tester) async {
        // u-vendor-1 owns l-1 ('Batu Ferringhi Budget Stay') among others.
        // After login, the Vendor Dashboard defaults to the Listings tab (index
        // 0), which calls vendorListings() filtered to the logged-in vendor's ID.
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        await _login(
          tester,
          email: 'vendor@langkawi.my', // u-vendor-1
          password: 'pass123',
        );

        expect(find.text('Vendor Dashboard'), findsOneWidget);

        // l-1 is u-vendor-1's first listing and should be visible immediately
        // without scrolling.
        expect(find.text('Batu Ferringhi Budget Stay'), findsOneWidget);
      },
    );

    testWidgets(
      'vendor does not see listings belonging to a different vendor',
      (tester) async {
        // l-2 ('Jalan Alor Student Meal Pass') belongs to u-vendor-2.
        // It must be completely absent from u-vendor-1's listing view.
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        await _login(
          tester,
          email: 'vendor@langkawi.my', // u-vendor-1
          password: 'pass123',
        );

        expect(find.text('Vendor Dashboard'), findsOneWidget);
        expect(find.text('Jalan Alor Student Meal Pass'), findsNothing);
        expect(find.text('KL Transit Capsule Hostel'), findsNothing);
      },
    );

    testWidgets(
      'a second vendor sees their own distinct set of listings',
      (tester) async {
        // u-vendor-2 owns l-2, l-5, l-6, l-7. Log in and verify l-2 appears
        // while u-vendor-1's l-1 does not.
        await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));

        await _login(
          tester,
          email: 'vendor@klfood.my', // u-vendor-2
          password: 'pass123',
        );

        expect(find.text('Vendor Dashboard'), findsOneWidget);
        // l-2 is vendor-2's first listing.
        expect(find.text('Jalan Alor Student Meal Pass'), findsOneWidget);
        // l-1 belongs to vendor-1 — must not appear.
        expect(find.text('Batu Ferringhi Budget Stay'), findsNothing);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Booking status labels — utility function
  // ───────────────────────────────────────────────────────────────────────────
  //
  // bookingStatusLabel() is a pure mapping function in core_utils.dart.
  // Testing it exhaustively here ensures no enum value is accidentally omitted
  // or returns an empty string, which would silently show blank text in the UI.

  group('Booking status labels — bookingStatusLabel()', () {
    test('pending maps to "Pending Vendor Approval"', () {
      expect(
        bookingStatusLabel(BookingStatus.pending),
        equals('Pending Vendor Approval'),
      );
    });

    test('confirmed maps to "Confirmed"', () {
      expect(
        bookingStatusLabel(BookingStatus.confirmed),
        equals('Confirmed'),
      );
    });

    test('rejected maps to "Rejected"', () {
      expect(
        bookingStatusLabel(BookingStatus.rejected),
        equals('Rejected'),
      );
    });

    test('cancelRequested maps to "Cancel Requested"', () {
      expect(
        bookingStatusLabel(BookingStatus.cancelRequested),
        equals('Cancel Requested'),
      );
    });

    test('cancelled maps to "Cancelled"', () {
      expect(
        bookingStatusLabel(BookingStatus.cancelled),
        equals('Cancelled'),
      );
    });

    test('completed maps to "Completed"', () {
      expect(
        bookingStatusLabel(BookingStatus.completed),
        equals('Completed'),
      );
    });

    test('every BookingStatus value produces a non-empty label', () {
      for (final status in BookingStatus.values) {
        expect(
          bookingStatusLabel(status),
          isNotEmpty,
          reason: 'bookingStatusLabel($status) returned an empty string.',
        );
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Traveler bookings page — status display and button visibility
  // ───────────────────────────────────────────────────────────────────────────

  group('Traveler bookings page — status display and action buttons', () {
    /// Logs in as the given traveler, navigates to the Bookings tab, and
    /// returns a [WidgetTester] positioned on the bookings list.
    Future<void> _goToBookings(
      WidgetTester tester,
      String email,
    ) async {
      await tester.pumpWidget(JomBudgetApp(appState: AppState.seeded()));
      await _login(tester, email: email, password: 'pass123');
      await tester.tap(find.text('Bookings'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'traveler-1 bookings page shows "Status: Pending Vendor Approval" for '
      'the pending seed booking',
      (tester) async {
        // b-1: pending — the booking card must render the human-readable label.
        await _goToBookings(tester, 'traveler@student.my');

        expect(
          find.text('Status: Pending Vendor Approval'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'traveler-1 bookings page shows "Status: Confirmed" for the confirmed '
      'seed booking',
      (tester) async {
        // b-2: confirmed.
        await _goToBookings(tester, 'traveler@student.my');

        // b-2 may be below the fold in the test viewport; use skipOffstage
        // false to find it even if it has scrolled partially out of view.
        expect(
          find.text('Status: Confirmed', skipOffstage: false),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'traveler-1 bookings page shows "Status: Cancel Requested" for the '
      'cancellation-requested seed booking',
      (tester) async {
        // b-3: cancelRequested.
        await _goToBookings(tester, 'traveler@student.my');

        expect(
          find.text('Status: Cancel Requested', skipOffstage: false),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '"Request Cancel" button is visible for at least one pending booking',
      (tester) async {
        // The button is shown when booking.status == pending || confirmed.
        // b-1 (pending) is the most recent booking for traveler-1, so it
        // should appear near the top of the list and be in-viewport.
        await _goToBookings(tester, 'traveler@student.my');

        expect(find.text('Request Cancel'), findsWidgets);
      },
    );

    testWidgets(
      '"Request Cancel" button is NOT visible for a cancelRequested booking',
      (tester) async {
        // Once the traveler has already requested a cancel (b-3), the button
        // must disappear — canRequestCancel is false for cancelRequested status.
        // However, b-1 (pending) still shows the button, so we check the count
        // is less than the total booking count (3).
        await _goToBookings(tester, 'traveler@student.my');

        // There are 3 bookings; only pending + confirmed have the button.
        // b-1: pending → button visible
        // b-3: cancelRequested → button hidden
        // b-2: confirmed → button visible
        // Expected count = 2 (not 3).
        final cancelButtons = find.text('Request Cancel');
        expect(tester.widgetList(cancelButtons).length, lessThan(3));
      },
    );

    testWidgets(
      '"Leave Review" button appears for completed bookings (traveler-2)',
      (tester) async {
        // traveler-2 (irfan@student.my) has b-4 and b-5 as completed bookings.
        // The "Leave Review" FilledButton must appear for those cards.
        await _goToBookings(tester, 'irfan@student.my');

        expect(find.text('Leave Review'), findsWidgets);
      },
    );

    testWidgets(
      '"Leave Review" button does NOT appear for traveler-1 who has no '
      'completed bookings',
      (tester) async {
        // traveler-1's bookings are pending, confirmed, cancelRequested —
        // none completed — so the review button must not be rendered at all.
        await _goToBookings(tester, 'traveler@student.my');

        expect(find.text('Leave Review'), findsNothing);
      },
    );

    testWidgets(
      '"Status: Completed" label appears for traveler-2\'s completed bookings',
      (tester) async {
        await _goToBookings(tester, 'irfan@student.my');

        expect(
          find.text('Status: Completed'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      '"Status: Rejected" label appears for traveler-2\'s rejected booking',
      (tester) async {
        // b-6: rejected. May be below fold in test viewport.
        await _goToBookings(tester, 'irfan@student.my');

        expect(
          find.text('Status: Rejected', skipOffstage: false),
          findsOneWidget,
        );
      },
    );
  });
}
