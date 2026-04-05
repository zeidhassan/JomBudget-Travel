/**
 * JomBudget Firestore Seeder
 *
 * Usage:
 *   1. Download your Firebase service account key:
 *      Firebase Console → Project Settings → Service accounts → Generate new private key
 *      Save the JSON file as: firebase/serviceAccountKey.json
 *
 *   2. Install dependency (one-time):
 *      cd firebase && npm install firebase-admin
 *
 *   3. Run:
 *      node firebase/seed_firestore.js
 *
 * This script:
 *   - Creates Firebase Auth accounts for all seed users (password: pass123)
 *   - Uploads demo listing images to Firebase Storage
 *   - Writes all seed documents to Firestore (with real Storage image URLs)
 *   - Is safe to re-run (uses set with merge)
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// ── Init ──────────────────────────────────────────────────────────────────────

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'jombudget-travel-6c219.firebasestorage.app',
});

const db = admin.firestore();
const auth = admin.auth();
const bucket = admin.storage().bucket();

// ── Helpers ───────────────────────────────────────────────────────────────────

function dayOffset(days) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  today.setDate(today.getDate() + days);
  return admin.firestore.Timestamp.fromDate(today);
}

async function upsert(collection, id, data) {
  await db.collection(collection).doc(id).set(data, { merge: true });
}

// Images dir is two levels up from firebase/ → project root → assets/demo_images/
const IMAGES_DIR = path.join(__dirname, '..', 'assets', 'demo_images');

async function uploadListingImage(listingId) {
  const filename = `${listingId}.png`;
  const localPath = path.join(IMAGES_DIR, filename);
  if (!fs.existsSync(localPath)) {
    console.log(`  No image found for ${listingId}, skipping.`);
    return null;
  }
  const destination = `listings/${filename}`;
  try {
    await bucket.upload(localPath, {
      destination,
      metadata: { contentType: 'image/png' },
    });
    const file = bucket.file(destination);
    await file.makePublic();
    const url = `https://storage.googleapis.com/${bucket.name}/${destination}`;
    console.log(`  Uploaded ${filename} → ${url}`);
    return url;
  } catch (err) {
    if (err.code === 404 || (err.message && err.message.includes('does not exist'))) {
      console.error(`\n  ERROR: Storage bucket not found.`);
      console.error(`  → Go to Firebase Console → Build → Storage → Get Started`);
      console.error(`  → Then re-run this script.\n`);
      process.exit(1);
    }
    throw err;
  }
}

async function createAuthUser(email, password, displayName) {
  try {
    const existing = await auth.getUserByEmail(email);
    console.log(`  Auth user already exists: ${email} (uid: ${existing.uid})`);
    return existing.uid;
  } catch {
    const user = await auth.createUser({ email, password, displayName });
    console.log(`  Created auth user: ${email} (uid: ${user.uid})`);
    return user.uid;
  }
}

// ── Seed Data ─────────────────────────────────────────────────────────────────

const USERS = [
  { id: 'u-traveler-1', name: 'Aina Student',           email: 'traveler@student.my',  role: 'traveler' },
  { id: 'u-traveler-2', name: 'Irfan Backpacker',       email: 'irfan@student.my',      role: 'traveler' },
  { id: 'u-traveler-3', name: 'Mei Ling Explorer',      email: 'meiling@student.my',    role: 'traveler' },
  { id: 'u-vendor-1',   name: 'Langkawi Escape Sdn Bhd',email: 'vendor@langkawi.my',    role: 'vendor'   },
  { id: 'u-vendor-2',   name: 'KL City Food Tours',     email: 'vendor@klfood.my',      role: 'vendor'   },
  { id: 'u-vendor-3',   name: 'Borneo Student Trails',  email: 'vendor@borneo.my',      role: 'vendor'   },
  { id: 'u-admin-1',    name: 'JomBudget Admin',        email: 'admin@jombudget.my',    role: 'admin'    },
];

const LISTINGS = [
  { id: 'l-1',  vendorId: 'u-vendor-1', type: 'accommodation', title: 'Batu Ferringhi Budget Stay',       description: 'Student-friendly hostel near beach with shared kitchen.',          location: 'Batu Ferringhi',      state: 'Penang',        priceBase: 58,  tags: ['beach','hostel','budget'],         ratingAvg: 4.3, imageUrls: [], isActive: true },
  { id: 'l-2',  vendorId: 'u-vendor-2', type: 'restaurant',    title: 'Jalan Alor Student Meal Pass',     description: 'Meal pass package for budget travelers in KL.',                   location: 'Bukit Bintang',       state: 'Kuala Lumpur',  priceBase: 22,  tags: ['food','local','night-life'],       ratingAvg: 4.5, imageUrls: [], isActive: true },
  { id: 'l-3',  vendorId: 'u-vendor-1', type: 'activity',      title: 'Langkawi Island Hopping',          description: 'Half-day island hopping with student group discount.',            location: 'Kuah',                state: 'Kedah',         priceBase: 75,  tags: ['adventure','nature','boat'],       ratingAvg: 4.7, imageUrls: [], isActive: true },
  { id: 'l-4',  vendorId: 'u-vendor-1', type: 'attraction',    title: 'Melaka Heritage Walk',             description: 'Guided historical walking tour in UNESCO heritage zone.',         location: 'Bandar Hilir',        state: 'Melaka',        priceBase: 35,  tags: ['history','culture','walking'],     ratingAvg: 4.2, imageUrls: [], isActive: true },
  { id: 'l-5',  vendorId: 'u-vendor-2', type: 'activity',      title: 'Cameron Highlands Tea Tour',       description: 'Budget mini-bus tea plantation and farm visit package.',          location: 'Brinchang',           state: 'Pahang',        priceBase: 49,  tags: ['nature','chill','farm'],           ratingAvg: 4.4, imageUrls: [], isActive: true },
  { id: 'l-6',  vendorId: 'u-vendor-2', type: 'accommodation', title: 'KL Transit Capsule Hostel',        description: 'Near LRT and MRT, ideal for students on city trips.',             location: 'Pasar Seni',          state: 'Kuala Lumpur',  priceBase: 65,  tags: ['city','hostel','transport'],       ratingAvg: 4.1, imageUrls: [], isActive: true },
  { id: 'l-7',  vendorId: 'u-vendor-2', type: 'attraction',    title: 'Sabah Sunset Coastal Trail',       description: 'Scenic low-cost guided trail with local community guide.',        location: 'Kota Kinabalu',       state: 'Sabah',         priceBase: 42,  tags: ['nature','sunset','community'],     ratingAvg: 4.6, imageUrls: [], isActive: true },
  { id: 'l-8',  vendorId: 'u-vendor-1', type: 'restaurant',    title: 'Penang Hawker Crawl',              description: 'Street food tasting set with transparent per-item pricing.',    location: 'George Town',         state: 'Penang',        priceBase: 28,  tags: ['food','culture','night-life'],     ratingAvg: 4.8, imageUrls: [], isActive: true },
  { id: 'l-9',  vendorId: 'u-vendor-1', type: 'activity',      title: 'Johor Outlet Shuttle Day Pass',    description: 'Low-cost shuttle + shopping route for weekend trips.',            location: 'Johor Bahru',         state: 'Johor',         priceBase: 30,  tags: ['shopping','transport','city'],     ratingAvg: 3.9, imageUrls: [], isActive: true },
  { id: 'l-10', vendorId: 'u-vendor-1', type: 'activity',      title: 'Langkawi Sunset Ride',             description: 'Sunset motorbike route with safety briefing and maps.',          location: 'Pantai Cenang',       state: 'Kedah',         priceBase: 52,  tags: ['adventure','sunset','community'],  ratingAvg: 4.5, imageUrls: [], isActive: true },
  { id: 'l-11', vendorId: 'u-vendor-3', type: 'restaurant',    title: 'Ipoh Food and Murals Trail',       description: 'Budget combo for street food spots and mural lane walk.',         location: 'Old Town',            state: 'Perak',         priceBase: 38,  tags: ['food','culture','walking'],        ratingAvg: 4.4, imageUrls: [], isActive: true },
  { id: 'l-12', vendorId: 'u-vendor-3', type: 'attraction',    title: 'Kuching Riverfront Cruise',        description: 'Student-priced evening river cruise with city landmarks.',        location: 'Kuching Waterfront',  state: 'Sarawak',       priceBase: 55,  tags: ['nature','city','culture'],         ratingAvg: 4.6, imageUrls: [], isActive: true },
];

const DESTINATIONS = [
  { id: 'd-1', name: 'George Town Heritage District', state: 'Penang',        description: 'Street food, murals, and heritage walk zone.',         budgetLow: 320, budgetHigh: 680,  recommendedDays: 3, highlights: ['Street food','Murals','Clan jetties'],          isActive: true },
  { id: 'd-2', name: 'Bukit Bintang City Area',        state: 'Kuala Lumpur', description: 'Shopping, nightlife, and urban attractions.',           budgetLow: 380, budgetHigh: 820,  recommendedDays: 3, highlights: ['Night market','Transit-friendly','Rooftops'],    isActive: true },
  { id: 'd-3', name: 'Cameron Highlands',              state: 'Pahang',       description: 'Tea plantation routes and nature-based day trips.',     budgetLow: 280, budgetHigh: 640,  recommendedDays: 3, highlights: ['Tea farms','Chill weather','Sunrise spots'],      isActive: true },
  { id: 'd-4', name: 'Ipoh Old Town',                  state: 'Perak',        description: 'Cafe lanes, cave temples, and mural walk circuits.',    budgetLow: 250, budgetHigh: 560,  recommendedDays: 2, highlights: ['White coffee','Cave temples','Old town walk'],    isActive: true },
  { id: 'd-5', name: 'Langkawi Cenang Coast',          state: 'Kedah',        description: 'Island activities, beaches, and sunset viewing points.',budgetLow: 420, budgetHigh: 940,  recommendedDays: 4, highlights: ['Island hopping','Beach sunset','Cable car'],      isActive: true },
  { id: 'd-6', name: 'Kuching Riverfront',             state: 'Sarawak',      description: 'River cruises and budget city culture spots.',          budgetLow: 300, budgetHigh: 700,  recommendedDays: 3, highlights: ['Waterfront walk','Museums','Food court'],          isActive: true },
];

const BOOKINGS = [
  { id: 'b-1', travelerId: 'u-traveler-1', listingId: 'l-1',  listingTitle: 'Batu Ferringhi Budget Stay',   vendorId: 'u-vendor-1', startDate: dayOffset(10),  endDate: dayOffset(11),  pax: 1, status: 'pending',          paymentStatus: 'paid',     totalAmount: 116, idempotencyKey: 'seed-booking-1', createdAt: dayOffset(-2)  },
  { id: 'b-2', travelerId: 'u-traveler-1', listingId: 'l-2',  listingTitle: 'Jalan Alor Student Meal Pass', vendorId: 'u-vendor-2', startDate: dayOffset(18),  endDate: dayOffset(18),  pax: 2, status: 'confirmed',        paymentStatus: 'paid',     totalAmount: 44,  idempotencyKey: 'seed-booking-2', createdAt: dayOffset(-4)  },
  { id: 'b-3', travelerId: 'u-traveler-1', listingId: 'l-3',  listingTitle: 'Langkawi Island Hopping',      vendorId: 'u-vendor-1', startDate: dayOffset(28),  endDate: dayOffset(28),  pax: 1, status: 'cancelRequested',  paymentStatus: 'paid',     totalAmount: 75,  idempotencyKey: 'seed-booking-3', createdAt: dayOffset(-3)  },
  { id: 'b-4', travelerId: 'u-traveler-2', listingId: 'l-6',  listingTitle: 'KL Transit Capsule Hostel',    vendorId: 'u-vendor-2', startDate: dayOffset(-12), endDate: dayOffset(-11), pax: 1, status: 'completed',        paymentStatus: 'paid',     totalAmount: 130, idempotencyKey: 'seed-booking-4', createdAt: dayOffset(-15) },
  { id: 'b-5', travelerId: 'u-traveler-2', listingId: 'l-8',  listingTitle: 'Penang Hawker Crawl',          vendorId: 'u-vendor-1', startDate: dayOffset(-20), endDate: dayOffset(-20), pax: 2, status: 'completed',        paymentStatus: 'paid',     totalAmount: 56,  idempotencyKey: 'seed-booking-5', createdAt: dayOffset(-23) },
  { id: 'b-6', travelerId: 'u-traveler-2', listingId: 'l-7',  listingTitle: 'Sabah Sunset Coastal Trail',   vendorId: 'u-vendor-2', startDate: dayOffset(16),  endDate: dayOffset(16),  pax: 1, status: 'rejected',         paymentStatus: 'refunded', totalAmount: 42,  idempotencyKey: 'seed-booking-6', createdAt: dayOffset(-1)  },
  { id: 'b-7', travelerId: 'u-traveler-3', listingId: 'l-11', listingTitle: 'Ipoh Food and Murals Trail',   vendorId: 'u-vendor-3', startDate: dayOffset(6),   endDate: dayOffset(6),   pax: 1, status: 'pending',          paymentStatus: 'unpaid',   totalAmount: 38,  idempotencyKey: 'seed-booking-7', createdAt: dayOffset(-1)  },
  { id: 'b-8', travelerId: 'u-traveler-3', listingId: 'l-12', listingTitle: 'Kuching Riverfront Cruise',    vendorId: 'u-vendor-3', startDate: dayOffset(22),  endDate: dayOffset(23),  pax: 1, status: 'cancelled',        paymentStatus: 'refunded', totalAmount: 110, idempotencyKey: 'seed-booking-8', createdAt: dayOffset(-2)  },
];

const PAYMENTS = [
  { id: 'p-1', bookingId: 'b-1', amount: 116, method: 'Card',           status: 'paid',     createdAt: dayOffset(-2)  },
  { id: 'p-2', bookingId: 'b-2', amount: 44,  method: 'E-Wallet',       status: 'paid',     createdAt: dayOffset(-4)  },
  { id: 'p-3', bookingId: 'b-3', amount: 75,  method: 'Online Banking', status: 'paid',     createdAt: dayOffset(-3)  },
  { id: 'p-4', bookingId: 'b-4', amount: 130, method: 'Card',           status: 'paid',     createdAt: dayOffset(-15) },
  { id: 'p-5', bookingId: 'b-5', amount: 56,  method: 'E-Wallet',       status: 'paid',     createdAt: dayOffset(-23) },
  { id: 'p-6', bookingId: 'b-6', amount: 42,  method: 'Card',           status: 'refunded', createdAt: dayOffset(-1)  },
  { id: 'p-7', bookingId: 'b-8', amount: 110, method: 'Online Banking', status: 'refunded', createdAt: dayOffset(-1)  },
];

const REVIEWS = [
  { id: 'r-1',  bookingId: 'b-4',      travelerId: 'u-traveler-2', listingId: 'l-6',  rating: 4, comment: 'Clean stay and near transport. Good value.',                          images: [],        isFlagged: false, vendorReply: null,                                            createdAt: dayOffset(-10) },
  { id: 'r-2',  bookingId: 'b-5',      travelerId: 'u-traveler-2', listingId: 'l-8',  rating: 5, comment: 'Best budget food route for our weekend group trip.',                  images: [],        isFlagged: false, vendorReply: null,                                            createdAt: dayOffset(-18) },
  { id: 'r-3',  bookingId: 'b-2',      travelerId: 'u-traveler-1', listingId: 'l-2',  rating: 3, comment: 'Good food choices, but waiting time was slightly long.',               images: [],        isFlagged: false, vendorReply: 'Thanks for the feedback. We now added timed slots.', createdAt: dayOffset(-2)  },
  { id: 'r-4',  bookingId: 'b-1',      travelerId: 'u-traveler-1', listingId: 'l-1',  rating: 5, comment: 'Smooth check-in and super helpful staff at midnight.',                 images: [],        isFlagged: false, vendorReply: 'Glad it helped. Safe travels and see you again.',    createdAt: dayOffset(-6)  },
  { id: 'r-5',  bookingId: 'b-demo-1', travelerId: 'u-traveler-3', listingId: 'l-3',  rating: 4, comment: 'Island hopping was fun and the guide explained clearly.',              images: [],        isFlagged: false, vendorReply: null,                                            createdAt: dayOffset(-8)  },
  { id: 'r-6',  bookingId: 'b-6',      travelerId: 'u-traveler-2', listingId: 'l-7',  rating: 2, comment: 'Weather delay reduced the trail time significantly.',                  images: [],        isFlagged: true,  vendorReply: null,                                            createdAt: dayOffset(-1)  },
  { id: 'r-7',  bookingId: 'b-7',      travelerId: 'u-traveler-3', listingId: 'l-11', rating: 5, comment: 'Excellent value and the route was very student-friendly.',             images: [],        isFlagged: false, vendorReply: null,                                            createdAt: dayOffset(-4)  },
  { id: 'r-8',  bookingId: 'b-8',      travelerId: 'u-traveler-3', listingId: 'l-12', rating: 4, comment: 'Great city views during sunset; worth the budget.',                    images: [],        isFlagged: false, vendorReply: null,                                            createdAt: dayOffset(-5)  },
  { id: 'r-9',  bookingId: 'b-demo-2', travelerId: 'u-traveler-1', listingId: 'l-5',  rating: 4, comment: 'Tea estate stop was scenic and timing was well managed.',              images: [],        isFlagged: false, vendorReply: null,                                            createdAt: dayOffset(-9)  },
  { id: 'r-10', bookingId: 'b-demo-3', travelerId: 'u-traveler-2', listingId: 'l-9',  rating: 3, comment: 'Useful shuttle route, but could have more pickup points.',             images: [],        isFlagged: false, vendorReply: null,                                            createdAt: dayOffset(-3)  },
];

const INQUIRIES = [
  { id: 'q-1',  listingId: 'l-1',  travelerId: 'u-traveler-1', vendorId: 'u-vendor-1', question: 'Do you allow late check-in after 11:00 PM?',                     answer: 'Yes, with 24-hour notice we can arrange self-check-in.',               isPublic: true,  createdAt: dayOffset(-5), answeredAt: dayOffset(-4) },
  { id: 'q-2',  listingId: 'l-2',  travelerId: 'u-traveler-2', vendorId: 'u-vendor-2', question: 'Can this meal pass be shared between two travelers?',              answer: null,                                                                    isPublic: true,  createdAt: dayOffset(-1), answeredAt: null          },
  { id: 'q-3',  listingId: 'l-11', travelerId: 'u-traveler-3', vendorId: 'u-vendor-3', question: 'Any vegetarian options in the trail package?',                    answer: 'Yes, we have a full vegetarian route option.',                          isPublic: false, createdAt: dayOffset(-3), answeredAt: dayOffset(-2) },
  { id: 'q-4',  listingId: 'l-8',  travelerId: 'u-traveler-1', vendorId: 'u-vendor-1', question: 'Is halal food route available for this crawl?',                   answer: null,                                                                    isPublic: false, createdAt: dayOffset(-1), answeredAt: null          },
  { id: 'q-5',  listingId: 'l-3',  travelerId: 'u-traveler-1', vendorId: 'u-vendor-1', question: 'Do we need to bring our own life jacket for island hopping?',     answer: 'No, safety equipment is fully provided in the package.',               isPublic: true,  createdAt: dayOffset(-7), answeredAt: dayOffset(-6) },
  { id: 'q-6',  listingId: 'l-6',  travelerId: 'u-traveler-2', vendorId: 'u-vendor-2', question: 'Any female-only dorm option for selected dates?',                 answer: 'Yes, we can reserve female-only capsules subject to capacity.',        isPublic: true,  createdAt: dayOffset(-6), answeredAt: dayOffset(-5) },
  { id: 'q-7',  listingId: 'l-7',  travelerId: 'u-traveler-3', vendorId: 'u-vendor-2', question: 'Is this trail suitable for first-time hikers?',                   answer: 'Yes, beginner pace is available on request.',                          isPublic: true,  createdAt: dayOffset(-4), answeredAt: dayOffset(-3) },
  { id: 'q-8',  listingId: 'l-12', travelerId: 'u-traveler-1', vendorId: 'u-vendor-3', question: 'Can I switch to an earlier cruise slot after booking?',           answer: null,                                                                    isPublic: true,  createdAt: dayOffset(-2), answeredAt: null          },
  { id: 'q-9',  listingId: 'l-11', travelerId: 'u-traveler-2', vendorId: 'u-vendor-3', question: 'How long is the full food and murals route?',                     answer: 'Around 3.5 hours including meal breaks.',                              isPublic: true,  createdAt: dayOffset(-9), answeredAt: dayOffset(-8) },
  { id: 'q-10', listingId: 'l-5',  travelerId: 'u-traveler-3', vendorId: 'u-vendor-2', question: 'Is pickup from Tanah Rata bus terminal included?',                answer: 'Yes, pickup is available at 8:15 AM.',                                 isPublic: true,  createdAt: dayOffset(-5), answeredAt: dayOffset(-5) },
  { id: 'q-11', listingId: 'l-1',  travelerId: 'u-traveler-3', vendorId: 'u-vendor-1', question: 'Do you have quiet hours policy for shared rooms?',                answer: null,                                                                    isPublic: true,  createdAt: dayOffset(-2), answeredAt: null          },
  { id: 'q-12', listingId: 'l-2',  travelerId: 'u-traveler-1', vendorId: 'u-vendor-2', question: 'Can I redeem meal pass over two different days?',                 answer: 'Yes, pass remains valid for 48 hours from first redemption.',          isPublic: true,  createdAt: dayOffset(-10), answeredAt: dayOffset(-9) },
];

const NOTIFICATIONS = [
  { id: 'n-1', userId: 'u-traveler-1', title: 'Booking confirmed',    body: 'Your Jalan Alor Student Meal Pass booking is confirmed.',    isRead: false, createdAt: dayOffset(-1) },
  { id: 'n-2', userId: 'u-traveler-1', title: 'Planner tip',          body: 'Your Penang itinerary has RM120 buffer left for activities.',isRead: true,  createdAt: dayOffset(-2) },
  { id: 'n-3', userId: 'u-vendor-1',   title: 'New inquiry pending',  body: 'Traveler asked a question on Penang Hawker Crawl.',         isRead: false, createdAt: dayOffset(-1) },
  { id: 'n-4', userId: 'u-vendor-2',   title: 'Cancellation request', body: 'Traveler requested cancellation for Langkawi Island Hopping.', isRead: false, createdAt: dayOffset(-1) },
  { id: 'n-5', userId: 'u-vendor-3',   title: 'Pending booking',      body: 'Booking request received for Ipoh Food and Murals Trail.',  isRead: false, createdAt: dayOffset(-1) },
  { id: 'n-6', userId: 'u-admin-1',    title: 'Review moderation',    body: 'A 3-star review was posted and may require follow-up.',     isRead: false, createdAt: dayOffset(-1) },
  { id: 'n-7', userId: 'u-admin-1',    title: 'Report ready',         body: 'Daily rollup report has been generated.',                   isRead: true,  createdAt: dayOffset(-2) },
];

const AVAILABILITY = [
  { id: 'a-1', listingId: 'l-5',  startDate: dayOffset(35), endDate: dayOffset(37), reason: 'Vehicle maintenance'         },
  { id: 'a-2', listingId: 'l-9',  startDate: dayOffset(22), endDate: dayOffset(23), reason: 'Public holiday crowd control' },
  { id: 'a-3', listingId: 'l-11', startDate: dayOffset(40), endDate: dayOffset(42), reason: 'Vendor training program'      },
];

// ── Runner ────────────────────────────────────────────────────────────────────

async function seed() {
  console.log('\n=== JomBudget Firestore Seeder ===\n');

  // 1. Users — create Firebase Auth accounts + Firestore docs
  console.log('--- Users (Auth + Firestore) ---');
  for (const u of USERS) {
    const uid = await createAuthUser(u.email, 'pass123', u.name);
    await upsert('users', uid, {
      name: u.name,
      email: u.email,
      role: u.role,
      legacyId: u.id,
      isActive: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  Firestore users/${uid} → ${u.id} (${u.role})`);
  }

  // 2. Listings (upload images first, then write docs with real URLs)
  console.log('\n--- Listings ---');
  for (const l of LISTINGS) {
    const imageUrl = await uploadListingImage(l.id);
    await upsert('listings', l.id, {
      vendorId: l.vendorId, type: l.type, title: l.title,
      description: l.description, location: l.location, state: l.state,
      priceBase: l.priceBase, tags: l.tags, ratingAvg: l.ratingAvg,
      imageUrls: imageUrl ? [imageUrl] : [],
      isActive: l.isActive,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ${l.id}: ${l.title}`);
  }

  // 3. Destinations
  console.log('\n--- Destinations ---');
  for (const d of DESTINATIONS) {
    await upsert('destinations', d.id, {
      name: d.name, state: d.state, description: d.description,
      budgetLow: d.budgetLow, budgetHigh: d.budgetHigh,
      recommendedDays: d.recommendedDays, highlights: d.highlights,
      isActive: d.isActive,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ${d.id}: ${d.name}`);
  }

  // 4. Bookings
  console.log('\n--- Bookings ---');
  for (const b of BOOKINGS) {
    await upsert('bookings', b.id, {
      travelerId: b.travelerId, listingId: b.listingId,
      listingTitle: b.listingTitle, vendorId: b.vendorId,
      startDate: b.startDate, endDate: b.endDate,
      pax: b.pax, status: b.status, paymentStatus: b.paymentStatus,
      totalAmount: b.totalAmount, idempotencyKey: b.idempotencyKey,
      createdAt: b.createdAt,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ${b.id}: ${b.listingTitle} (${b.status})`);
  }

  // 5. Payments
  console.log('\n--- Payments ---');
  for (const p of PAYMENTS) {
    await upsert('payments_mock', p.id, {
      bookingId: p.bookingId, amount: p.amount,
      method: p.method, status: p.status, createdAt: p.createdAt,
    });
    console.log(`  ${p.id}: ${p.amount} MYR (${p.status})`);
  }

  // 6. Reviews
  console.log('\n--- Reviews ---');
  for (const r of REVIEWS) {
    await upsert('reviews', r.id, {
      bookingId: r.bookingId, travelerId: r.travelerId,
      listingId: r.listingId, rating: r.rating, comment: r.comment,
      images: r.images, isFlagged: r.isFlagged,
      vendorReply: r.vendorReply,
      createdAt: r.createdAt,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ${r.id}: ${r.rating}★ on ${r.listingId}`);
  }

  // 7. Inquiries
  console.log('\n--- Inquiries ---');
  for (const q of INQUIRIES) {
    await upsert('inquiries', q.id, {
      listingId: q.listingId, travelerId: q.travelerId,
      vendorId: q.vendorId, question: q.question,
      answer: q.answer, isPublic: q.isPublic,
      createdAt: q.createdAt, answeredAt: q.answeredAt,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ${q.id}: ${q.question.substring(0, 50)}...`);
  }

  // 8. Notifications
  console.log('\n--- Notifications ---');
  for (const n of NOTIFICATIONS) {
    await upsert('notifications', n.id, {
      userId: n.userId, title: n.title, body: n.body,
      isRead: n.isRead, createdAt: n.createdAt,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ${n.id}: ${n.title} → ${n.userId}`);
  }

  // 9. Availability windows
  console.log('\n--- Availability Windows ---');
  for (const a of AVAILABILITY) {
    await upsert('availability', a.id, {
      listingId: a.listingId, startDate: a.startDate,
      endDate: a.endDate, reason: a.reason,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ${a.id}: ${a.reason} on ${a.listingId}`);
  }

  console.log('\n=== Seeding complete ===\n');
}

seed().catch((err) => {
  console.error('Seeding failed:', err);
  process.exit(1);
});
