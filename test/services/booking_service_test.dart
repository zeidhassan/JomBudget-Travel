// =============================================================================
// test/services/booking_service_test.dart
//
// Scope: Unit tests for BookingService — the core transactional layer that
// handles booking creation, mock payment processing, vendor decision-making,
// cancellation flows, and completion lifecycle.
//
// What this file tests:
//   - createBooking: correct amount calculation, idempotency guarantee, date
//     validation, listing availability checks, and notification dispatch.
//   - confirmMockPayment: payment record creation, double-pay protection, and
//     notifications to traveler and vendor.
//   - vendorDecision: accept/reject transitions, ownership guard, and
//     traveler notification.
//   - requestCancellation: 48-hour notice enforcement, ownership guard, and
//     vendor notification.
//   - adminOverrideCancellation: forced cancellation with automatic refund
//     status and dual notification.
//   - markCompleted: terminal status transition.
//
// All tests are deterministic — they use SeedData for stable user and listing
// fixtures and construct fresh in-memory repositories in setUp() so that no
// test can pollute the state seen by a later test.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:jombudget/data/in_memory_repositories.dart';
import 'package:jombudget/data/seed_data.dart';
import 'package:jombudget/domain/models.dart';
import 'package:jombudget/services/booking_service.dart';
import 'package:jombudget/services/notification_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Shared test fixtures — rebuilt before every test via the outer setUp().
  // All groups share the same variable bindings but each test starts from a
  // clean slate because setUp() creates fresh repository instances.
  // ---------------------------------------------------------------------------
  late InMemoryUserRepository userRepo;
  late InMemoryListingRepository listingRepo;
  late InMemoryBookingRepository bookingRepo;
  late InMemoryPaymentRepository paymentRepo;
  late InMemoryNotificationRepository notifRepo;
  late BookingService service;

  setUp(() {
    userRepo = InMemoryUserRepository(SeedData.users());
    listingRepo = InMemoryListingRepository(SeedData.listings());
    bookingRepo = InMemoryBookingRepository();
    paymentRepo = InMemoryPaymentRepository();
    notifRepo = InMemoryNotificationRepository();

    service = BookingService(
      bookingRepository: bookingRepo,
      listingRepository: listingRepo,
      paymentRepository: paymentRepo,
      userRepository: userRepo,
      notificationService: NotificationService(notifRepo),
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // createBooking
  // ───────────────────────────────────────────────────────────────────────────

  group('BookingService — createBooking', () {
    // Stable future dates that are always well beyond the 48-hour cancellation
    // window and never overlap with the seed bookings that use _dayOffset.
    final start = DateTime.now().add(const Duration(days: 30));
    final end = start.add(const Duration(days: 2)); // 3-day stay

    test(
      'creates a booking with the correct calculated total amount',
      () {
        // l-1 priceBase = 58 RM.  3 days × 2 pax = 348 RM.
        // days = endDate.difference(startDate).inDays + 1 = 3
        final booking = service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: start,
          endDate: end,
          pax: 2,
          idempotencyKey: 'test-create-amount',
        );

        expect(booking.totalAmount, equals(58 * 3 * 2)); // 348 RM
        expect(booking.listingId, equals('l-1'));
        expect(booking.travelerId, equals('u-traveler-1'));
        expect(booking.vendorId, equals('u-vendor-1'));
        expect(booking.pax, equals(2));
      },
    );

    test(
      'new booking has status=pending and paymentStatus=unpaid',
      () {
        // A freshly created booking should not be auto-confirmed or auto-paid;
        // the vendor must accept and the traveler must complete mock checkout.
        final booking = service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: start,
          endDate: end,
          pax: 1,
          idempotencyKey: 'test-initial-status',
        );

        expect(booking.status, equals(BookingStatus.pending));
        expect(booking.paymentStatus, equals(PaymentStatus.unpaid));
      },
    );

    test(
      'idempotency key: repeated call with same key returns the original '
      'booking and does not create a duplicate',
      () {
        // Idempotency prevents the traveler from accidentally booking twice
        // if the network times out and the app retries the request.
        const key = 'idem-key-duplicate-test';

        final first = service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: start,
          endDate: end,
          pax: 1,
          idempotencyKey: key,
        );

        final second = service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: start,
          endDate: end,
          pax: 1,
          idempotencyKey: key,
        );

        // The repository should still hold exactly one record.
        expect(first.id, equals(second.id));
        expect(bookingRepo.all().length, equals(1));
      },
    );

    test(
      'throws BookingException when startDate is after endDate',
      () {
        // The service must reject logically inverted date ranges before
        // attempting any availability checks.
        expect(
          () => service.createBooking(
            travelerId: 'u-traveler-1',
            listingId: 'l-1',
            startDate: end, // intentionally swapped
            endDate: start,
            pax: 1,
            idempotencyKey: 'test-invalid-dates',
          ),
          throwsA(isA<BookingException>()),
        );
      },
    );

    test(
      'rejects overlapping booking — new start falls inside an existing range',
      () {
        // First traveler books days 30-32 (3-night stay).
        service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: start,
          endDate: end,
          pax: 1,
          idempotencyKey: 'overlap-first',
        );

        // Second traveler attempts to book days 31-33, which overlaps by 2 days.
        // The service must protect against double-booking the same listing.
        expect(
          () => service.createBooking(
            travelerId: 'u-traveler-2',
            listingId: 'l-1',
            startDate: start.add(const Duration(days: 1)),
            endDate: end.add(const Duration(days: 1)),
            pax: 1,
            idempotencyKey: 'overlap-second',
          ),
          throwsA(isA<BookingException>()),
        );
      },
    );

    test(
      'rejects overlapping booking — new range fully contains the existing one',
      () {
        // The overlap check must also catch the case where a wider window
        // completely envelops an already-booked period.
        service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: start.add(const Duration(days: 1)),
          endDate: end.subtract(const Duration(days: 1)),
          pax: 1,
          idempotencyKey: 'contains-inner',
        );

        expect(
          () => service.createBooking(
            travelerId: 'u-traveler-2',
            listingId: 'l-1',
            startDate: start, // wider window
            endDate: end,
            pax: 1,
            idempotencyKey: 'contains-outer',
          ),
          throwsA(isA<BookingException>()),
        );
      },
    );

    test(
      'adjacent (non-overlapping) bookings are both accepted',
      () {
        // Booking A ends on day 32; booking B starts on day 33.
        // The _datesOverlap check uses !endA.isBefore(startB), so same-day
        // adjacency where endA == startB would overlap. Using +1 day gap is safe.
        service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: start,
          endDate: end,
          pax: 1,
          idempotencyKey: 'adjacent-a',
        );

        // This should not throw — no overlap with the previous booking.
        final second = service.createBooking(
          travelerId: 'u-traveler-2',
          listingId: 'l-1',
          startDate: end.add(const Duration(days: 1)),
          endDate: end.add(const Duration(days: 3)),
          pax: 1,
          idempotencyKey: 'adjacent-b',
        );

        expect(second.status, equals(BookingStatus.pending));
        expect(bookingRepo.all().length, equals(2));
      },
    );

    test(
      'throws BookingException when the listing does not exist',
      () {
        expect(
          () => service.createBooking(
            travelerId: 'u-traveler-1',
            listingId: 'l-does-not-exist',
            startDate: start,
            endDate: end,
            pax: 1,
            idempotencyKey: 'test-missing-listing',
          ),
          throwsA(isA<BookingException>()),
        );
      },
    );

    test(
      'throws BookingException when the listing is inactive',
      () {
        // Deactivate listing l-1 to simulate an admin-paused listing.
        final allListings = SeedData.listings()
            .map((l) => l.id == 'l-1' ? l.copyWith(isActive: false) : l)
            .toList();
        final inactiveListingRepo = InMemoryListingRepository(allListings);
        final serviceWithInactive = BookingService(
          bookingRepository: bookingRepo,
          listingRepository: inactiveListingRepo,
          paymentRepository: paymentRepo,
          userRepository: userRepo,
          notificationService: NotificationService(notifRepo),
        );

        expect(
          () => serviceWithInactive.createBooking(
            travelerId: 'u-traveler-1',
            listingId: 'l-1',
            startDate: start,
            endDate: end,
            pax: 1,
            idempotencyKey: 'test-inactive-listing',
          ),
          throwsA(isA<BookingException>()),
        );
      },
    );

    test(
      'sends a notification to the vendor when a booking is created',
      () {
        // l-1 belongs to u-vendor-1. The service must proactively notify the
        // vendor so they can review and accept or reject the request.
        service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: start,
          endDate: end,
          pax: 1,
          idempotencyKey: 'test-vendor-notif',
        );

        final vendorNotifs = notifRepo.byUser('u-vendor-1');
        expect(vendorNotifs, isNotEmpty);
        expect(
          vendorNotifs.any((n) => n.title.contains('booking')),
          isTrue,
        );
      },
    );

    test(
      'sends a notification to admins when a booking is created',
      () {
        // Admins receive a notification for every new booking so they can
        // monitor activity and intervene if needed.
        service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: start,
          endDate: end,
          pax: 1,
          idempotencyKey: 'test-admin-notif',
        );

        final adminNotifs = notifRepo.byUser('u-admin-1');
        expect(adminNotifs, isNotEmpty);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // confirmMockPayment
  // ───────────────────────────────────────────────────────────────────────────

  group('BookingService — confirmMockPayment', () {
    // Helper that creates a fresh booking in the pending/unpaid state.
    Booking _makeBooking() {
      final start = DateTime.now().add(const Duration(days: 30));
      return service.createBooking(
        travelerId: 'u-traveler-1',
        listingId: 'l-1',
        startDate: start,
        endDate: start.add(const Duration(days: 1)),
        pax: 1,
        idempotencyKey: 'payment-test-booking',
      );
    }

    test(
      'creates a PaymentMock record and marks the booking as paid',
      () {
        final booking = _makeBooking();

        final payment = service.confirmMockPayment(
          bookingId: booking.id,
          method: 'Card',
        );

        // A payment record must exist in the repository.
        expect(paymentRepo.all().length, equals(1));
        expect(payment.bookingId, equals(booking.id));
        expect(payment.status, equals(PaymentStatus.paid));

        // The booking's payment status must be updated to paid.
        final updatedBooking = bookingRepo.byId(booking.id)!;
        expect(updatedBooking.paymentStatus, equals(PaymentStatus.paid));
      },
    );

    test(
      'throws BookingException if the same booking is paid a second time',
      () {
        // Double-charging protection: once a booking is paid, calling
        // confirmMockPayment again should be rejected.
        final booking = _makeBooking();
        service.confirmMockPayment(bookingId: booking.id, method: 'Card');

        expect(
          () => service.confirmMockPayment(
            bookingId: booking.id,
            method: 'E-Wallet',
          ),
          throwsA(isA<BookingException>()),
        );
      },
    );

    test(
      'throws BookingException when the booking ID does not exist',
      () {
        expect(
          () => service.confirmMockPayment(
            bookingId: 'non-existent-id',
            method: 'Card',
          ),
          throwsA(isA<BookingException>()),
        );
      },
    );

    test(
      'notifies the traveler that payment was successful',
      () {
        final booking = _makeBooking();
        service.confirmMockPayment(bookingId: booking.id, method: 'Card');

        final travelerNotifs = notifRepo.byUser('u-traveler-1');
        expect(
          travelerNotifs.any((n) => n.title.toLowerCase().contains('payment')),
          isTrue,
        );
      },
    );

    test(
      'notifies the vendor to confirm the paid booking',
      () {
        // After payment, the vendor needs a prompt to either confirm or reject.
        final booking = _makeBooking();
        service.confirmMockPayment(bookingId: booking.id, method: 'Card');

        final vendorNotifs = notifRepo.byUser('u-vendor-1');
        // Vendor receives one notification from createBooking and another from
        // confirmMockPayment — at least the second should reference "paid".
        expect(vendorNotifs.length, greaterThanOrEqualTo(2));
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // vendorDecision
  // ───────────────────────────────────────────────────────────────────────────

  group('BookingService — vendorDecision', () {
    late Booking pendingBooking;

    setUp(() {
      // Create a booking to act on in each test.
      final start = DateTime.now().add(const Duration(days: 30));
      pendingBooking = service.createBooking(
        travelerId: 'u-traveler-1',
        listingId: 'l-1', // owned by u-vendor-1
        startDate: start,
        endDate: start.add(const Duration(days: 1)),
        pax: 1,
        idempotencyKey: 'vendor-decision-booking',
      );
    });

    test(
      'accepting a booking transitions its status to confirmed',
      () {
        service.vendorDecision(
          bookingId: pendingBooking.id,
          accept: true,
          vendorId: 'u-vendor-1',
        );

        final updated = bookingRepo.byId(pendingBooking.id)!;
        expect(updated.status, equals(BookingStatus.confirmed));
      },
    );

    test(
      'rejecting a booking transitions its status to rejected',
      () {
        service.vendorDecision(
          bookingId: pendingBooking.id,
          accept: false,
          vendorId: 'u-vendor-1',
        );

        final updated = bookingRepo.byId(pendingBooking.id)!;
        expect(updated.status, equals(BookingStatus.rejected));
      },
    );

    test(
      'throws BookingException when a different vendor tries to decide',
      () {
        // Ownership guard: u-vendor-2 does not own listing l-1, so they
        // must not be able to accept or reject bookings on it.
        expect(
          () => service.vendorDecision(
            bookingId: pendingBooking.id,
            accept: true,
            vendorId: 'u-vendor-2',
          ),
          throwsA(isA<BookingException>()),
        );
      },
    );

    test(
      'notifies the traveler of the vendor decision',
      () {
        service.vendorDecision(
          bookingId: pendingBooking.id,
          accept: true,
          vendorId: 'u-vendor-1',
        );

        final travelerNotifs = notifRepo.byUser('u-traveler-1');
        expect(
          travelerNotifs.any(
            (n) => n.title.toLowerCase().contains('confirmed'),
          ),
          isTrue,
        );
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // requestCancellation
  // ───────────────────────────────────────────────────────────────────────────

  group('BookingService — requestCancellation', () {
    test(
      'succeeds when the start date is more than 48 hours away',
      () {
        final farFutureStart = DateTime.now().add(const Duration(days: 7));
        final booking = service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: farFutureStart,
          endDate: farFutureStart.add(const Duration(days: 1)),
          pax: 1,
          idempotencyKey: 'cancel-far-future',
        );

        // No exception expected — cancellation is within policy.
        service.requestCancellation(
          bookingId: booking.id,
          travelerId: 'u-traveler-1',
        );

        final updated = bookingRepo.byId(booking.id)!;
        expect(updated.status, equals(BookingStatus.cancelRequested));
      },
    );

    test(
      'throws BookingException when the start date is within 48 hours',
      () {
        // The cancellation policy requires at least 48 hours notice.
        // A booking starting in 24 hours must be rejected.
        final nearFutureStart = DateTime.now().add(const Duration(hours: 24));
        final booking = service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: nearFutureStart,
          endDate: nearFutureStart.add(const Duration(days: 1)),
          pax: 1,
          idempotencyKey: 'cancel-near-future',
        );

        expect(
          () => service.requestCancellation(
            bookingId: booking.id,
            travelerId: 'u-traveler-1',
          ),
          throwsA(isA<BookingException>()),
        );
      },
    );

    test(
      'throws BookingException when a different traveler attempts cancellation',
      () {
        // Ownership guard: only the traveler who created the booking may
        // request its cancellation.
        final futureStart = DateTime.now().add(const Duration(days: 7));
        final booking = service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: futureStart,
          endDate: futureStart.add(const Duration(days: 1)),
          pax: 1,
          idempotencyKey: 'cancel-wrong-traveler',
        );

        expect(
          () => service.requestCancellation(
            bookingId: booking.id,
            travelerId: 'u-traveler-2', // not the booking owner
          ),
          throwsA(isA<BookingException>()),
        );
      },
    );

    test(
      'notifies the vendor when a cancellation is requested',
      () {
        final futureStart = DateTime.now().add(const Duration(days: 7));
        final booking = service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: futureStart,
          endDate: futureStart.add(const Duration(days: 1)),
          pax: 1,
          idempotencyKey: 'cancel-notify-vendor',
        );

        service.requestCancellation(
          bookingId: booking.id,
          travelerId: 'u-traveler-1',
        );

        final vendorNotifs = notifRepo.byUser('u-vendor-1');
        expect(
          vendorNotifs.any(
            (n) => n.title.toLowerCase().contains('cancell'),
          ),
          isTrue,
        );
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // adminOverrideCancellation
  // ───────────────────────────────────────────────────────────────────────────

  group('BookingService — adminOverrideCancellation', () {
    test(
      'sets booking status to cancelled and payment status to refunded',
      () {
        final futureStart = DateTime.now().add(const Duration(days: 7));
        final booking = service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: futureStart,
          endDate: futureStart.add(const Duration(days: 1)),
          pax: 1,
          idempotencyKey: 'admin-override-test',
        );

        service.adminOverrideCancellation(
          bookingId: booking.id,
          reason: 'Listing removed by vendor request.',
        );

        final updated = bookingRepo.byId(booking.id)!;
        expect(updated.status, equals(BookingStatus.cancelled));
        expect(updated.paymentStatus, equals(PaymentStatus.refunded));
      },
    );

    test(
      'notifies both the traveler and the vendor of the admin cancellation',
      () {
        final futureStart = DateTime.now().add(const Duration(days: 7));
        final booking = service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: futureStart,
          endDate: futureStart.add(const Duration(days: 1)),
          pax: 1,
          idempotencyKey: 'admin-override-notify',
        );

        service.adminOverrideCancellation(
          bookingId: booking.id,
          reason: 'Policy violation.',
        );

        // Both affected parties must be informed.
        final travelerNotifs = notifRepo.byUser('u-traveler-1');
        final vendorNotifs = notifRepo.byUser('u-vendor-1');

        expect(
          travelerNotifs.any(
            (n) => n.title.toLowerCase().contains('cancelled'),
          ),
          isTrue,
        );
        expect(
          vendorNotifs.any(
            (n) => n.title.toLowerCase().contains('cancelled'),
          ),
          isTrue,
        );
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // markCompleted
  // ───────────────────────────────────────────────────────────────────────────

  group('BookingService — markCompleted', () {
    test(
      'transitions booking status to completed',
      () {
        // Once the traveler has experienced the service, the booking moves to
        // the terminal "completed" state, which unlocks the review flow.
        final futureStart = DateTime.now().add(const Duration(days: 30));
        final booking = service.createBooking(
          travelerId: 'u-traveler-1',
          listingId: 'l-1',
          startDate: futureStart,
          endDate: futureStart.add(const Duration(days: 1)),
          pax: 1,
          idempotencyKey: 'mark-completed-test',
        );

        service.markCompleted(booking.id);

        final updated = bookingRepo.byId(booking.id)!;
        expect(updated.status, equals(BookingStatus.completed));
      },
    );

    test(
      'throws BookingException when booking ID is not found',
      () {
        expect(
          () => service.markCompleted('id-that-does-not-exist'),
          throwsA(isA<BookingException>()),
        );
      },
    );
  });
}
