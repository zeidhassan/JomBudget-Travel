import '../domain/models.dart';

abstract class UserRepository {
  AppUser? findByEmail(String email);

  AppUser? findById(String id);

  List<AppUser> all();

  AppUser add(AppUser user);

  void update(AppUser user);

  void upsert(AppUser user);

  void remove(String id);
}

class InMemoryUserRepository implements UserRepository {
  InMemoryUserRepository(List<AppUser> seedUsers)
    : _users = List<AppUser>.from(seedUsers);

  final List<AppUser> _users;

  @override
  AppUser? findByEmail(String email) {
    for (final user in _users) {
      if (user.email.toLowerCase() == email.toLowerCase()) {
        return user;
      }
    }
    return null;
  }

  @override
  AppUser? findById(String id) {
    final matches = _users.where((user) => user.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  List<AppUser> all() => List<AppUser>.unmodifiable(_users);

  @override
  AppUser add(AppUser user) {
    upsert(user);
    return user;
  }

  @override
  void update(AppUser user) {
    final index = _users.indexWhere((element) => element.id == user.id);
    if (index == -1) {
      return;
    }
    _users[index] = user;
  }

  @override
  void upsert(AppUser user) {
    final index = _users.indexWhere((element) => element.id == user.id);
    if (index == -1) {
      _users.add(user);
      return;
    }
    _users[index] = user;
  }

  @override
  void remove(String id) {
    _users.removeWhere((user) => user.id == id);
  }
}

abstract class ListingRepository {
  List<Listing> all({bool activeOnly = true});

  List<Listing> forVendor(String vendorId);

  Listing? byId(String id);

  Listing add(Listing listing);

  void update(Listing listing);

  void upsert(Listing listing);

  void remove(String id);
}

class InMemoryListingRepository implements ListingRepository {
  InMemoryListingRepository(List<Listing> seedListings)
    : _listings = List<Listing>.from(seedListings);

  final List<Listing> _listings;

  @override
  List<Listing> all({bool activeOnly = true}) {
    return List<Listing>.unmodifiable(
      _listings.where((listing) => !activeOnly || listing.isActive),
    );
  }

  @override
  List<Listing> forVendor(String vendorId) {
    return List<Listing>.unmodifiable(
      _listings.where((listing) => listing.vendorId == vendorId),
    );
  }

  @override
  Listing? byId(String id) {
    final matches = _listings.where((listing) => listing.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Listing add(Listing listing) {
    upsert(listing);
    return listing;
  }

  @override
  void update(Listing listing) {
    final index = _listings.indexWhere((element) => element.id == listing.id);
    if (index == -1) {
      return;
    }
    _listings[index] = listing;
  }

  @override
  void upsert(Listing listing) {
    final index = _listings.indexWhere((element) => element.id == listing.id);
    if (index == -1) {
      _listings.add(listing);
      return;
    }
    _listings[index] = listing;
  }

  @override
  void remove(String id) {
    _listings.removeWhere((listing) => listing.id == id);
  }
}

abstract class BookingRepository {
  List<Booking> all();

  List<Booking> byTraveler(String travelerId);

  List<Booking> byVendor(String vendorId);

  List<Booking> byListing(String listingId);

  Booking? byId(String id);

  Booking? byIdempotencyKey(String key);

  Booking add(Booking booking);

  void update(Booking booking);

  void upsert(Booking booking);

  void remove(String id);
}

class InMemoryBookingRepository implements BookingRepository {
  InMemoryBookingRepository([List<Booking> seedBookings = const <Booking>[]])
    : _bookings = List<Booking>.from(seedBookings);

  final List<Booking> _bookings;

  @override
  List<Booking> all() => List<Booking>.unmodifiable(_bookings);

  @override
  List<Booking> byTraveler(String travelerId) {
    return List<Booking>.unmodifiable(
      _bookings.where((booking) => booking.travelerId == travelerId),
    );
  }

  @override
  List<Booking> byVendor(String vendorId) {
    return List<Booking>.unmodifiable(
      _bookings.where((booking) => booking.vendorId == vendorId),
    );
  }

  @override
  List<Booking> byListing(String listingId) {
    return List<Booking>.unmodifiable(
      _bookings.where((booking) => booking.listingId == listingId),
    );
  }

  @override
  Booking? byId(String id) {
    final matches = _bookings.where((booking) => booking.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Booking? byIdempotencyKey(String key) {
    final matches = _bookings.where((booking) => booking.idempotencyKey == key);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Booking add(Booking booking) {
    upsert(booking);
    return booking;
  }

  @override
  void update(Booking booking) {
    final index = _bookings.indexWhere((element) => element.id == booking.id);
    if (index == -1) {
      return;
    }
    _bookings[index] = booking;
  }

  @override
  void upsert(Booking booking) {
    final index = _bookings.indexWhere((element) => element.id == booking.id);
    if (index == -1) {
      _bookings.add(booking);
      return;
    }
    _bookings[index] = booking;
  }

  @override
  void remove(String id) {
    _bookings.removeWhere((booking) => booking.id == id);
  }
}

abstract class PaymentRepository {
  List<PaymentMock> all();

  PaymentMock? byId(String id);

  PaymentMock add(PaymentMock payment);

  void upsert(PaymentMock payment);

  void remove(String id);
}

class InMemoryPaymentRepository implements PaymentRepository {
  InMemoryPaymentRepository([
    List<PaymentMock> seedPayments = const <PaymentMock>[],
  ]) : _payments = List<PaymentMock>.from(seedPayments);

  final List<PaymentMock> _payments;

  @override
  List<PaymentMock> all() => List<PaymentMock>.unmodifiable(_payments);

  @override
  PaymentMock? byId(String id) {
    final matches = _payments.where((payment) => payment.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  PaymentMock add(PaymentMock payment) {
    upsert(payment);
    return payment;
  }

  @override
  void upsert(PaymentMock payment) {
    final index = _payments.indexWhere((entry) => entry.id == payment.id);
    if (index == -1) {
      _payments.add(payment);
      return;
    }
    _payments[index] = payment;
  }

  @override
  void remove(String id) {
    _payments.removeWhere((payment) => payment.id == id);
  }
}

abstract class ReviewRepository {
  List<Review> all();

  List<Review> byListing(String listingId);

  List<Review> byVendor(String vendorId, List<Listing> listings);

  Review? byId(String id);

  Review add(Review review);

  void update(Review review);

  void upsert(Review review);

  void remove(String id);
}

class InMemoryReviewRepository implements ReviewRepository {
  InMemoryReviewRepository(List<Review> seedReviews)
    : _reviews = List<Review>.from(seedReviews);

  final List<Review> _reviews;

  @override
  List<Review> all() => List<Review>.unmodifiable(_reviews);

  @override
  List<Review> byListing(String listingId) {
    return List<Review>.unmodifiable(
      _reviews.where((review) => review.listingId == listingId),
    );
  }

  @override
  List<Review> byVendor(String vendorId, List<Listing> listings) {
    final vendorListingIds = listings
        .where((listing) => listing.vendorId == vendorId)
        .map((listing) => listing.id)
        .toSet();
    return List<Review>.unmodifiable(
      _reviews.where((review) => vendorListingIds.contains(review.listingId)),
    );
  }

  @override
  Review? byId(String id) {
    final matches = _reviews.where((entry) => entry.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Review add(Review review) {
    upsert(review);
    return review;
  }

  @override
  void update(Review review) {
    final index = _reviews.indexWhere((element) => element.id == review.id);
    if (index == -1) {
      return;
    }
    _reviews[index] = review;
  }

  @override
  void upsert(Review review) {
    final index = _reviews.indexWhere((element) => element.id == review.id);
    if (index == -1) {
      _reviews.add(review);
      return;
    }
    _reviews[index] = review;
  }

  @override
  void remove(String id) {
    _reviews.removeWhere((review) => review.id == id);
  }
}

abstract class NotificationRepository {
  List<NotificationItem> all();

  List<NotificationItem> byUser(String userId);

  NotificationItem? byId(String id);

  NotificationItem add(NotificationItem notification);

  void update(NotificationItem notification);

  void upsert(NotificationItem notification);

  void remove(String id);
}

class InMemoryNotificationRepository implements NotificationRepository {
  InMemoryNotificationRepository([
    List<NotificationItem> seedNotifications = const <NotificationItem>[],
  ]) : _notifications = List<NotificationItem>.from(seedNotifications);

  final List<NotificationItem> _notifications;

  @override
  List<NotificationItem> all() =>
      List<NotificationItem>.unmodifiable(_notifications);

  @override
  List<NotificationItem> byUser(String userId) {
    final items =
        _notifications.where((entry) => entry.userId == userId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<NotificationItem>.unmodifiable(items);
  }

  @override
  NotificationItem? byId(String id) {
    final matches = _notifications.where((entry) => entry.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  NotificationItem add(NotificationItem notification) {
    upsert(notification);
    return notification;
  }

  @override
  void update(NotificationItem notification) {
    final index = _notifications.indexWhere(
      (element) => element.id == notification.id,
    );
    if (index == -1) {
      return;
    }
    _notifications[index] = notification;
  }

  @override
  void upsert(NotificationItem notification) {
    final index = _notifications.indexWhere(
      (element) => element.id == notification.id,
    );
    if (index == -1) {
      _notifications.add(notification);
      return;
    }
    _notifications[index] = notification;
  }

  @override
  void remove(String id) {
    _notifications.removeWhere((notification) => notification.id == id);
  }
}

abstract class InquiryRepository {
  List<Inquiry> all();

  List<Inquiry> byTraveler(String travelerId);

  List<Inquiry> byVendor(String vendorId);

  List<Inquiry> byListing(String listingId, {bool publicOnly = true});

  Inquiry? byId(String id);

  Inquiry add(Inquiry inquiry);

  void update(Inquiry inquiry);

  void upsert(Inquiry inquiry);

  void remove(String id);
}

class InMemoryInquiryRepository implements InquiryRepository {
  InMemoryInquiryRepository([List<Inquiry> seedInquiries = const <Inquiry>[]])
    : _inquiries = List<Inquiry>.from(seedInquiries);

  final List<Inquiry> _inquiries;

  @override
  List<Inquiry> all() => List<Inquiry>.unmodifiable(_inquiries);

  @override
  List<Inquiry> byTraveler(String travelerId) {
    return List<Inquiry>.unmodifiable(
      _inquiries.where((inquiry) => inquiry.travelerId == travelerId),
    );
  }

  @override
  List<Inquiry> byVendor(String vendorId) {
    return List<Inquiry>.unmodifiable(
      _inquiries.where((inquiry) => inquiry.vendorId == vendorId),
    );
  }

  @override
  List<Inquiry> byListing(String listingId, {bool publicOnly = true}) {
    return List<Inquiry>.unmodifiable(
      _inquiries.where(
        (inquiry) =>
            inquiry.listingId == listingId && (!publicOnly || inquiry.isPublic),
      ),
    );
  }

  @override
  Inquiry? byId(String id) {
    final matches = _inquiries.where((entry) => entry.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Inquiry add(Inquiry inquiry) {
    upsert(inquiry);
    return inquiry;
  }

  @override
  void update(Inquiry inquiry) {
    final index = _inquiries.indexWhere((entry) => entry.id == inquiry.id);
    if (index == -1) {
      return;
    }
    _inquiries[index] = inquiry;
  }

  @override
  void upsert(Inquiry inquiry) {
    final index = _inquiries.indexWhere((entry) => entry.id == inquiry.id);
    if (index == -1) {
      _inquiries.add(inquiry);
      return;
    }
    _inquiries[index] = inquiry;
  }

  @override
  void remove(String id) {
    _inquiries.removeWhere((inquiry) => inquiry.id == id);
  }
}

abstract class DestinationRepository {
  List<Destination> all({bool activeOnly = true});

  Destination? byId(String id);

  Destination add(Destination destination);

  void update(Destination destination);

  void upsert(Destination destination);

  void remove(String id);
}

class InMemoryDestinationRepository implements DestinationRepository {
  InMemoryDestinationRepository(List<Destination> seedDestinations)
    : _destinations = List<Destination>.from(seedDestinations);

  final List<Destination> _destinations;

  @override
  List<Destination> all({bool activeOnly = true}) {
    return List<Destination>.unmodifiable(
      _destinations.where((destination) => !activeOnly || destination.isActive),
    );
  }

  @override
  Destination? byId(String id) {
    final matches = _destinations.where((destination) => destination.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Destination add(Destination destination) {
    upsert(destination);
    return destination;
  }

  @override
  void update(Destination destination) {
    final index = _destinations.indexWhere(
      (entry) => entry.id == destination.id,
    );
    if (index == -1) {
      return;
    }
    _destinations[index] = destination;
  }

  @override
  void upsert(Destination destination) {
    final index = _destinations.indexWhere(
      (entry) => entry.id == destination.id,
    );
    if (index == -1) {
      _destinations.add(destination);
      return;
    }
    _destinations[index] = destination;
  }

  @override
  void remove(String id) {
    _destinations.removeWhere((destination) => destination.id == id);
  }
}

abstract class AvailabilityRepository {
  List<AvailabilityWindow> all();

  List<AvailabilityWindow> forListing(String listingId);

  AvailabilityWindow? byId(String id);

  AvailabilityWindow add(AvailabilityWindow availabilityWindow);

  void upsert(AvailabilityWindow availabilityWindow);

  void remove(String id);
}

class InMemoryAvailabilityRepository implements AvailabilityRepository {
  InMemoryAvailabilityRepository([
    List<AvailabilityWindow> seedWindows = const <AvailabilityWindow>[],
  ]) : _windows = List<AvailabilityWindow>.from(seedWindows);

  final List<AvailabilityWindow> _windows;

  @override
  List<AvailabilityWindow> all() =>
      List<AvailabilityWindow>.unmodifiable(_windows);

  @override
  List<AvailabilityWindow> forListing(String listingId) {
    final windows = _windows.where((window) => window.listingId == listingId);
    return List<AvailabilityWindow>.unmodifiable(windows);
  }

  @override
  AvailabilityWindow? byId(String id) {
    final matches = _windows.where((window) => window.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  AvailabilityWindow add(AvailabilityWindow availabilityWindow) {
    upsert(availabilityWindow);
    return availabilityWindow;
  }

  @override
  void upsert(AvailabilityWindow availabilityWindow) {
    final index = _windows.indexWhere(
      (entry) => entry.id == availabilityWindow.id,
    );
    if (index == -1) {
      _windows.add(availabilityWindow);
      return;
    }
    _windows[index] = availabilityWindow;
  }

  @override
  void remove(String id) {
    _windows.removeWhere((window) => window.id == id);
  }
}

abstract class ItineraryRepository {
  List<ItineraryPlan> byTraveler(String travelerId);

  Map<String, List<ItineraryPlan>> allByTraveler();

  ItineraryPlan add(String travelerId, ItineraryPlan plan);

  void upsert(String travelerId, ItineraryPlan plan);

  void remove(String planId);
}

class InMemoryItineraryRepository implements ItineraryRepository {
  InMemoryItineraryRepository([
    Map<String, List<ItineraryPlan>> seedItineraries =
        const <String, List<ItineraryPlan>>{},
  ]) : _itineraries = <String, List<ItineraryPlan>>{
         for (final entry in seedItineraries.entries)
           entry.key: List<ItineraryPlan>.from(entry.value),
       };

  final Map<String, List<ItineraryPlan>> _itineraries;

  @override
  List<ItineraryPlan> byTraveler(String travelerId) {
    return List<ItineraryPlan>.unmodifiable(
      _itineraries[travelerId] ?? <ItineraryPlan>[],
    );
  }

  @override
  Map<String, List<ItineraryPlan>> allByTraveler() {
    return Map<String, List<ItineraryPlan>>.unmodifiable({
      for (final entry in _itineraries.entries)
        entry.key: List<ItineraryPlan>.unmodifiable(entry.value),
    });
  }

  @override
  ItineraryPlan add(String travelerId, ItineraryPlan plan) {
    upsert(travelerId, plan);
    return plan;
  }

  @override
  void upsert(String travelerId, ItineraryPlan plan) {
    final plans = _itineraries.putIfAbsent(travelerId, () => <ItineraryPlan>[]);
    final index = plans.indexWhere((entry) => entry.id == plan.id);
    if (index == -1) {
      plans.add(plan);
      return;
    }
    plans[index] = plan;
  }

  @override
  void remove(String planId) {
    for (final plans in _itineraries.values) {
      plans.removeWhere((entry) => entry.id == planId);
    }
  }
}
