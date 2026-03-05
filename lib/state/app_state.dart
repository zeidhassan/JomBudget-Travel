import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/in_memory_repositories.dart';
import '../data/seed_data.dart';
import '../domain/models.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/booking_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/itinerary_service.dart';
import '../services/local_persistence_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import '../services/receipt_service.dart';

class AppState extends ChangeNotifier {
  AppState._({
    required UserRepository userRepository,
    required ListingRepository listingRepository,
    required BookingRepository bookingRepository,
    required PaymentRepository paymentRepository,
    required ReviewRepository reviewRepository,
    required InquiryRepository inquiryRepository,
    required NotificationRepository notificationRepository,
    required ItineraryRepository itineraryRepository,
    required DestinationRepository destinationRepository,
    required AvailabilityRepository availabilityRepository,
    required LocalPersistenceService localPersistenceService,
    required bool enableCloudSync,
  }) : _userRepository = userRepository,
       _listingRepository = listingRepository,
       _bookingRepository = bookingRepository,
       _paymentRepository = paymentRepository,
       _reviewRepository = reviewRepository,
       _inquiryRepository = inquiryRepository,
       _notificationRepository = notificationRepository,
       _itineraryRepository = itineraryRepository,
       _destinationRepository = destinationRepository,
       _availabilityRepository = availabilityRepository,
       _localPersistenceService = localPersistenceService,
       _authService = AuthService(userRepository),
       _itineraryService = ItineraryService(),
       _notificationService = NotificationService(notificationRepository),
       _adminService = AdminService(
         userRepository: userRepository,
         listingRepository: listingRepository,
         bookingRepository: bookingRepository,
         paymentRepository: paymentRepository,
         reviewRepository: reviewRepository,
       ),
       _bookingService = BookingService(
         bookingRepository: bookingRepository,
         listingRepository: listingRepository,
         paymentRepository: paymentRepository,
         userRepository: userRepository,
         notificationService: NotificationService(notificationRepository),
       ),
       _cloudSyncService = CloudSyncService(enabled: enableCloudSync),
       _pushNotificationService = PushNotificationService(
         enabled: enableCloudSync,
       ) {
    unawaited(_pushNotificationService.initialize());
  }

  factory AppState.seeded({bool enableCloudSync = false}) {
    return AppState._(
      userRepository: InMemoryUserRepository(SeedData.users()),
      listingRepository: InMemoryListingRepository(SeedData.listings()),
      bookingRepository: InMemoryBookingRepository(SeedData.bookings()),
      paymentRepository: InMemoryPaymentRepository(SeedData.payments()),
      reviewRepository: InMemoryReviewRepository(SeedData.reviews()),
      inquiryRepository: InMemoryInquiryRepository(SeedData.inquiries()),
      notificationRepository: InMemoryNotificationRepository(
        SeedData.notifications(),
      ),
      itineraryRepository: InMemoryItineraryRepository(SeedData.itineraries()),
      destinationRepository: InMemoryDestinationRepository(
        SeedData.destinations(),
      ),
      availabilityRepository: InMemoryAvailabilityRepository(
        SeedData.availabilityWindows(),
      ),
      localPersistenceService: LocalPersistenceService(),
      enableCloudSync: enableCloudSync,
    );
  }

  static Future<AppState> bootstrap({
    bool enableCloudSync = false,
    bool useLocalPersistence = true,
  }) async {
    final persistence = LocalPersistenceService();
    final snapshot = useLocalPersistence ? await persistence.load() : null;

    final users = (snapshot == null || snapshot.users.isEmpty)
        ? SeedData.users()
        : snapshot.users;
    final listings = (snapshot == null || snapshot.listings.isEmpty)
        ? SeedData.listings()
        : snapshot.listings;
    final bookings = snapshot?.bookings ?? SeedData.bookings();
    final payments = snapshot?.payments ?? SeedData.payments();
    final reviews = snapshot?.reviews ?? SeedData.reviews();
    final inquiries = snapshot?.inquiries ?? SeedData.inquiries();
    final notifications = snapshot?.notifications ?? SeedData.notifications();
    final itineraries = snapshot?.itineraries ?? SeedData.itineraries();
    final destinations = (snapshot == null || snapshot.destinations.isEmpty)
        ? SeedData.destinations()
        : snapshot.destinations;
    final windows =
        snapshot?.availabilityWindows ?? SeedData.availabilityWindows();

    final state = AppState._(
      userRepository: InMemoryUserRepository(users),
      listingRepository: InMemoryListingRepository(listings),
      bookingRepository: InMemoryBookingRepository(bookings),
      paymentRepository: InMemoryPaymentRepository(payments),
      reviewRepository: InMemoryReviewRepository(reviews),
      inquiryRepository: InMemoryInquiryRepository(inquiries),
      notificationRepository: InMemoryNotificationRepository(notifications),
      itineraryRepository: InMemoryItineraryRepository(itineraries),
      destinationRepository: InMemoryDestinationRepository(destinations),
      availabilityRepository: InMemoryAvailabilityRepository(windows),
      localPersistenceService: persistence,
      enableCloudSync: enableCloudSync,
    );

    final restoredUserId = snapshot?.currentUserId;
    if (!enableCloudSync && restoredUserId != null) {
      final restoredUser = state._userRepository.findById(restoredUserId);
      if (restoredUser != null && restoredUser.isActive) {
        state._currentUser = restoredUser;
        unawaited(
          state._pushNotificationService.subscribeToRole(restoredUser.role),
        );
      }
    }

    return state;
  }

  final UserRepository _userRepository;
  final ListingRepository _listingRepository;
  final BookingRepository _bookingRepository;
  final PaymentRepository _paymentRepository;
  final ReviewRepository _reviewRepository;
  final InquiryRepository _inquiryRepository;
  final NotificationRepository _notificationRepository;
  final ItineraryRepository _itineraryRepository;
  final DestinationRepository _destinationRepository;
  final AvailabilityRepository _availabilityRepository;
  final LocalPersistenceService _localPersistenceService;

  final AuthService _authService;
  final ItineraryService _itineraryService;
  final BookingService _bookingService;
  final NotificationService _notificationService;
  final AdminService _adminService;
  final CloudSyncService _cloudSyncService;
  final PushNotificationService _pushNotificationService;
  final ReceiptService _receiptService = ReceiptService();
  fb_auth.FirebaseAuth? _firebaseAuth;
  final List<StreamSubscription<dynamic>> _cloudSubscriptions =
      <StreamSubscription<dynamic>>[];
  bool _cloudListenersStarted = false;

  final Uuid _uuid = const Uuid();

  AppUser? _currentUser;
  ItineraryPlan? _lastGeneratedPlan;
  String? _lastError;

  AppUser? get currentUser => _currentUser;

  ItineraryPlan? get lastGeneratedPlan => _lastGeneratedPlan;

