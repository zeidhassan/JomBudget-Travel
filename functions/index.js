const admin = require('firebase-admin');
const { onDocumentUpdated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');

admin.initializeApp();
const db = admin.firestore();

exports.onBookingStatusChanged = onDocumentUpdated(
  'bookings/{bookingId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!before || !after) {
      return;
    }

    if (before.status === after.status) {
      return;
    }

    const createdAt = admin.firestore.FieldValue.serverTimestamp();
    const notifications = [
      {
        userId: after.travelerId,
        title: 'Booking status updated',
        body: `${after.listingTitle} is now ${after.status}.`,
        createdAt,
        isRead: false,
      },
      {
        userId: after.vendorId,
        title: 'Booking status updated',
        body: `${after.listingTitle} changed to ${after.status}.`,
        createdAt,
        isRead: false,
      },
    ];

    const adminUsers = await db
      .collection('users')
      .where('role', '==', 'admin')
      .where('isActive', '==', true)
      .get();

    adminUsers.forEach((doc) => {
      notifications.push({
        userId: doc.id,
        title: 'Booking status updated',
        body: `${after.listingTitle} changed to ${after.status}.`,
        createdAt,
        isRead: false,
      });
    });

    const batch = db.batch();
    notifications.forEach((payload) => {
      const ref = db.collection('notifications').doc();
      batch.set(ref, payload);
    });

    await batch.commit();
  },
);

exports.dailyReportRollup = onSchedule('every day 02:00', async () => {
  const [bookingsSnap, paymentsSnap] = await Promise.all([
    db.collection('bookings').get(),
    db.collection('payments_mock').get(),
  ]);

  const bookings = bookingsSnap.docs.map((doc) => doc.data());
  const payments = paymentsSnap.docs.map((doc) => doc.data());

  const totalBookings = bookings.length;
  const pendingBookings = bookings.filter((item) => item.status === 'pending').length;

  const totalRevenue = payments
    .filter((item) => item.status === 'paid')
    .reduce((sum, item) => sum + Number(item.amount || 0), 0);

  const popularityMap = {};
  bookings.forEach((booking) => {
    const key = booking.listingTitle || 'Unknown listing';
    popularityMap[key] = (popularityMap[key] || 0) + 1;
  });

  const popularListingTitles = Object.entries(popularityMap)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([name]) => name);

  await db.collection('reports').add({
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    totalBookings,
    pendingBookings,
    totalRevenue,
    popularListingTitles,
  });
});

exports.moderationTriggers = onDocumentWritten('reviews/{reviewId}', async (event) => {
  const after = event.data.after.data();
  if (!after) {
    return;
  }

  const rating = Number(after.rating || 0);
  const needsModeration = after.isFlagged === true || rating <= 1;
  if (!needsModeration) {
    return;
  }

  const existing = await db
    .collection('reports')
    .where('type', '==', 'review_moderation')
    .where('reviewId', '==', event.params.reviewId)
    .limit(1)
    .get();
  if (!existing.empty) {
    return;
  }

  await db.collection('reports').add({
    type: 'review_moderation',
    reviewId: event.params.reviewId,
    listingId: after.listingId || null,
    travelerId: after.travelerId || null,
    reason: after.isFlagged === true ? 'flagged_by_admin_or_vendor' : 'low_rating',
    rating: rating || null,
    status: 'open',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});
