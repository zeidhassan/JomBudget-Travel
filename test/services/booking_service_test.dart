import 'package:flutter_test/flutter_test.dart';

import 'package:jombudget/data/in_memory_repositories.dart';
import 'package:jombudget/data/seed_data.dart';
import 'package:jombudget/services/booking_service.dart';
import 'package:jombudget/services/notification_service.dart';

void main() {
  group('BookingService', () {
    late InMemoryUserRepository userRepository;
    late InMemoryListingRepository listingRepository;
    late InMemoryBookingRepository bookingRepository;
    late InMemoryPaymentRepository paymentRepository;
    late InMemoryNotificationRepository notificationRepository;
    late BookingService bookingService;

    setUp(() {
      userRepository = InMemoryUserRepository(SeedData.users());
      listingRepository = InMemoryListingRepository(SeedData.listings());
      bookingRepository = InMemoryBookingRepository();
      paymentRepository = InMemoryPaymentRepository();
      notificationRepository = InMemoryNotificationRepository();

      bookingService = BookingService(
        bookingRepository: bookingRepository,
        listingRepository: listingRepository,
        paymentRepository: paymentRepository,
        userRepository: userRepository,
        notificationService: NotificationService(notificationRepository),
      );
    });

    test('idempotency key returns existing booking', () {
      final startDate = DateTime.now().add(const Duration(days: 10));
      final endDate = startDate.add(const Duration(days: 2));

      final first = bookingService.createBooking(
        travelerId: 'u-traveler-1',
        listingId: 'l-1',
        startDate: startDate,
        endDate: endDate,
        pax: 1,
        idempotencyKey: 'idem-a',
      );

      final second = bookingService.createBooking(
        travelerId: 'u-traveler-1',
        listingId: 'l-1',
        startDate: startDate,
        endDate: endDate,
        pax: 1,
        idempotencyKey: 'idem-a',
      );

      expect(first.id, second.id);
      expect(bookingRepository.all().length, 1);
    });

    test('overlapping booking windows are rejected', () {
      final startDate = DateTime.now().add(const Duration(days: 12));
      final endDate = startDate.add(const Duration(days: 2));

      bookingService.createBooking(
        travelerId: 'u-traveler-1',
        listingId: 'l-1',
        startDate: startDate,
        endDate: endDate,
        pax: 1,
        idempotencyKey: 'slot-a',
      );

      expect(
        () => bookingService.createBooking(
          travelerId: 'u-traveler-2',
          listingId: 'l-1',
          startDate: startDate.add(const Duration(days: 1)),
          endDate: endDate.add(const Duration(days: 1)),
          pax: 1,
          idempotencyKey: 'slot-b',
        ),
        throwsA(isA<BookingException>()),
      );
    });
  });
}