  String? get lastError => _lastError;

  bool get isLoggedIn => _currentUser != null;

  bool get cloudSyncEnabled => _cloudSyncService.enabled;

  @override
  void dispose() {
    _stopCloudRealtimeSync();
    super.dispose();
  }

  void clearError() {
    _lastError = null;
    _notifyListenersWithPersistence();
  }

  Future<bool> login({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_cloudSyncService.enabled) {
      return _cloudModeLogin(email: normalizedEmail, password: password);
    }

    try {
      final localUser = _authService.login(normalizedEmail, password);
      _currentUser = localUser;
      _lastError = null;
      unawaited(_pushNotificationService.subscribeToRole(_currentUser!.role));
      _notifyListenersWithPersistence();
      return true;
    } on AuthException catch (e) {
      _lastError = e.message;
      _notifyListenersWithPersistence();
      return false;
    } on fb_auth.FirebaseAuthException catch (e) {
      _lastError = _mapFirebaseAuthError(e);
      _notifyListenersWithPersistence();
      return false;
    } catch (e) {
      _lastError = 'Login failed: $e';
      _notifyListenersWithPersistence();
      return false;
    }
  }

  Future<bool> _cloudModeLogin({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuthClient.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      AppUser? localUser;
      try {
        localUser = _authService.login(email, password);
      } on AuthException {
        localUser = null;
      }

      localUser ??= await _hydrateLocalUserFromCloud(
        authUid: _firebaseAuthClient.currentUser?.uid,
        email: email,
        password: password,
      );

      if (localUser == null) {
        throw AuthException('Unable to load account profile from cloud.');
      }

      await _cloudSyncService.upsertAuthUserProfile(
        authUid: _firebaseAuthClient.currentUser!.uid,
        user: localUser,
      );

      _currentUser = localUser;
      _lastError = null;
      unawaited(_pushNotificationService.subscribeToRole(_currentUser!.role));
      _startCloudRealtimeSync();
      _notifyListenersWithPersistence();
      return true;
    } on AuthException catch (e) {
      _lastError = e.message;
      _notifyListenersWithPersistence();
      return false;
    } on fb_auth.FirebaseAuthException catch (e) {
      _lastError = _mapFirebaseAuthError(e);
      _notifyListenersWithPersistence();
      return false;
    } catch (e) {
      _lastError = 'Login failed: $e';
      _notifyListenersWithPersistence();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final localUser = _authService.register(
        name: name,
        email: normalizedEmail,
        password: password,
        role: role,
      );
      if (_cloudSyncService.enabled) {
        final credential = await _firebaseAuthClient
            .createUserWithEmailAndPassword(
              email: normalizedEmail,
              password: password,
            );
        final authUid = credential.user?.uid;
        if (authUid == null) {
          throw AuthException('Unable to create Firebase account.');
        }
        await _cloudSyncService.upsertAuthUserProfile(
          authUid: authUid,
          user: localUser,
        );
      } else {
        _scheduleSync(_cloudSyncService.upsertUser(localUser));
      }
      _currentUser = localUser;
      _lastError = null;
      unawaited(_pushNotificationService.subscribeToRole(_currentUser!.role));
      _startCloudRealtimeSync();
      _notifyListenersWithPersistence();
      return true;
    } on AuthException catch (e) {
      _lastError = e.message;
      _notifyListenersWithPersistence();
      return false;
    } on fb_auth.FirebaseAuthException catch (e) {
      _lastError = _mapFirebaseAuthError(e);
      _notifyListenersWithPersistence();
      return false;
    } catch (e) {
      _lastError = 'Registration failed: $e';
      _notifyListenersWithPersistence();
      return false;
    }
  }

  void logout() {
    final role = _currentUser?.role;
    if (role != null) {
      unawaited(_pushNotificationService.unsubscribeFromRole(role));
    }
    _stopCloudRealtimeSync();
    if (_cloudSyncService.enabled) {
      unawaited(_firebaseAuthClient.signOut());
    }
    _currentUser = null;
    _lastGeneratedPlan = null;
    _lastError = null;
    _notifyListenersWithPersistence();
  }

  List<Listing> browseListings({
    String query = '',
    String? state,
    ListingType? type,
    bool activeOnly = true,
  }) {
    final lowered = query.trim().toLowerCase();
    return _listingRepository.all(activeOnly: activeOnly).where((listing) {
      final matchesQuery =
          lowered.isEmpty ||
          listing.title.toLowerCase().contains(lowered) ||
          listing.description.toLowerCase().contains(lowered) ||
          listing.tags.any((tag) => tag.toLowerCase().contains(lowered));
      final matchesState =
          state == null || state.isEmpty || listing.state == state;
      final matchesType = type == null || listing.type == type;
      return matchesQuery && matchesState && matchesType;
    }).toList();
  }

  List<Listing> vendorListings() {
    final user = _requireUser();
    return _listingRepository.forVendor(user.id);
  }

  bool addVendorListing({
    required ListingType type,
    required String title,
    required String description,
    required String location,
    required String state,
    required double priceBase,
    required List<String> tags,
    List<String> imageUrls = const <String>[],
  }) {
    final user = _requireUser();
    if (user.role != UserRole.vendor) {
      _lastError = 'Only vendors can add listings.';
      _notifyListenersWithPersistence();
      return false;
    }

    final listing = Listing(
      id: _uuid.v4(),
      vendorId: user.id,
      type: type,
      title: title,
      description: description,
      location: location,
      state: state,
      priceBase: priceBase,
      tags: tags,
      ratingAvg: 4,
      imageUrls: imageUrls,
    );
    _listingRepository.add(listing);
    _scheduleSync(_cloudSyncService.upsertListing(listing));
    _lastError = null;
    _notifyListenersWithPersistence();
    return true;
  }

  bool updateVendorListing(Listing listing) {
    final user = _requireUser();
    if (user.role != UserRole.vendor || listing.vendorId != user.id) {
      _lastError = 'Unauthorized listing update.';
      _notifyListenersWithPersistence();
      return false;
    }

    _listingRepository.update(listing);
    _scheduleSync(_cloudSyncService.upsertListing(listing));
    _lastError = null;
    _notifyListenersWithPersistence();
    return true;
  }

  Future<String?> uploadImageBytes({
    required Uint8List bytes,
    required String filename,
    String folder = 'listings',
  }) async {
    final uploaded = await _cloudSyncService.uploadImage(
      bytes: bytes,
      folder: folder,
      filename: filename,
    );

    if (uploaded != null) {
      return uploaded;
    }

    final encoded = base64Encode(bytes);
    return 'data:image/png;base64,$encoded';
  }

