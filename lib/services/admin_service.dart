import 'package:uuid/uuid.dart';

import '../data/in_memory_repositories.dart';
import '../domain/models.dart';

class AdminService {
  AdminService({
    required UserRepository userRepository,
    required ListingRepository listingRepository,
    required BookingRepository bookingRepository,
    required PaymentRepository paymentRepository,
    required ReviewRepository reviewRepository,
  }) : _userRepository = userRepository,
       _listingRepository = listingRepository,
       _bookingRepository = bookingRepository,
       _paymentRepository = paymentRepository,
       _reviewRepository = reviewRepository;

  final UserRepository _userRepository;
  final ListingRepository _listingRepository;
  final BookingRepository _bookingRepository;
  final PaymentRepository _paymentRepository;
  final ReviewRepository _reviewRepository;
  final Uuid _uuid = const Uuid();

  List<AppUser> users() => _userRepository.all();

  List<Listing> listings({bool activeOnly = false}) =>
      _listingRepository.all(activeOnly: activeOnly);

  List<Review> reviews() => _reviewRepository.all();

  void setUserActive(String userId, bool isActive) {
    final user = _userRepository.findById(userId);
    if (user == null) {
      return;
    }
    _userRepository.update(user.copyWith(isActive: isActive));
  }

  void setListingActive(String listingId, bool isActive) {
    final listing = _listingRepository.byId(listingId);
    if (listing == null) {
      return;
    }
    _listingRepository.update(listing.copyWith(isActive: isActive));
  }

  void flagReview(String reviewId, bool flagged) {
    final review = _reviewRepository.all().where(
      (entry) => entry.id == reviewId,
    );
    if (review.isEmpty) {
      return;
    }
    _reviewRepository.update(review.first.copyWith(isFlagged: flagged));
  }

  ReportSnapshot generateReportSnapshot() {
    final bookings = _bookingRepository.all();
    final payments = _paymentRepository.all();

    final pendingCount = bookings
        .where((booking) => booking.status == BookingStatus.pending)
        .length;

    final listingCounts = <String, int>{};
    for (final booking in bookings) {
      listingCounts.update(
        booking.listingTitle,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final sortedTitles = listingCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final cancellationReasons = <String, int>{
      'Traveler changed plans': bookings
          .where((booking) => booking.status == BookingStatus.cancelRequested)
          .length,
      'Admin overrides': bookings
          .where((booking) => booking.status == BookingStatus.cancelled)
          .length,
      'Vendor rejection': bookings
          .where((booking) => booking.status == BookingStatus.rejected)
          .length,
    };

    final revenue = payments
        .where((payment) => payment.status == PaymentStatus.paid)
        .fold<double>(0, (sum, item) => sum + item.amount);

    return ReportSnapshot(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      totalBookings: bookings.length,
      pendingBookings: pendingCount,
      totalRevenue: revenue,
      popularListingTitles: sortedTitles
          .take(3)
          .map((entry) => entry.key)
          .toList(),
      cancellationReasons: cancellationReasons,
    );
  }
}
