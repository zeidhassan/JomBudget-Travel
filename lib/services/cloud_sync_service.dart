import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/models.dart';

class CloudSyncService {
  CloudSyncService({required this.enabled});

  final bool enabled;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  Future<void> upsertUser(AppUser user) async {
    await _upsert('users', user.id, <String, dynamic>{
      'name': user.name,
      'email': user.email,
      'role': user.role.name,
      'isActive': user.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> upsertAuthUserProfile({
    required String authUid,
    required AppUser user,
  }) async {
    await _upsert('users', authUid, <String, dynamic>{
      'name': user.name,
      'email': user.email,
      'role': user.role.name,
      'legacyId': user.id,
      'isActive': user.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> upsertListing(Listing listing) async {
    await _upsert('listings', listing.id, <String, dynamic>{
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
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> upsertBooking(Booking booking) async {
    await _upsert('bookings', booking.id, <String, dynamic>{
      'travelerId': booking.travelerId,
      'listingId': booking.listingId,
      'listingTitle': booking.listingTitle,
      'vendorId': booking.vendorId,
      'startDate': Timestamp.fromDate(booking.startDate),
      'endDate': Timestamp.fromDate(booking.endDate),
      'pax': booking.pax,
      'status': booking.status.name,
      'paymentStatus': booking.paymentStatus.name,
      'totalAmount': booking.totalAmount,
      'idempotencyKey': booking.idempotencyKey,
      'createdAt': Timestamp.fromDate(booking.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> upsertPayment(PaymentMock payment) async {
    await _upsert('payments_mock', payment.id, <String, dynamic>{
      'bookingId': payment.bookingId,
      'amount': payment.amount,
      'method': payment.method,
      'status': payment.status.name,
      'createdAt': Timestamp.fromDate(payment.createdAt),
    });
  }

  Future<void> upsertReview(Review review) async {
    await _upsert('reviews', review.id, <String, dynamic>{
      'bookingId': review.bookingId,
      'travelerId': review.travelerId,
      'listingId': review.listingId,
      'rating': review.rating,
      'comment': review.comment,
      'images': review.images,
      'isFlagged': review.isFlagged,
      'vendorReply': review.vendorReply,
      'createdAt': Timestamp.fromDate(review.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> upsertInquiry(Inquiry inquiry) async {
    await _upsert('inquiries', inquiry.id, <String, dynamic>{
      'listingId': inquiry.listingId,
      'travelerId': inquiry.travelerId,
      'vendorId': inquiry.vendorId,
      'question': inquiry.question,
      'answer': inquiry.answer,
      'isPublic': inquiry.isPublic,
      'createdAt': Timestamp.fromDate(inquiry.createdAt),
      'answeredAt': inquiry.answeredAt == null
          ? null
          : Timestamp.fromDate(inquiry.answeredAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> upsertDestination(Destination destination) async {
    await _upsert('destinations', destination.id, <String, dynamic>{
      'name': destination.name,
      'state': destination.state,
      'description': destination.description,
      'budgetLow': destination.budgetLow,
      'budgetHigh': destination.budgetHigh,
      'recommendedDays': destination.recommendedDays,
      'highlights': destination.highlights,
      'isActive': destination.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> upsertNotification(NotificationItem notification) async {
    await _upsert('notifications', notification.id, <String, dynamic>{
      'userId': notification.userId,
      'title': notification.title,
      'body': notification.body,
      'isRead': notification.isRead,
      'createdAt': Timestamp.fromDate(notification.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> upsertItinerary({
    required String travelerId,
    required ItineraryPlan plan,
  }) async {
    await _upsert('itineraries', plan.id, <String, dynamic>{
      'travelerId': travelerId,
      'message': plan.message,
      'remainingBudget': plan.remainingBudget,
      'request': <String, dynamic>{
        'startCity': plan.request.startCity,
        'destinationState': plan.request.destinationState,
        'startDate': Timestamp.fromDate(plan.request.startDate),
        'endDate': Timestamp.fromDate(plan.request.endDate),
        'budget': plan.request.budget,
        'interests': plan.request.interests,
        'pace': plan.request.pace.name,
        'transportMode': plan.request.transportMode.name,
        'stayType': plan.request.stayType.name,
      },
      'cost': <String, dynamic>{
        'transport': plan.cost.transport,
        'accommodation': plan.cost.accommodation,
        'activities': plan.cost.activities,
        'foodEstimate': plan.cost.foodEstimate,
        'fees': plan.cost.fees,
        'total': plan.cost.total,
      },
      'items': plan.items
          .map(
            (item) => <String, dynamic>{
              'dayIndex': item.dayIndex,
              'timeSlot': item.timeSlot.name,
              'listingId': item.listingId,
              'listingTitle': item.listingTitle,
              'estimatedCost': item.estimatedCost,
              'category': item.category,
              'notes': item.notes,
              'score': item.score,
            },
          )
          .toList(),
      'cheaperAlternatives': plan.cheaperAlternatives
          .map(
            (listing) => <String, dynamic>{
              'id': listing.id,
              'title': listing.title,
              'priceBase': listing.priceBase,
              'ratingAvg': listing.ratingAvg,
            },
          )
          .toList(),
      'upgradeAlternatives': plan.upgradeAlternatives
          .map(
            (listing) => <String, dynamic>{
              'id': listing.id,
              'title': listing.title,
              'priceBase': listing.priceBase,
              'ratingAvg': listing.ratingAvg,
            },
          )
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> upsertAvailability(AvailabilityWindow window) async {
    await _upsert('availability', window.id, <String, dynamic>{
      'listingId': window.listingId,
      'startDate': Timestamp.fromDate(window.startDate),
      'endDate': Timestamp.fromDate(window.endDate),
      'reason': window.reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAvailability(String id) async {
    await _delete('availability', id);
  }

  Future<void> deleteListing(String id) async {
    await _delete('listings', id);
  }

  Future<void> deleteDestination(String id) async {
    await _delete('destinations', id);
  }

  Future<String?> uploadImage({
    required Uint8List bytes,
    required String folder,
    required String filename,
  }) async {
    if (!enabled) {
      return null;
    }

    try {
      final ref = _storage.ref('$folder/$filename');
      await ref.putData(bytes);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _upsert(
    String collection,
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (!enabled) {
      return;
    }

    try {
      await _db
          .collection(collection)
          .doc(id)
          .set(payload, SetOptions(merge: true));
    } catch (_) {
      // Soft-fail: local app flow should continue even without backend.
    }
  }

  Future<void> _delete(String collection, String id) async {
    if (!enabled) {
      return;
    }

    try {
      await _db.collection(collection).doc(id).delete();
    } catch (_) {
      // Ignore.
    }
  }
}