  ItineraryPlan generateItinerary(TripRequest request) {
    final user = _requireUser();
    final listings = _listingRepository.all();
    final plan = _itineraryService.generatePlan(
      request: request,
      listings: listings,
    );
    _itineraryRepository.add(user.id, plan);
    _scheduleSync(
      _cloudSyncService.upsertItinerary(travelerId: user.id, plan: plan),
    );
    _lastGeneratedPlan = plan;
    _notifyListenersWithPersistence();
    return plan;
  }

  List<ItineraryPlan> itineraryHistory() {
    final user = _requireUser();
    return _itineraryRepository.byTraveler(user.id);
  }

  List<ItineraryRecord> allItineraryRecords() {
    final user = _requireUser();
    if (user.role != UserRole.admin) {
      return const <ItineraryRecord>[];
    }
    final records = <ItineraryRecord>[];
    final all = _itineraryRepository.allByTraveler();
    for (final entry in all.entries) {
      for (final plan in entry.value) {
        records.add(ItineraryRecord(travelerId: entry.key, plan: plan));
      }
    }
    records.sort(
      (a, b) => b.plan.request.startDate.compareTo(a.plan.request.startDate),
    );
    return List<ItineraryRecord>.unmodifiable(records);
  }

  Booking? createBooking({
    required String listingId,
    required DateTime startDate,
    required DateTime endDate,
    required int pax,
    required String paymentMethod,
  }) {
    final user = _requireUser();

    final blocked = _availabilityRepository.forListing(listingId).where((
      window,
    ) {
      return _datesOverlap(
        startDate,
        endDate,
        window.startDate,
        window.endDate,
      );
    });

    if (blocked.isNotEmpty) {
      _lastError =
          'Listing is unavailable on selected dates due to vendor blackout window.';
      _notifyListenersWithPersistence();
      return null;
    }

    try {
      final idempotency =
          '${user.id}-$listingId-${startDate.toIso8601String()}-$pax';
      final booking = _bookingService.createBooking(
        travelerId: user.id,
        listingId: listingId,
        startDate: startDate,
        endDate: endDate,
        pax: pax,
        idempotencyKey: idempotency,
      );

      final payment = _bookingService.confirmMockPayment(
        bookingId: booking.id,
        method: paymentMethod,
      );

      final updatedBooking = _bookingRepository.byId(booking.id) ?? booking;
      _scheduleSync(_cloudSyncService.upsertBooking(updatedBooking));
      _scheduleSync(_cloudSyncService.upsertPayment(payment));
      _lastError = null;
      _notifyListenersWithPersistence();
      return updatedBooking;
    } on BookingException catch (e) {
      _lastError = e.message;
      _notifyListenersWithPersistence();
      return null;
    }
  }

  bool requestCancellation(String bookingId) {
    final user = _requireUser();
    try {
      _bookingService.requestCancellation(
        bookingId: bookingId,
        travelerId: user.id,
      );
      final booking = _bookingRepository.byId(bookingId);
      if (booking != null) {
        _scheduleSync(_cloudSyncService.upsertBooking(booking));
      }
      _lastError = null;
      _notifyListenersWithPersistence();
      return true;
    } on BookingException catch (e) {
      _lastError = e.message;
      _notifyListenersWithPersistence();
      return false;
    }
  }

  void vendorDecision({required String bookingId, required bool accept}) {
    final user = _requireUser();
    _bookingService.vendorDecision(
      bookingId: bookingId,
      accept: accept,
      vendorId: user.id,
    );
    final booking = _bookingRepository.byId(bookingId);
    if (booking != null) {
      _scheduleSync(_cloudSyncService.upsertBooking(booking));
    }
    _notifyListenersWithPersistence();
  }

  void adminOverrideCancellation({
    required String bookingId,
    required String reason,
  }) {
    _bookingService.adminOverrideCancellation(
      bookingId: bookingId,
      reason: reason,
    );
    final booking = _bookingRepository.byId(bookingId);
    if (booking != null) {
      _scheduleSync(_cloudSyncService.upsertBooking(booking));
    }
    _notifyListenersWithPersistence();
  }

  void markBookingCompleted(String bookingId) {
    _bookingService.markCompleted(bookingId);
    final booking = _bookingRepository.byId(bookingId);
    if (booking != null) {
      _scheduleSync(_cloudSyncService.upsertBooking(booking));
    }
    _notifyListenersWithPersistence();
  }

  List<Booking> currentUserBookings() {
    final user = _requireUser();
    if (user.role == UserRole.traveler) {
      return _bookingService.travelerBookings(user.id);
    }
    if (user.role == UserRole.vendor) {
      return _bookingService.vendorBookings(user.id);
    }
    return _bookingService.allBookings();
  }

  void submitReview({
    required String bookingId,
    required int rating,
    required String comment,
    List<String> images = const <String>[],
  }) {
    final user = _requireUser();
    final booking = _bookingRepository.byId(bookingId);
    if (booking == null) {
      _lastError = 'Booking does not exist.';
      _notifyListenersWithPersistence();
      return;
    }

    final review = _reviewRepository.add(
      Review(
        id: _uuid.v4(),
        bookingId: bookingId,
        travelerId: user.id,
        listingId: booking.listingId,
        rating: rating,
        comment: comment,
        images: images,
        createdAt: DateTime.now(),
      ),
    );

    _notificationService.notifyUser(
      userId: booking.vendorId,
      title: 'New review posted',
      body: 'A traveler posted a review for ${booking.listingTitle}.',
    );

    _scheduleSync(_cloudSyncService.upsertReview(review));
    _lastError = null;
    _notifyListenersWithPersistence();
  }

  void vendorReplyToReview({required Review review, required String reply}) {
    final updated = review.copyWith(vendorReply: reply);
    _reviewRepository.update(updated);
    _scheduleSync(_cloudSyncService.upsertReview(updated));
    _notifyListenersWithPersistence();
  }

  List<Review> reviewsForListing(String listingId) =>
      _reviewRepository.byListing(listingId);

  List<Review> vendorReviews() {
    final user = _requireUser();
    return _reviewRepository.byVendor(
      user.id,
      _listingRepository.all(activeOnly: false),
    );
  }

  List<Inquiry> inquiriesForListing(String listingId) {
    return _inquiryRepository.byListing(listingId);
  }

  List<Inquiry> travelerInquiries() {
    final user = _requireUser();
    return _inquiryRepository.byTraveler(user.id);
  }

  List<Inquiry> vendorInquiries() {
    final user = _requireUser();
    return _inquiryRepository.byVendor(user.id);
  }

