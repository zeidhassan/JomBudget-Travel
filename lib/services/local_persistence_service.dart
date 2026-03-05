import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

class AppSnapshot {
  const AppSnapshot({
    required this.users,
    required this.listings,
    required this.bookings,
    required this.payments,
    required this.reviews,
    required this.inquiries,
    required this.notifications,
    required this.itineraries,
    required this.destinations,
    required this.availabilityWindows,
    this.currentUserId,
  });

  final List<AppUser> users;
  final List<Listing> listings;
  final List<Booking> bookings;
  final List<PaymentMock> payments;
  final List<Review> reviews;
  final List<Inquiry> inquiries;
  final List<NotificationItem> notifications;
  final Map<String, List<ItineraryPlan>> itineraries;
  final List<Destination> destinations;
  final List<AvailabilityWindow> availabilityWindows;
  final String? currentUserId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'currentUserId': currentUserId,
      'users': users.map(_userToJson).toList(),
      'listings': listings.map(_listingToJson).toList(),
      'bookings': bookings.map(_bookingToJson).toList(),
      'payments': payments.map(_paymentToJson).toList(),
      'reviews': reviews.map(_reviewToJson).toList(),
      'inquiries': inquiries.map(_inquiryToJson).toList(),
      'notifications': notifications.map(_notificationToJson).toList(),
      'itineraries': itineraries.map(
        (travelerId, plans) =>
            MapEntry(travelerId, plans.map(_itineraryPlanToJson).toList()),
      ),
      'destinations': destinations.map(_destinationToJson).toList(),
      'availability': availabilityWindows.map(_availabilityToJson).toList(),
    };
  }

  static AppSnapshot? fromJson(Map<String, dynamic> json) {
    try {
      return AppSnapshot(
        users: _readList(json['users'], _userFromJson),
        listings: _readList(json['listings'], _listingFromJson),
        bookings: _readList(json['bookings'], _bookingFromJson),
        payments: _readList(json['payments'], _paymentFromJson),
        reviews: _readList(json['reviews'], _reviewFromJson),
        inquiries: _readList(json['inquiries'], _inquiryFromJson),
        notifications: _readList(json['notifications'], _notificationFromJson),
        itineraries: _itineraryMapFromJson(json['itineraries']),
        destinations: _readList(json['destinations'], _destinationFromJson),
        availabilityWindows: _readList(
          json['availability'],
          _availabilityFromJson,
        ),
        currentUserId: _readString(json['currentUserId']),
      );
    } catch (_) {
      return null;
    }
  }

  static List<T> _readList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (raw is! List<dynamic>) {
      return <T>[];
    }
    final parsed = <T>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        parsed.add(parser(item));
      } else if (item is Map) {
        parsed.add(parser(Map<String, dynamic>.from(item)));
      }
    }
    return parsed;
  }

  static Map<String, List<ItineraryPlan>> _itineraryMapFromJson(dynamic raw) {
    if (raw is! Map) {
      return <String, List<ItineraryPlan>>{};
    }
    final parsed = <String, List<ItineraryPlan>>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String || entry.value is! List<dynamic>) {
        continue;
      }
      final plans = <ItineraryPlan>[];
      for (final plan in entry.value as List<dynamic>) {
        if (plan is Map<String, dynamic>) {
          plans.add(_itineraryPlanFromJson(plan));
        } else if (plan is Map) {
          plans.add(_itineraryPlanFromJson(Map<String, dynamic>.from(plan)));
        }
      }
      parsed[key] = plans;
    }
    return parsed;
  }

  static Map<String, dynamic> _userToJson(AppUser user) {
    return <String, dynamic>{
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'password': user.password,
      'role': user.role.name,
      'isActive': user.isActive,
    };
  }

  static AppUser _userFromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _readString(json['id']) ?? '',
      name: _readString(json['name']) ?? '',
      email: _readString(json['email']) ?? '',
      password: _readString(json['password']) ?? '',
      role: _readEnum(
        UserRole.values,
        _readString(json['role']),
        UserRole.traveler,
      ),
      isActive: _readBool(json['isActive'], fallback: true),
    );
  }

  static Map<String, dynamic> _listingToJson(Listing listing) {
    return <String, dynamic>{
      'id': listing.id,
      'vendorId': listing.vendorId,
      'type': listing.type.name,
      'title': listing.title,
      'description': listing.description,
      'location': listing.location,
      'state': listing.state,
      'priceBase': listing.priceBase,
      'tags': listing.tags,
      'ratingAvg': listing.ratingAvg,
      'imageUrls': listing.imageUrls,
      'isActive': listing.isActive,
    };
  }

  static Listing _listingFromJson(Map<String, dynamic> json) {
    return Listing(
      id: _readString(json['id']) ?? '',
      vendorId: _readString(json['vendorId']) ?? '',
      type: _readEnum(
        ListingType.values,
        _readString(json['type']),
        ListingType.activity,
      ),
      title: _readString(json['title']) ?? '',
      description: _readString(json['description']) ?? '',
      location: _readString(json['location']) ?? '',
      state: _readString(json['state']) ?? '',
      priceBase: _readDouble(json['priceBase']),
      tags: _readStringList(json['tags']),
      ratingAvg: _readDouble(json['ratingAvg'], fallback: 4),
      imageUrls: _readStringList(json['imageUrls']),
      isActive: _readBool(json['isActive'], fallback: true),
    );
  }

  static Map<String, dynamic> _bookingToJson(Booking booking) {
    return <String, dynamic>{
      'id': booking.id,
      'travelerId': booking.travelerId,
      'listingId': booking.listingId,
      'listingTitle': booking.listingTitle,
      'vendorId': booking.vendorId,
      'startDate': booking.startDate.toIso8601String(),
      'endDate': booking.endDate.toIso8601String(),
      'pax': booking.pax,
      'status': booking.status.name,
      'paymentStatus': booking.paymentStatus.name,
      'totalAmount': booking.totalAmount,
      'idempotencyKey': booking.idempotencyKey,
      'createdAt': booking.createdAt.toIso8601String(),
    };
  }

  static Booking _bookingFromJson(Map<String, dynamic> json) {
    return Booking(
      id: _readString(json['id']) ?? '',
      travelerId: _readString(json['travelerId']) ?? '',
      listingId: _readString(json['listingId']) ?? '',
      listingTitle: _readString(json['listingTitle']) ?? '',
      vendorId: _readString(json['vendorId']) ?? '',
      startDate: _readDate(json['startDate']),
      endDate: _readDate(json['endDate']),
      pax: _readInt(json['pax'], fallback: 1),
      status: _readEnum(
        BookingStatus.values,
        _readString(json['status']),
        BookingStatus.pending,
      ),
      paymentStatus: _readEnum(
        PaymentStatus.values,
        _readString(json['paymentStatus']),
        PaymentStatus.unpaid,
      ),
      totalAmount: _readDouble(json['totalAmount']),
      idempotencyKey: _readString(json['idempotencyKey']) ?? '',
      createdAt: _readDate(json['createdAt']),
    );
  }

  static Map<String, dynamic> _paymentToJson(PaymentMock payment) {
    return <String, dynamic>{
      'id': payment.id,
      'bookingId': payment.bookingId,
      'amount': payment.amount,
      'method': payment.method,
      'createdAt': payment.createdAt.toIso8601String(),
      'status': payment.status.name,
    };
  }

  static PaymentMock _paymentFromJson(Map<String, dynamic> json) {
    return PaymentMock(
      id: _readString(json['id']) ?? '',
      bookingId: _readString(json['bookingId']) ?? '',
      amount: _readDouble(json['amount']),
      method: _readString(json['method']) ?? '',
      createdAt: _readDate(json['createdAt']),
      status: _readEnum(
        PaymentStatus.values,
        _readString(json['status']),
        PaymentStatus.paid,
      ),
    );
  }

  static Map<String, dynamic> _reviewToJson(Review review) {
    return <String, dynamic>{
      'id': review.id,
      'bookingId': review.bookingId,
      'travelerId': review.travelerId,
      'listingId': review.listingId,
      'rating': review.rating,
      'comment': review.comment,
      'images': review.images,
      'createdAt': review.createdAt.toIso8601String(),
      'isFlagged': review.isFlagged,
      'vendorReply': review.vendorReply,
    };
  }

  static Review _reviewFromJson(Map<String, dynamic> json) {
    return Review(
      id: _readString(json['id']) ?? '',
      bookingId: _readString(json['bookingId']) ?? '',
      travelerId: _readString(json['travelerId']) ?? '',
      listingId: _readString(json['listingId']) ?? '',
      rating: _readInt(json['rating'], fallback: 4),
      comment: _readString(json['comment']) ?? '',
      images: _readStringList(json['images']),
      createdAt: _readDate(json['createdAt']),
      isFlagged: _readBool(json['isFlagged']),
      vendorReply: _readString(json['vendorReply']),
    );
  }

  static Map<String, dynamic> _inquiryToJson(Inquiry inquiry) {
    return <String, dynamic>{
      'id': inquiry.id,
      'listingId': inquiry.listingId,
      'travelerId': inquiry.travelerId,
      'vendorId': inquiry.vendorId,
      'question': inquiry.question,
      'createdAt': inquiry.createdAt.toIso8601String(),
      'answer': inquiry.answer,
      'answeredAt': inquiry.answeredAt?.toIso8601String(),
      'isPublic': inquiry.isPublic,
    };
  }

  static Inquiry _inquiryFromJson(Map<String, dynamic> json) {
    return Inquiry(
      id: _readString(json['id']) ?? '',
      listingId: _readString(json['listingId']) ?? '',
      travelerId: _readString(json['travelerId']) ?? '',
      vendorId: _readString(json['vendorId']) ?? '',
      question: _readString(json['question']) ?? '',
      createdAt: _readDate(json['createdAt']),
      answer: _readString(json['answer']),
      answeredAt: _readNullableDate(json['answeredAt']),
      isPublic: _readBool(json['isPublic'], fallback: true),
    );
  }

  static Map<String, dynamic> _notificationToJson(NotificationItem item) {
    return <String, dynamic>{
      'id': item.id,
      'userId': item.userId,
      'title': item.title,
      'body': item.body,
      'createdAt': item.createdAt.toIso8601String(),
      'isRead': item.isRead,
    };
  }

  static NotificationItem _notificationFromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: _readString(json['id']) ?? '',
      userId: _readString(json['userId']) ?? '',
      title: _readString(json['title']) ?? '',
      body: _readString(json['body']) ?? '',
      createdAt: _readDate(json['createdAt']),
      isRead: _readBool(json['isRead']),
    );
  }

  static Map<String, dynamic> _itineraryPlanToJson(ItineraryPlan plan) {
    return <String, dynamic>{
      'id': plan.id,
      'request': _tripRequestToJson(plan.request),
      'items': plan.items.map(_itineraryItemToJson).toList(),
      'cost': _costBreakdownToJson(plan.cost),
      'remainingBudget': plan.remainingBudget,
      'cheaperAlternatives': plan.cheaperAlternatives
          .map(_listingToJson)
          .toList(),
      'upgradeAlternatives': plan.upgradeAlternatives
          .map(_listingToJson)
          .toList(),
      'message': plan.message,
    };
  }

  static ItineraryPlan _itineraryPlanFromJson(Map<String, dynamic> json) {
    final requestMap = json['request'] is Map<String, dynamic>
        ? json['request'] as Map<String, dynamic>
        : json['request'] is Map
        ? Map<String, dynamic>.from(json['request'] as Map)
        : <String, dynamic>{};

    final costMap = json['cost'] is Map<String, dynamic>
        ? json['cost'] as Map<String, dynamic>
        : json['cost'] is Map
        ? Map<String, dynamic>.from(json['cost'] as Map)
        : <String, dynamic>{};

    return ItineraryPlan(
      id: _readString(json['id']) ?? '',
      request: _tripRequestFromJson(requestMap),
      items: _readList(json['items'], _itineraryItemFromJson),
      cost: _costBreakdownFromJson(costMap),
      remainingBudget: _readDouble(json['remainingBudget']),
      cheaperAlternatives: _readList(
        json['cheaperAlternatives'],
        _listingFromJson,
      ),
      upgradeAlternatives: _readList(
        json['upgradeAlternatives'],
        _listingFromJson,
      ),
      message: _readString(json['message']) ?? '',
    );
  }

  static Map<String, dynamic> _tripRequestToJson(TripRequest request) {
    return <String, dynamic>{
      'startCity': request.startCity,
      'destinationState': request.destinationState,
      'startDate': request.startDate.toIso8601String(),
      'endDate': request.endDate.toIso8601String(),
      'budget': request.budget,
      'interests': request.interests,
      'pace': request.pace.name,
      'transportMode': request.transportMode.name,
      'stayType': request.stayType.name,
    };
  }

  static TripRequest _tripRequestFromJson(Map<String, dynamic> json) {
    return TripRequest(
      startCity: _readString(json['startCity']) ?? '',
      destinationState: _readString(json['destinationState']) ?? '',
      startDate: _readDate(json['startDate']),
      endDate: _readDate(json['endDate']),
      budget: _readDouble(json['budget']),
      interests: _readStringList(json['interests']),
      pace: _readEnum(Pace.values, _readString(json['pace']), Pace.balanced),
      transportMode: _readEnum(
        TransportMode.values,
        _readString(json['transportMode']),
        TransportMode.mixed,
      ),
      stayType: _readEnum(
        StayType.values,
        _readString(json['stayType']),
        StayType.hostel,
      ),
    );
  }

  static Map<String, dynamic> _itineraryItemToJson(ItineraryItem item) {
    return <String, dynamic>{
      'dayIndex': item.dayIndex,
      'timeSlot': item.timeSlot.name,
      'listingId': item.listingId,
      'listingTitle': item.listingTitle,
      'estimatedCost': item.estimatedCost,
      'category': item.category,
      'notes': item.notes,
      'score': item.score,
    };
  }

  static ItineraryItem _itineraryItemFromJson(Map<String, dynamic> json) {
    return ItineraryItem(
      dayIndex: _readInt(json['dayIndex'], fallback: 1),
      timeSlot: _readEnum(
        TimeSlot.values,
        _readString(json['timeSlot']),
        TimeSlot.morning,
      ),
      listingId: _readString(json['listingId']) ?? '',
      listingTitle: _readString(json['listingTitle']) ?? '',
      estimatedCost: _readDouble(json['estimatedCost']),
      category: _readString(json['category']) ?? '',
      notes: _readString(json['notes']) ?? '',
      score: _readDouble(json['score']),
    );
  }

  static Map<String, dynamic> _costBreakdownToJson(CostBreakdown cost) {
    return <String, dynamic>{
      'transport': cost.transport,
      'accommodation': cost.accommodation,
      'activities': cost.activities,
      'foodEstimate': cost.foodEstimate,
      'fees': cost.fees,
    };
  }

  static CostBreakdown _costBreakdownFromJson(Map<String, dynamic> json) {
    return CostBreakdown(
      transport: _readDouble(json['transport']),
      accommodation: _readDouble(json['accommodation']),
      activities: _readDouble(json['activities']),
      foodEstimate: _readDouble(json['foodEstimate']),
      fees: _readDouble(json['fees']),
    );
  }

  static Map<String, dynamic> _destinationToJson(Destination destination) {
    return <String, dynamic>{
      'id': destination.id,
      'name': destination.name,
      'state': destination.state,
      'description': destination.description,
      'budgetLow': destination.budgetLow,
      'budgetHigh': destination.budgetHigh,
      'recommendedDays': destination.recommendedDays,
      'highlights': destination.highlights,
      'isActive': destination.isActive,
    };
  }

  static Destination _destinationFromJson(Map<String, dynamic> json) {
    return Destination(
      id: _readString(json['id']) ?? '',
      name: _readString(json['name']) ?? '',
      state: _readString(json['state']) ?? '',
      description: _readString(json['description']) ?? '',
      budgetLow: _readDouble(json['budgetLow'], fallback: 120),
      budgetHigh: _readDouble(json['budgetHigh'], fallback: 400),
      recommendedDays: _readInt(json['recommendedDays'], fallback: 3),
      highlights: _readStringList(json['highlights']),
      isActive: _readBool(json['isActive'], fallback: true),
    );
  }

  static Map<String, dynamic> _availabilityToJson(AvailabilityWindow window) {
    return <String, dynamic>{
      'id': window.id,
      'listingId': window.listingId,
      'startDate': window.startDate.toIso8601String(),
      'endDate': window.endDate.toIso8601String(),
      'reason': window.reason,
    };
  }

  static AvailabilityWindow _availabilityFromJson(Map<String, dynamic> json) {
    return AvailabilityWindow(
      id: _readString(json['id']) ?? '',
      listingId: _readString(json['listingId']) ?? '',
      startDate: _readDate(json['startDate']),
      endDate: _readDate(json['endDate']),
      reason: _readString(json['reason']) ?? 'Unavailable',
    );
  }

  static String? _readString(dynamic raw) {
    if (raw is String) {
      return raw;
    }
    return null;
  }

  static List<String> _readStringList(dynamic raw) {
    if (raw is! List) {
      return <String>[];
    }
    return raw.whereType<String>().toList();
  }

  static double _readDouble(dynamic raw, {double fallback = 0}) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw) ?? fallback;
    }
    return fallback;
  }

  static int _readInt(dynamic raw, {int fallback = 0}) {
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

  static bool _readBool(dynamic raw, {bool fallback = false}) {
    if (raw is bool) {
      return raw;
    }
    return fallback;
  }

  static DateTime _readDate(dynamic raw) {
    final parsed = _readNullableDate(raw);
    if (parsed != null) {
      return parsed;
    }
    return DateTime.now();
  }

  static DateTime? _readNullableDate(dynamic raw) {
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

  static T _readEnum<T extends Enum>(List<T> values, String? raw, T fallback) {
    if (raw == null) {
      return fallback;
    }
    for (final value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    return fallback;
  }
}

class LocalPersistenceService {
  static const String _snapshotKey = 'jombudget_snapshot_v1';

  Future<AppSnapshot?> load() async {
    final prefs = await _safePrefs();
    if (prefs == null) {
      return null;
    }
    final raw = prefs.getString(_snapshotKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return AppSnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AppSnapshot snapshot) async {
    final prefs = await _safePrefs();
    if (prefs == null) {
      return;
    }

    try {
      await prefs.setString(_snapshotKey, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> clear() async {
    final prefs = await _safePrefs();
    if (prefs == null) {
      return;
    }
    try {
      await prefs.remove(_snapshotKey);
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<SharedPreferences?> _safePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }
}
