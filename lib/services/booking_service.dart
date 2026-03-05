import 'package:uuid/uuid.dart';

import '../data/in_memory_repositories.dart';
import '../domain/models.dart';
import 'notification_service.dart';

class BookingException implements Exception {
  BookingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BookingService {
  BookingService({
    required BookingRepository bookingRepository,
    required ListingRepository listingRepository,
    required PaymentRepository paymentRepository,
    required UserRepository userRepository,
    required NotificationService notificationService,
  }) : _bookingRepository = bookingRepository,
       _listingRepository = listingRepository,
       _paymentRepository = paymentRepository,
       _userRepository = userRepository,
       _notificationService = notificationService;

  final BookingRepository _bookingRepository;
  final ListingRepository _listingRepository;
  final PaymentRepository _paymentRepository;
  final UserRepository _userRepository;
  final NotificationService _notificationService;
  final Uuid _uuid = const Uuid();

  Booking createBooking({
    required String travelerId,
    required String listingId,
    required DateTime startDate,
    required DateTime endDate,
    required int pax,
    required String idempotencyKey,
  }) {
    if (startDate.isAfter(endDate)) {
      throw BookingException('Start date cannot be after end date.');
    }

    final duplicate = _bookingRepository.byIdempotencyKey(idempotencyKey);
    if (duplicate != null) {
      return duplicate;
    }

    final listing = _listingRepository.byId(listingId);
    if (listing == null || !listing.isActive) {
      throw BookingException('Listing is not available anymore.');
    }

    final overlapping = _bookingRepository.byListing(listingId).where((entry) {
      final blocksAvailability =
          entry.status == BookingStatus.pending ||
          entry.status == BookingStatus.confirmed;
      return blocksAvailability &&
          _datesOverlap(startDate, endDate, entry.startDate, entry.endDate);
    });
    if (overlapping.isNotEmpty) {
      throw BookingException(
        'Selected dates are unavailable. Please choose another date range.',
      );
    }

    final days = endDate.difference(startDate).inDays + 1;
    final total = listing.priceBase * (days < 1 ? 1 : days) * pax;

    final booking = Booking(
      id: _uuid.v4(),
      travelerId: travelerId,
      listingId: listingId,
      listingTitle: listing.title,
      vendorId: listing.vendorId,
      startDate: startDate,
      endDate: endDate,
      pax: pax,
      status: BookingStatus.pending,
      paymentStatus: PaymentStatus.unpaid,
      totalAmount: total,
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.now(),
    );

    _bookingRepository.add(booking);

    _notificationService.notifyUser(
      userId: listing.vendorId,
      title: 'New booking request',
      body: '${listing.title} has a new pending booking.',
    );
    _notifyAdmins(
      title: 'Booking created',
      body: 'A new booking is awaiting payment/approval.',
    );

    return booking;
  }

  PaymentMock confirmMockPayment({
    required String bookingId,
    required String method,
  }) {
    final booking = _bookingRepository.byId(bookingId);
    if (booking == null) {
      throw BookingException('Booking not found.');
    }
    if (booking.paymentStatus == PaymentStatus.paid) {
      throw BookingException('Booking is already paid.');
    }

    final payment = PaymentMock(
      id: _uuid.v4(),
      bookingId: booking.id,
      amount: booking.totalAmount,
      method: method,
      createdAt: DateTime.now(),
      status: PaymentStatus.paid,
    );

    _paymentRepository.add(payment);
    _bookingRepository.update(
      booking.copyWith(paymentStatus: PaymentStatus.paid),
    );

    _notificationService.notifyUser(
      userId: booking.travelerId,
      title: 'Payment successful',
      body:
          'Payment received for ${booking.listingTitle}. Awaiting vendor confirmation.',
    );
    _notificationService.notifyUser(
      userId: booking.vendorId,
      title: 'Paid booking pending action',
      body: 'Please confirm booking for ${booking.listingTitle}.',
    );

    return payment;
  }

  void vendorDecision({
    required String bookingId,
    required bool accept,
    required String vendorId,
  }) {
    final booking = _bookingRepository.byId(bookingId);
    if (booking == null) {
      throw BookingException('Booking not found.');
    }
    if (booking.vendorId != vendorId) {
      throw BookingException('Vendor is not allowed to update this booking.');
    }

    final nextStatus = accept
        ? BookingStatus.confirmed
        : BookingStatus.rejected;
    _bookingRepository.update(booking.copyWith(status: nextStatus));

    _notificationService.notifyUser(
      userId: booking.travelerId,
      title: accept ? 'Booking confirmed' : 'Booking rejected',
      body:
          '${booking.listingTitle}: ${accept ? 'confirmed by vendor.' : 'vendor rejected the booking.'}',
    );

    _notifyAdmins(
      title: 'Booking status updated',
      body: 'Vendor marked ${booking.listingTitle} as ${nextStatus.name}.',
    );
  }

  void requestCancellation({
    required String bookingId,
    required String travelerId,
  }) {
    final booking = _bookingRepository.byId(bookingId);
    if (booking == null) {
      throw BookingException('Booking not found.');
    }
    if (booking.travelerId != travelerId) {
      throw BookingException('Traveler mismatch for cancellation request.');
    }

    if (booking.startDate.difference(DateTime.now()).inHours < 48) {
      throw BookingException('Cancellation requires at least 48 hours notice.');
    }

    _bookingRepository.update(
      booking.copyWith(status: BookingStatus.cancelRequested),
    );

    _notificationService.notifyUser(
      userId: booking.vendorId,
      title: 'Cancellation requested',
      body: 'Traveler requested cancellation for ${booking.listingTitle}.',
    );
    _notifyAdmins(
      title: 'Cancellation requested',
      body: 'Admin review needed for ${booking.listingTitle}.',
    );
  }

  void adminOverrideCancellation({
    required String bookingId,
    required String reason,
  }) {
    final booking = _bookingRepository.byId(bookingId);
    if (booking == null) {
      throw BookingException('Booking not found.');
    }

    final updated = booking.copyWith(
      status: BookingStatus.cancelled,
      paymentStatus: PaymentStatus.refunded,
    );
    _bookingRepository.update(updated);

    _notificationService.notifyUser(
      userId: booking.travelerId,
      title: 'Booking cancelled by admin',
      body: 'Reason: $reason',
    );
    _notificationService.notifyUser(
      userId: booking.vendorId,
      title: 'Booking cancelled by admin',
      body: '${booking.listingTitle} cancellation approved. Reason: $reason',
    );
  }

  void markCompleted(String bookingId) {
    final booking = _bookingRepository.byId(bookingId);
    if (booking == null) {
      throw BookingException('Booking not found.');
    }
    _bookingRepository.update(
      booking.copyWith(status: BookingStatus.completed),
    );
  }

  List<Booking> travelerBookings(String travelerId) {
    final list = _bookingRepository.byTraveler(travelerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Booking> vendorBookings(String vendorId) {
    final list = _bookingRepository.byVendor(vendorId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Booking> allBookings() {
    final list = _bookingRepository.all().toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<PaymentMock> allPayments() => _paymentRepository.all();

  void _notifyAdmins({required String title, required String body}) {
    final admins = _userRepository.all().where(
      (user) => user.role == UserRole.admin && user.isActive,
    );
    for (final admin in admins) {
      _notificationService.notifyUser(
        userId: admin.id,
        title: title,
        body: body,
      );
    }
  }

  bool _datesOverlap(
    DateTime startA,
    DateTime endA,
    DateTime startB,
    DateTime endB,
  ) {
    return !endA.isBefore(startB) && !startA.isAfter(endB);
  }
}