  bool submitInquiry({
    required String listingId,
    required String question,
    bool isPublic = true,
  }) {
    final user = _requireUser();
    if (user.role != UserRole.traveler) {
      _lastError = 'Only travelers can submit inquiries.';
      _notifyListenersWithPersistence();
      return false;
    }
    final listing = _listingRepository.byId(listingId);
    if (listing == null) {
      _lastError = 'Listing not found.';
      _notifyListenersWithPersistence();
      return false;
    }
    if (question.trim().isEmpty) {
      _lastError = 'Question cannot be empty.';
      _notifyListenersWithPersistence();
      return false;
    }

    final inquiry = _inquiryRepository.add(
      Inquiry(
        id: _uuid.v4(),
        listingId: listingId,
        travelerId: user.id,
        vendorId: listing.vendorId,
        question: question.trim(),
        createdAt: DateTime.now(),
        isPublic: isPublic,
      ),
    );

    _notificationService.notifyUser(
      userId: listing.vendorId,
      title: 'New traveler inquiry',
      body: 'A new question was posted for ${listing.title}.',
    );
    _scheduleSync(_cloudSyncService.upsertInquiry(inquiry));
    _lastError = null;
    _notifyListenersWithPersistence();
    return true;
  }

  bool answerInquiry({required String inquiryId, required String answer}) {
    final user = _requireUser();
    if (user.role != UserRole.vendor && user.role != UserRole.admin) {
      _lastError = 'Only vendors or admins can answer inquiries.';
      _notifyListenersWithPersistence();
      return false;
    }
    if (answer.trim().isEmpty) {
      _lastError = 'Answer cannot be empty.';
      _notifyListenersWithPersistence();
      return false;
    }

    final inquiry = _inquiryRepository.all().where(
      (entry) => entry.id == inquiryId,
    );
    if (inquiry.isEmpty) {
      _lastError = 'Inquiry not found.';
      _notifyListenersWithPersistence();
      return false;
    }

    final target = inquiry.first;
    if (user.role == UserRole.vendor && target.vendorId != user.id) {
      _lastError = 'You can only answer inquiries for your own listings.';
      _notifyListenersWithPersistence();
      return false;
    }

    final updated = target.copyWith(
      answer: answer.trim(),
      answeredAt: DateTime.now(),
    );
    _inquiryRepository.update(updated);

    _notificationService.notifyUser(
      userId: updated.travelerId,
      title: 'Inquiry answered',
      body: 'Your question on listing ${updated.listingId} has been answered.',
    );
    _scheduleSync(_cloudSyncService.upsertInquiry(updated));
    _lastError = null;
    _notifyListenersWithPersistence();
    return true;
  }

  List<AvailabilityWindow> availabilityForListing(String listingId) {
    return _availabilityRepository.forListing(listingId);
  }

