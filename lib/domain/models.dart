import 'package:flutter/foundation.dart';

enum UserRole { traveler, vendor, admin }

enum ListingType { accommodation, activity, restaurant, attraction }

enum Pace { relaxed, balanced, packed }

enum TransportMode { bus, train, flight, mixed }

enum StayType { hostel, budgetHotel, midRange }

enum TimeSlot { morning, afternoon, evening }

enum BookingStatus {
  pending,
  confirmed,
  rejected,
  cancelRequested,
  cancelled,
  completed,
}

enum PaymentStatus { unpaid, paid, refunded }

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final bool isActive;

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    UserRole? role,
    bool? isActive,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }
}

@immutable
class Listing {
  const Listing({
    required this.id,
    required this.vendorId,
    required this.type,
    required this.title,
    required this.description,
    required this.location,
    required this.state,
    required this.priceBase,
    required this.tags,
    required this.ratingAvg,
    this.imageUrls = const <String>[],
    this.isActive = true,
  });

  final String id;
  final String vendorId;
  final ListingType type;
  final String title;
  final String description;
  final String location;
  final String state;
  final double priceBase;
  final List<String> tags;
  final double ratingAvg;
  final List<String> imageUrls;
  final bool isActive;

  Listing copyWith({
    String? id,
    String? vendorId,
    ListingType? type,
    String? title,
    String? description,
    String? location,
    String? state,
    double? priceBase,
    List<String>? tags,
    double? ratingAvg,
    List<String>? imageUrls,
    bool? isActive,
  }) {
    return Listing(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      state: state ?? this.state,
      priceBase: priceBase ?? this.priceBase,
      tags: tags ?? this.tags,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      imageUrls: imageUrls ?? this.imageUrls,
      isActive: isActive ?? this.isActive,
    );
  }
}

@immutable
class TripRequest {
  const TripRequest({
    required this.startCity,
    required this.destinationState,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.interests,
    required this.pace,
    required this.transportMode,
    required this.stayType,
  });

  final String startCity;
  final String destinationState;
  final DateTime startDate;
  final DateTime endDate;
  final double budget;
  final List<String> interests;
  final Pace pace;
  final TransportMode transportMode;
  final StayType stayType;

  int get days {
    final diff = endDate.difference(startDate).inDays + 1;
    return diff < 1 ? 1 : diff;
  }
}

@immutable
class CostBreakdown {
  const CostBreakdown({
    required this.transport,
    required this.accommodation,
    required this.activities,
    required this.foodEstimate,
    required this.fees,
  });

  final double transport;
  final double accommodation;
  final double activities;
  final double foodEstimate;
  final double fees;

  double get total =>
      transport + accommodation + activities + foodEstimate + fees;
}

@immutable
class ItineraryItem {
  const ItineraryItem({
    required this.dayIndex,
    required this.timeSlot,
    required this.listingId,
    required this.listingTitle,
    required this.estimatedCost,
    required this.category,
    required this.notes,
    required this.score,
  });

  final int dayIndex;
  final TimeSlot timeSlot;
  final String listingId;
  final String listingTitle;
  final double estimatedCost;
  final String category;
  final String notes;
  final double score;
}

@immutable
class ItineraryPlan {
  const ItineraryPlan({
    required this.id,
    required this.request,
    required this.items,
    required this.cost,
    required this.remainingBudget,
    required this.cheaperAlternatives,
    required this.upgradeAlternatives,
    required this.message,
  });

  final String id;
  final TripRequest request;
  final List<ItineraryItem> items;
  final CostBreakdown cost;
  final double remainingBudget;
  final List<Listing> cheaperAlternatives;
  final List<Listing> upgradeAlternatives;
  final String message;
}

@immutable
class Booking {
  const Booking({
    required this.id,
    required this.travelerId,
    required this.listingId,
    required this.listingTitle,
    required this.vendorId,
    required this.startDate,
    required this.endDate,
    required this.pax,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    required this.idempotencyKey,
    required this.createdAt,
  });

  final String id;
  final String travelerId;
  final String listingId;
  final String listingTitle;
  final String vendorId;
  final DateTime startDate;
  final DateTime endDate;
  final int pax;
  final BookingStatus status;
  final PaymentStatus paymentStatus;
  final double totalAmount;
  final String idempotencyKey;
  final DateTime createdAt;