  bool addAvailabilityWindow({
    required String listingId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) {
    final user = _requireUser();
    final listing = _listingRepository.byId(listingId);
    if (listing == null) {
      _lastError = 'Listing not found.';
      _notifyListenersWithPersistence();
      return false;
    }
    final authorized =
        user.role == UserRole.admin ||
        (user.role == UserRole.vendor && listing.vendorId == user.id);
    if (!authorized) {
      _lastError = 'Only listing owner or admin can manage availability.';
      _notifyListenersWithPersistence();
      return false;
    }
    if (startDate.isAfter(endDate)) {
      _lastError = 'Availability start date cannot be after end date.';
      _notifyListenersWithPersistence();
      return false;
    }
    if (reason.trim().isEmpty) {
      _lastError = 'Please provide a reason for the blackout window.';
      _notifyListenersWithPersistence();
      return false;
    }
    final overlapsExisting = _availabilityRepository
        .forListing(listingId)
        .any(
          (window) => _datesOverlap(
            startDate,
            endDate,
            window.startDate,
            window.endDate,
          ),
        );
    if (overlapsExisting) {
      _lastError = 'Selected dates overlap an existing blackout window.';
      _notifyListenersWithPersistence();
      return false;
    }

    final window = _availabilityRepository.add(
      AvailabilityWindow(
        id: _uuid.v4(),
        listingId: listingId,
        startDate: startDate,
        endDate: endDate,
        reason: reason.trim(),
      ),
    );
    _scheduleSync(_cloudSyncService.upsertAvailability(window));
    _lastError = null;
    _notifyListenersWithPersistence();
    return true;
  }

  bool removeAvailabilityWindow(String id) {
    final user = _requireUser();
    final window = _availabilityRepository.byId(id);
    if (window == null) {
      _lastError = 'Availability window not found.';
      _notifyListenersWithPersistence();
      return false;
    }
    final listing = _listingRepository.byId(window.listingId);
    if (listing == null) {
      _lastError = 'Listing for availability window no longer exists.';
      _notifyListenersWithPersistence();
      return false;
    }
    final authorized =
        user.role == UserRole.admin ||
        (user.role == UserRole.vendor && listing.vendorId == user.id);
    if (!authorized) {
      _lastError = 'Only listing owner or admin can remove this window.';
      _notifyListenersWithPersistence();
      return false;
    }

    _availabilityRepository.remove(id);
    _scheduleSync(_cloudSyncService.deleteAvailability(id));
    _lastError = null;
    _notifyListenersWithPersistence();
    return true;
  }

  List<Destination> allDestinations({bool activeOnly = false}) {
    return _destinationRepository.all(activeOnly: activeOnly);
  }

  bool addDestination({
    required String name,
    required String state,
    required String description,
    double budgetLow = 150,
    double budgetHigh = 450,
    int recommendedDays = 3,
    List<String> highlights = const <String>[],
    bool isActive = true,
  }) {
    final user = _requireUser();
    if (user.role != UserRole.admin) {
      _lastError = 'Only admins can add destinations.';
      _notifyListenersWithPersistence();
      return false;
    }
    if (name.trim().isEmpty || state.trim().isEmpty) {
      _lastError = 'Destination name and state are required.';
      _notifyListenersWithPersistence();
      return false;
    }

    final destination = _destinationRepository.add(
      Destination(
        id: _uuid.v4(),
        name: name.trim(),
        state: state.trim(),
        description: description.trim(),
        budgetLow: budgetLow,
        budgetHigh: budgetHigh,
        recommendedDays: recommendedDays,
        highlights: highlights,
        isActive: isActive,
      ),
    );

    _scheduleSync(_cloudSyncService.upsertDestination(destination));
    _lastError = null;
    _notifyListenersWithPersistence();
    return true;
  }

  bool updateDestination(Destination destination) {
    final user = _requireUser();
    if (user.role != UserRole.admin) {
      _lastError = 'Only admins can update destinations.';
      _notifyListenersWithPersistence();
      return false;
    }
    final existing = _destinationRepository.byId(destination.id);
    if (existing == null) {
      _lastError = 'Destination not found.';
      _notifyListenersWithPersistence();
      return false;
    }
    _destinationRepository.update(destination);
    _scheduleSync(_cloudSyncService.upsertDestination(destination));
    _lastError = null;
    _notifyListenersWithPersistence();
    return true;
  }

  Future<String?> exportReceipt(Booking booking) async {
    try {
      return await _receiptService.saveToDownloads(booking);
    } catch (e) {
      _lastError = 'Unable to export receipt: $e';
      _notifyListenersWithPersistence();
      return null;
    }
  }

  Future<void> shareReceipt(Booking booking) async {
    try {
      await _receiptService.shareReceipt(booking);
    } catch (e) {
      _lastError = 'Unable to share receipt: $e';
      _notifyListenersWithPersistence();
    }
  }

  String receiptPreview(Booking booking) =>
      _receiptService.buildReceiptText(booking);

  List<NotificationItem> notificationsForCurrentUser() {
    final user = _requireUser();
    return _notificationRepository.byUser(user.id);
  }

  void markNotificationRead(NotificationItem notification) {
    _notificationService.markAsRead(notification);
    _scheduleSync(
      _cloudSyncService.upsertNotification(notification.copyWith(isRead: true)),
    );
    _notifyListenersWithPersistence();
  }

  int sendAnnouncement({
    required String title,
    required String body,
    UserRole? targetRole,
  }) {
    final user = _requireUser();
    if (user.role != UserRole.admin) {
      _lastError = 'Only admins can send announcements.';
      _notifyListenersWithPersistence();
      return -1;
    }
    if (title.trim().isEmpty || body.trim().isEmpty) {
      _lastError = 'Announcement title and message are required.';
      _notifyListenersWithPersistence();
      return -1;
    }

    final recipients = _adminService
        .users()
        .where((entry) => entry.isActive)
        .where((entry) => targetRole == null || entry.role == targetRole)
        .toList();

    for (final recipient in recipients) {
      final notification = _notificationRepository.add(
        NotificationItem(
          id: _uuid.v4(),
          userId: recipient.id,
          title: title.trim(),
          body: body.trim(),
          createdAt: DateTime.now(),
        ),
      );
      _scheduleSync(_cloudSyncService.upsertNotification(notification));
    }

    _lastError = null;
    _notifyListenersWithPersistence();
    return recipients.length;
  }

  // Admin APIs
  List<AppUser> allUsers() => _adminService.users();

  List<Listing> allListings() => _adminService.listings();

  List<Review> allReviews() => _adminService.reviews();

  List<Inquiry> allInquiries() => _inquiryRepository.all();

  void setUserActive(String userId, bool isActive) {
    _adminService.setUserActive(userId, isActive);
    final user = _adminService.users().firstWhere(
      (entry) => entry.id == userId,
      orElse: () => const AppUser(
        id: '',
        name: '',
        email: '',
        password: '',
        role: UserRole.traveler,
      ),
    );
    if (user.id.isNotEmpty) {
      _scheduleSync(_cloudSyncService.upsertUser(user));
    }
    _notifyListenersWithPersistence();
  }

  void setListingActive(String listingId, bool isActive) {
    _adminService.setListingActive(listingId, isActive);
    final listing = _listingRepository.byId(listingId);
    if (listing != null) {
      _scheduleSync(_cloudSyncService.upsertListing(listing));
    }
    _notifyListenersWithPersistence();
  }

  bool adminDeleteListing(String listingId) {
    final user = _requireUser();
    if (user.role != UserRole.admin) {
      _lastError = 'Only admins can delete listings.';
      _notifyListenersWithPersistence();
      return false;
    }

    final listing = _listingRepository.byId(listingId);
    if (listing == null) {
      _lastError = 'Listing not found.';
      _notifyListenersWithPersistence();
      return false;
    }

    final openBookings = _bookingRepository
        .byListing(listingId)
        .where(
          (booking) =>
              booking.status == BookingStatus.pending ||
              booking.status == BookingStatus.confirmed ||
              booking.status == BookingStatus.cancelRequested,
        );
    if (openBookings.isNotEmpty) {
      _lastError =
          'Cannot delete listing with active bookings. Pause it instead.';
      _notifyListenersWithPersistence();
      return false;
    }

    final windows = _availabilityRepository.forListing(listingId);
    for (final window in windows) {
      _availabilityRepository.remove(window.id);
      _scheduleSync(_cloudSyncService.deleteAvailability(window.id));
    }

    _listingRepository.remove(listingId);
    _scheduleSync(_cloudSyncService.deleteListing(listingId));
    _lastError = null;
    _notifyListenersWithPersistence();
    return true;
  }

  bool deleteDestination(String destinationId) {
    final user = _requireUser();
    if (user.role != UserRole.admin) {
      _lastError = 'Only admins can delete destinations.';
      _notifyListenersWithPersistence();
      return false;
    }

    final destination = _destinationRepository.byId(destinationId);
    if (destination == null) {
      _lastError = 'Destination not found.';
      _notifyListenersWithPersistence();
      return false;
    }

    _destinationRepository.remove(destinationId);
    _scheduleSync(_cloudSyncService.deleteDestination(destinationId));
    _lastError = null;
    _notifyListenersWithPersistence();
    return true;
  }

  void flagReview(String reviewId, bool flagged) {
    _adminService.flagReview(reviewId, flagged);
    final review = _reviewRepository.all().where(
      (entry) => entry.id == reviewId,
    );
    if (review.isNotEmpty) {
      _scheduleSync(_cloudSyncService.upsertReview(review.first));
    }
    _notifyListenersWithPersistence();
  }

  ReportSnapshot report() => _adminService.generateReportSnapshot();

  List<String> states() => SeedData.malaysiaStates;

  Future<AppUser?> _hydrateLocalUserFromCloud({
    required String? authUid,
    required String email,
    required String password,
  }) async {
    if (authUid == null) {
      return null;
    }

    final profileSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(authUid)
        .get();

    final data = profileSnapshot.data();
    if (data == null) {
      return null;
    }

    final role = _enumByName(
      UserRole.values,
      _asString(data['role'], fallback: ''),
      UserRole.traveler,
    );
    final legacyId = _asString(data['legacyId'], fallback: authUid);
    final nameFallback = email.split('@').first;
    final user = AppUser(
      id: legacyId,
      name: _asString(data['name'], fallback: nameFallback),
      email: _asString(data['email'], fallback: email),
      password: password,
      role: role,
      isActive: _asBool(data['isActive'], fallback: true),
    );
    _userRepository.upsert(user);
    return user;
  }

  void _startCloudRealtimeSync() {
    if (!_cloudSyncService.enabled ||
        _cloudListenersStarted ||
        _currentUser == null) {
      return;
    }

    _stopCloudRealtimeSync();
    _cloudListenersStarted = true;
    final user = _currentUser!;
    final db = FirebaseFirestore.instance;

    _listenQuery(db.collection('listings'), _applyListingCloudChange);
    _listenQuery(db.collection('destinations'), _applyDestinationCloudChange);
    _listenQuery(db.collection('availability'), _applyAvailabilityCloudChange);
    _listenQuery(db.collection('reviews'), _applyReviewCloudChange);

    if (user.role == UserRole.admin) {
      _listenQuery(db.collection('bookings'), _applyBookingCloudChange);
      _listenQuery(db.collection('inquiries'), _applyInquiryCloudChange);
      _listenQuery(db.collection('payments_mock'), _applyPaymentCloudChange);
      _listenQuery(db.collection('itineraries'), _applyItineraryCloudChange);
      _listenQuery(db.collection('users'), _applyUserCloudChange);
    } else if (user.role == UserRole.vendor) {
      _listenQuery(
        db.collection('bookings').where('vendorId', isEqualTo: user.id),
        _applyBookingCloudChange,
      );
      _listenQuery(
        db.collection('inquiries').where('vendorId', isEqualTo: user.id),
        _applyInquiryCloudChange,
      );
      _listenQuery(
        db.collection('inquiries').where('isPublic', isEqualTo: true),
        _applyInquiryCloudChange,
      );
      _listenQuery(
        db.collection('itineraries').where('travelerId', isEqualTo: user.id),
        _applyItineraryCloudChange,
      );
      final authUid = _firebaseAuthClient.currentUser?.uid;
      if (authUid != null) {
        _listenDocument(
          db.collection('users').doc(authUid),
          _applyUserCloudDoc,
        );
      }
    } else {
      _listenQuery(
        db.collection('bookings').where('travelerId', isEqualTo: user.id),
        _applyBookingCloudChange,
      );
      _listenQuery(
        db.collection('inquiries').where('travelerId', isEqualTo: user.id),
        _applyInquiryCloudChange,
      );
      _listenQuery(
        db.collection('inquiries').where('isPublic', isEqualTo: true),
        _applyInquiryCloudChange,
      );
      _listenQuery(
        db.collection('itineraries').where('travelerId', isEqualTo: user.id),
        _applyItineraryCloudChange,
      );
      final authUid = _firebaseAuthClient.currentUser?.uid;
      if (authUid != null) {
        _listenDocument(
          db.collection('users').doc(authUid),
          _applyUserCloudDoc,
        );
      }
    }

    _listenQuery(
      db.collection('notifications').where('userId', isEqualTo: user.id),
      _applyNotificationCloudChange,
    );
  }

  void _stopCloudRealtimeSync() {
    for (final subscription in _cloudSubscriptions) {
      unawaited(subscription.cancel());
    }
    _cloudSubscriptions.clear();
    _cloudListenersStarted = false;
  }

  void _listenQuery(
    Query<Map<String, dynamic>> query,
    void Function(DocumentChange<Map<String, dynamic>> change) onChange,
  ) {
    final subscription = query.snapshots().listen((snapshot) {
      var changed = false;
      for (final change in snapshot.docChanges) {
        onChange(change);
        changed = true;
      }
      if (changed) {
        _notifyListenersWithPersistence();
      }
    }, onError: _onCloudListenerError);
    _cloudSubscriptions.add(subscription);
  }

  void _listenDocument(
    DocumentReference<Map<String, dynamic>> reference,
    void Function(DocumentSnapshot<Map<String, dynamic>> snapshot) onChange,
  ) {
    final subscription = reference.snapshots().listen((snapshot) {
      onChange(snapshot);
      _notifyListenersWithPersistence();
    }, onError: _onCloudListenerError);
    _cloudSubscriptions.add(subscription);
  }

  void _onCloudListenerError(Object error) {
    if (!_cloudSyncService.enabled) {
      return;
    }
    _lastError = 'Cloud sync warning: $error';
    _notifyListenersWithPersistence();
  }

  void _applyListingCloudChange(DocumentChange<Map<String, dynamic>> change) {
    final id = change.doc.id;
    if (change.type == DocumentChangeType.removed) {
      _listingRepository.remove(id);
      return;
    }

    final data = change.doc.data();
    if (data == null) {
      return;
    }
    final listing = _listingFromCloudMap(id, data);
    _listingRepository.upsert(listing);
  }

  void _applyDestinationCloudChange(
    DocumentChange<Map<String, dynamic>> change,
  ) {
    final id = change.doc.id;
    if (change.type == DocumentChangeType.removed) {
      _destinationRepository.remove(id);
      return;
    }

    final data = change.doc.data();
    if (data == null) {
      return;
    }
    final destination = _destinationFromCloudMap(id, data);
    _destinationRepository.upsert(destination);
  }

  void _applyAvailabilityCloudChange(
    DocumentChange<Map<String, dynamic>> change,
  ) {
    final id = change.doc.id;
    if (change.type == DocumentChangeType.removed) {
      _availabilityRepository.remove(id);
      return;
    }

    final data = change.doc.data();
    if (data == null) {
      return;
    }
    final window = _availabilityFromCloudMap(id, data);
    _availabilityRepository.upsert(window);
  }

  void _applyReviewCloudChange(DocumentChange<Map<String, dynamic>> change) {
    final id = change.doc.id;
    if (change.type == DocumentChangeType.removed) {
      _reviewRepository.remove(id);
      return;
    }

    final data = change.doc.data();
    if (data == null) {
      return;
    }
    final review = _reviewFromCloudMap(id, data);
    _reviewRepository.upsert(review);
  }

  void _applyInquiryCloudChange(DocumentChange<Map<String, dynamic>> change) {
    final id = change.doc.id;
    if (change.type == DocumentChangeType.removed) {
      _inquiryRepository.remove(id);
      return;
    }

    final data = change.doc.data();
    if (data == null) {
      return;
    }
    final inquiry = _inquiryFromCloudMap(id, data);
    _inquiryRepository.upsert(inquiry);
  }

  void _applyBookingCloudChange(DocumentChange<Map<String, dynamic>> change) {
    final id = change.doc.id;
    if (change.type == DocumentChangeType.removed) {
      _bookingRepository.remove(id);
      return;
    }

    final data = change.doc.data();
    if (data == null) {
      return;
    }
    final booking = _bookingFromCloudMap(id, data);
    _bookingRepository.upsert(booking);
  }

  void _applyPaymentCloudChange(DocumentChange<Map<String, dynamic>> change) {
    final id = change.doc.id;
    if (change.type == DocumentChangeType.removed) {
      _paymentRepository.remove(id);
      return;
    }

    final data = change.doc.data();
    if (data == null) {
      return;
    }
    final payment = _paymentFromCloudMap(id, data);
    _paymentRepository.upsert(payment);
  }

  void _applyNotificationCloudChange(
    DocumentChange<Map<String, dynamic>> change,
  ) {
    final id = change.doc.id;
    if (change.type == DocumentChangeType.removed) {
      _notificationRepository.remove(id);
      return;
    }

    final data = change.doc.data();
    if (data == null) {
      return;
    }
    final notification = _notificationFromCloudMap(id, data);
    _notificationRepository.upsert(notification);
  }

  void _applyItineraryCloudChange(DocumentChange<Map<String, dynamic>> change) {
    final id = change.doc.id;
    if (change.type == DocumentChangeType.removed) {
      _itineraryRepository.remove(id);
      return;
    }

    final data = change.doc.data();
    if (data == null) {
      return;
    }
    final plan = _itineraryFromCloudMap(id, data);
    final travelerId = _asString(data['travelerId'], fallback: '');
    if (travelerId.isEmpty) {
      return;
    }
    _itineraryRepository.upsert(travelerId, plan);
  }

  void _applyUserCloudChange(DocumentChange<Map<String, dynamic>> change) {
    final id = change.doc.id;
    if (change.type == DocumentChangeType.removed) {
      return;
    }

    final data = change.doc.data();
    if (data == null) {
      return;
    }
    _upsertUserFromCloudDoc(id: id, data: data);
  }

  void _applyUserCloudDoc(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists) {
      return;
    }
    final data = snapshot.data();
    if (data == null) {
      return;
    }
    _upsertUserFromCloudDoc(id: snapshot.id, data: data);
  }

  void _upsertUserFromCloudDoc({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final legacyId = _asString(data['legacyId'], fallback: id);
    final email = _asString(data['email'], fallback: '');
    final existingById = _userRepository.findById(legacyId);
    final existingByEmail = email.isEmpty
        ? null
        : _userRepository.findByEmail(email);
    final role = _enumByName(
      UserRole.values,
      _asString(data['role'], fallback: ''),
      UserRole.traveler,
    );
    final user = AppUser(
      id: legacyId,
      name: _asString(data['name'], fallback: existingById?.name ?? ''),
      email: email.isEmpty ? (existingById?.email ?? '') : email,
      password:
          existingById?.password ??
          existingByEmail?.password ??
          'firebase-auth',
      role: role,
      isActive: _asBool(data['isActive'], fallback: true),
    );
    _userRepository.upsert(user);
    if (_currentUser?.id == user.id) {
      _currentUser = user;
    }
  }

  Listing _listingFromCloudMap(String id, Map<String, dynamic> data) {
    return Listing(
      id: id,
      vendorId: _asString(data['vendorId'], fallback: ''),
      type: _enumByName(
        ListingType.values,
        _asString(data['type'], fallback: ''),
        ListingType.activity,
      ),
      title: _asString(data['title'], fallback: ''),
      description: _asString(data['description'], fallback: ''),
      location: _asString(data['location'], fallback: ''),
      state: _asString(data['state'], fallback: ''),
      priceBase: _asDouble(data['priceBase']),
      tags: _asStringList(data['tags']),
      ratingAvg: _asDouble(data['ratingAvg'], fallback: 4),
      imageUrls: _asStringList(data['imageUrls']),
      isActive: _asBool(data['isActive'], fallback: true),
    );
  }

  Destination _destinationFromCloudMap(String id, Map<String, dynamic> data) {
    return Destination(
      id: id,
      name: _asString(data['name'], fallback: ''),
      state: _asString(data['state'], fallback: ''),
      description: _asString(data['description'], fallback: ''),
      budgetLow: _asDouble(data['budgetLow'], fallback: 150),
      budgetHigh: _asDouble(data['budgetHigh'], fallback: 450),
      recommendedDays: _asInt(data['recommendedDays'], fallback: 3),
      highlights: _asStringList(data['highlights']),
      isActive: _asBool(data['isActive'], fallback: true),
    );
  }

  AvailabilityWindow _availabilityFromCloudMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return AvailabilityWindow(
      id: id,
      listingId: _asString(data['listingId'], fallback: ''),
      startDate: _asDateTime(data['startDate']),
      endDate: _asDateTime(data['endDate']),
      reason: _asString(data['reason'], fallback: 'Unavailable'),
    );
  }