  Booking copyWith({BookingStatus? status, PaymentStatus? paymentStatus}) {
    return Booking(
      id: id,
      travelerId: travelerId,
      listingId: listingId,
      listingTitle: listingTitle,
      vendorId: vendorId,
      startDate: startDate,
      endDate: endDate,
      pax: pax,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      totalAmount: totalAmount,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
    );
  }
}

@immutable
class PaymentMock {
  const PaymentMock({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.method,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String bookingId;
  final double amount;
  final String method;
  final DateTime createdAt;
  final PaymentStatus status;
}

@immutable
class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.travelerId,
    required this.listingId,
    required this.rating,
    required this.comment,
    required this.images,
    required this.createdAt,
    this.isFlagged = false,
    this.vendorReply,
  });

  final String id;
  final String bookingId;
  final String travelerId;
  final String listingId;
  final int rating;
  final String comment;
  final List<String> images;
  final DateTime createdAt;
  final bool isFlagged;
  final String? vendorReply;

  Review copyWith({bool? isFlagged, String? vendorReply}) {
    return Review(
      id: id,
      bookingId: bookingId,
      travelerId: travelerId,
      listingId: listingId,
      rating: rating,
      comment: comment,
      images: images,
      createdAt: createdAt,
      isFlagged: isFlagged ?? this.isFlagged,
      vendorReply: vendorReply ?? this.vendorReply,
    );
  }
}

@immutable
class Inquiry {
  const Inquiry({
    required this.id,
    required this.listingId,
    required this.travelerId,
    required this.vendorId,
    required this.question,
    required this.createdAt,
    this.answer,
    this.answeredAt,
    this.isPublic = true,
  });

  final String id;
  final String listingId;
  final String travelerId;
  final String vendorId;
  final String question;
  final DateTime createdAt;
  final String? answer;
  final DateTime? answeredAt;
  final bool isPublic;

  bool get isAnswered => answer != null && answer!.trim().isNotEmpty;

  Inquiry copyWith({String? answer, DateTime? answeredAt, bool? isPublic}) {
    return Inquiry(
      id: id,
      listingId: listingId,
      travelerId: travelerId,
      vendorId: vendorId,
      question: question,
      createdAt: createdAt,
      answer: answer ?? this.answer,
      answeredAt: answeredAt ?? this.answeredAt,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}

@immutable
class Destination {
  const Destination({
    required this.id,
    required this.name,
    required this.state,
    required this.description,
    this.budgetLow = 150,
    this.budgetHigh = 450,
    this.recommendedDays = 3,
    this.highlights = const <String>[],
    this.isActive = true,
  });

  final String id;
  final String name;
  final String state;
  final String description;
  final double budgetLow;
  final double budgetHigh;
  final int recommendedDays;
  final List<String> highlights;
  final bool isActive;

  Destination copyWith({
    String? name,
    String? state,
    String? description,
    double? budgetLow,
    double? budgetHigh,
    int? recommendedDays,
    List<String>? highlights,
    bool? isActive,
  }) {
    return Destination(
      id: id,
      name: name ?? this.name,
      state: state ?? this.state,
      description: description ?? this.description,
      budgetLow: budgetLow ?? this.budgetLow,
      budgetHigh: budgetHigh ?? this.budgetHigh,
      recommendedDays: recommendedDays ?? this.recommendedDays,
      highlights: highlights ?? this.highlights,
      isActive: isActive ?? this.isActive,
    );
  }
}

@immutable
class ItineraryRecord {
  const ItineraryRecord({required this.travelerId, required this.plan});

  final String travelerId;
  final ItineraryPlan plan;
}

@immutable
class AvailabilityWindow {
  const AvailabilityWindow({
    required this.id,
    required this.listingId,
    required this.startDate,
    required this.endDate,
    required this.reason,
  });

  final String id;
  final String listingId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
}

@immutable
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      userId: userId,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

@immutable
class ReportSnapshot {
  const ReportSnapshot({
    required this.id,
    required this.createdAt,
    required this.totalBookings,
    required this.pendingBookings,
    required this.totalRevenue,
    required this.popularListingTitles,
    required this.cancellationReasons,
  });

  final String id;
  final DateTime createdAt;
  final int totalBookings;
  final int pendingBookings;
  final double totalRevenue;
  final List<String> popularListingTitles;
  final Map<String, int> cancellationReasons;
}