  Review _reviewFromCloudMap(String id, Map<String, dynamic> data) {
    return Review(
      id: id,
      bookingId: _asString(data['bookingId'], fallback: ''),
      travelerId: _asString(data['travelerId'], fallback: ''),
      listingId: _asString(data['listingId'], fallback: ''),
      rating: _asInt(data['rating'], fallback: 4),
      comment: _asString(data['comment'], fallback: ''),
      images: _asStringList(data['images']),
      createdAt: _asDateTime(data['createdAt']),
      isFlagged: _asBool(data['isFlagged']),
      vendorReply: _asStringNullable(data['vendorReply']),
    );
  }

  Inquiry _inquiryFromCloudMap(String id, Map<String, dynamic> data) {
    return Inquiry(
      id: id,
      listingId: _asString(data['listingId'], fallback: ''),
      travelerId: _asString(data['travelerId'], fallback: ''),
      vendorId: _asString(data['vendorId'], fallback: ''),
      question: _asString(data['question'], fallback: ''),
      createdAt: _asDateTime(data['createdAt']),
      answer: _asStringNullable(data['answer']),
      answeredAt: _asDateTimeNullable(data['answeredAt']),
      isPublic: _asBool(data['isPublic'], fallback: true),
    );
  }

  Booking _bookingFromCloudMap(String id, Map<String, dynamic> data) {
    return Booking(
      id: id,
      travelerId: _asString(data['travelerId'], fallback: ''),
      listingId: _asString(data['listingId'], fallback: ''),
      listingTitle: _asString(data['listingTitle'], fallback: ''),
      vendorId: _asString(data['vendorId'], fallback: ''),
      startDate: _asDateTime(data['startDate']),
      endDate: _asDateTime(data['endDate']),
      pax: _asInt(data['pax'], fallback: 1),
      status: _enumByName(
        BookingStatus.values,
        _asString(data['status'], fallback: ''),
        BookingStatus.pending,
      ),
      paymentStatus: _enumByName(
        PaymentStatus.values,
        _asString(data['paymentStatus'], fallback: ''),
        PaymentStatus.unpaid,
      ),
      totalAmount: _asDouble(data['totalAmount']),
      idempotencyKey: _asString(data['idempotencyKey'], fallback: ''),
      createdAt: _asDateTime(data['createdAt']),
    );
  }

  PaymentMock _paymentFromCloudMap(String id, Map<String, dynamic> data) {
    return PaymentMock(
      id: id,
      bookingId: _asString(data['bookingId'], fallback: ''),
      amount: _asDouble(data['amount']),
      method: _asString(data['method'], fallback: 'Card'),
      createdAt: _asDateTime(data['createdAt']),
      status: _enumByName(
        PaymentStatus.values,
        _asString(data['status'], fallback: ''),
        PaymentStatus.paid,
      ),
    );
  }

  NotificationItem _notificationFromCloudMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return NotificationItem(
      id: id,
      userId: _asString(data['userId'], fallback: ''),
      title: _asString(data['title'], fallback: ''),
      body: _asString(data['body'], fallback: ''),
      createdAt: _asDateTime(data['createdAt']),
      isRead: _asBool(data['isRead']),
    );
  }

  ItineraryPlan _itineraryFromCloudMap(String id, Map<String, dynamic> data) {
    final requestMap = _asMap(data['request']);
    final costMap = _asMap(data['cost']);
    final itemsRaw = data['items'] is List ? data['items'] as List : const [];
    final cheaperRaw = data['cheaperAlternatives'] is List
        ? data['cheaperAlternatives'] as List
        : const [];
    final upgradeRaw = data['upgradeAlternatives'] is List
        ? data['upgradeAlternatives'] as List
        : const [];

    final request = TripRequest(
      startCity: _asString(requestMap['startCity'], fallback: ''),
      destinationState: _asString(requestMap['destinationState'], fallback: ''),
      startDate: _asDateTime(requestMap['startDate']),
      endDate: _asDateTime(requestMap['endDate']),
      budget: _asDouble(requestMap['budget']),
      interests: _asStringList(requestMap['interests']),
      pace: _enumByName(
        Pace.values,
        _asString(requestMap['pace'], fallback: ''),
        Pace.balanced,
      ),
      transportMode: _enumByName(
        TransportMode.values,
        _asString(requestMap['transportMode'], fallback: ''),
        TransportMode.mixed,
      ),
      stayType: _enumByName(
        StayType.values,
        _asString(requestMap['stayType'], fallback: ''),
        StayType.hostel,
      ),
    );

    final items = itemsRaw
        .whereType<Map>()
        .map(
          (entry) => ItineraryItem(
            dayIndex: _asInt(entry['dayIndex'], fallback: 1),
            timeSlot: _enumByName(
              TimeSlot.values,
              _asString(entry['timeSlot'], fallback: ''),
              TimeSlot.morning,
            ),
            listingId: _asString(entry['listingId'], fallback: ''),
            listingTitle: _asString(entry['listingTitle'], fallback: ''),
            estimatedCost: _asDouble(entry['estimatedCost']),
            category: _asString(entry['category'], fallback: ''),
            notes: _asString(entry['notes'], fallback: ''),
            score: _asDouble(entry['score']),
          ),
        )
        .toList();

    final cheaper = cheaperRaw
        .whereType<Map>()
        .map(
          (entry) => Listing(
            id: _asString(entry['id'], fallback: _uuid.v4()),
            vendorId: '',
            type: ListingType.activity,
            title: _asString(entry['title'], fallback: 'Alternative'),
            description: '',
            location: '',
            state: request.destinationState,
            priceBase: _asDouble(entry['priceBase']),
            tags: const <String>[],
            ratingAvg: _asDouble(entry['ratingAvg'], fallback: 4),
          ),
        )
        .toList();

    final upgrades = upgradeRaw
        .whereType<Map>()
        .map(
          (entry) => Listing(
            id: _asString(entry['id'], fallback: _uuid.v4()),
            vendorId: '',
            type: ListingType.activity,
            title: _asString(entry['title'], fallback: 'Alternative'),
            description: '',
            location: '',
            state: request.destinationState,
            priceBase: _asDouble(entry['priceBase']),
            tags: const <String>[],
            ratingAvg: _asDouble(entry['ratingAvg'], fallback: 4),
          ),
        )
        .toList();

    return ItineraryPlan(
      id: id,
      request: request,
      items: items,
      cost: CostBreakdown(
        transport: _asDouble(costMap['transport']),
        accommodation: _asDouble(costMap['accommodation']),
        activities: _asDouble(costMap['activities']),
        foodEstimate: _asDouble(costMap['foodEstimate']),
        fees: _asDouble(costMap['fees']),
      ),
      remainingBudget: _asDouble(data['remainingBudget']),
      cheaperAlternatives: cheaper,
      upgradeAlternatives: upgrades,
      message: _asString(data['message'], fallback: 'Synced from cloud'),
    );
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  String _asString(dynamic raw, {required String fallback}) {
    if (raw is String) {
      return raw;
    }
    return fallback;
  }

  String? _asStringNullable(dynamic raw) {
    if (raw is String) {
      return raw;
    }
    return null;
  }

  List<String> _asStringList(dynamic raw) {
    if (raw is! List) {
      return const <String>[];
    }
    return raw.whereType<String>().toList();
  }

  double _asDouble(dynamic raw, {double fallback = 0}) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw) ?? fallback;
    }
    return fallback;
  }

  int _asInt(dynamic raw, {int fallback = 0}) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw) ?? fallback;
    }
    return fallback;
  }

  bool _asBool(dynamic raw, {bool fallback = false}) {
    if (raw is bool) {
      return raw;
    }
    return fallback;
  }

  DateTime _asDateTime(dynamic raw) {
    final parsed = _asDateTimeNullable(raw);
    if (parsed != null) {
      return parsed;
    }
    return DateTime.now();
  }

  DateTime? _asDateTimeNullable(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    return null;
  }

  T _enumByName<T extends Enum>(List<T> values, String name, T fallback) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }

  String _mapFirebaseAuthError(fb_auth.FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Invalid email format.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email is already registered in Firebase.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return error.message ?? 'Firebase authentication error.';
    }
  }

  fb_auth.FirebaseAuth get _firebaseAuthClient {
    _firebaseAuth ??= fb_auth.FirebaseAuth.instance;
    return _firebaseAuth!;
  }

  AppUser _requireUser() {
    if (_currentUser == null) {
      throw StateError('No signed in user.');
    }
    return _currentUser!;
  }

  bool _datesOverlap(
    DateTime startA,
    DateTime endA,
    DateTime startB,
    DateTime endB,
  ) {
    return !endA.isBefore(startB) && !startA.isAfter(endB);
  }

  void _notifyListenersWithPersistence() {
    _scheduleSync(_persistLocalSnapshot());
    notifyListeners();
  }

  Future<void> _persistLocalSnapshot() async {
    final listings = _listingRepository.all(activeOnly: false);
    final windowsById = <String, AvailabilityWindow>{};
    for (final listing in listings) {
      for (final window in _availabilityRepository.forListing(listing.id)) {
        windowsById[window.id] = window;
      }
    }

    final notificationsById = <String, NotificationItem>{};
    for (final user in _userRepository.all()) {
      final items = _notificationRepository.byUser(user.id);
      for (final item in items) {
        notificationsById[item.id] = item;
      }
    }

    final snapshot = AppSnapshot(
      users: _userRepository.all(),
      listings: listings,
      bookings: _bookingRepository.all(),
      payments: _paymentRepository.all(),
      reviews: _reviewRepository.all(),
      inquiries: _inquiryRepository.all(),
      notifications: notificationsById.values.toList(),
      itineraries: _itineraryRepository.allByTraveler(),
      destinations: _destinationRepository.all(activeOnly: false),
      availabilityWindows: windowsById.values.toList(),
      currentUserId: _currentUser?.id,
    );
    await _localPersistenceService.save(snapshot);
  }

  void _scheduleSync(Future<void> future) {
    unawaited(future);
  }
}
