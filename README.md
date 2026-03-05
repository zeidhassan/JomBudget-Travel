# JomBudget

JomBudget is a role-based Flutter mobile app prototype for **student budget travel planning in Malaysia**.
It implements traveler, vendor, and admin workflows with a deterministic budget optimizer, mock checkout, booking lifecycle management, and moderation/reporting tools.

## Implemented Scope

- Single app with role-based login and routing.
- Traveler features:
  - Browse/search/filter listings.
  - Budget-first itinerary generation.
  - Mock booking + payment + in-app receipt dialog.
  - Availability conflict protection for overlapping booking dates.
  - Q&A inquiries to vendors (public or private question mode).
  - Booking history, cancellation requests, review submission.
- Vendor features:
  - Listing CRUD, image upload, and activation toggles.
  - Blackout window availability management per listing.
  - Booking approval/rejection.
  - Earnings/performance summary.
  - Review replies and inquiry responses.
- Admin features:
  - User and listing moderation.
  - Admin delete flow for listings (with active-booking guard).
  - Destination CRUD + activation management.
  - Booking override for cancellations/refund simulation.
  - Review flagging and inquiry thread visibility.
  - Admin inquiry response support.
  - Report snapshot (bookings, revenue proxy, popular listings, cancellation trends).

## Demo Credentials

- Traveler: `traveler@student.my` / `pass123`
- Traveler 2: `irfan@student.my` / `pass123`
- Traveler 3: `meiling@student.my` / `pass123`
- Vendor: `vendor@langkawi.my` / `pass123`
- Vendor 2: `vendor@klfood.my` / `pass123`
- Vendor 3: `vendor@borneo.my` / `pass123`
- Admin: `admin@jombudget.my` / `pass123`

## App Screenshots

Screenshots are stored in `assets/screenshots/`.

### Authentication and Traveler Flow

- `01_login_screen.png`
- `02_traveler_browse.png`
- `03_traveler_planner_result.png`
- `04_traveler_booking_receipt.png`
- `05_traveler_bookings.png`

![Login Screen](assets/screenshots/01_login_screen.png)
![Traveler Browse](assets/screenshots/02_traveler_browse.png)
![Traveler Planner Result](assets/screenshots/03_traveler_planner_result.png)
![Traveler Booking Receipt](assets/screenshots/04_traveler_booking_receipt.png)
![Traveler Bookings](assets/screenshots/05_traveler_bookings.png)

### Vendor Flow

- `06_vendor_listings.png`
- `07_vendor_bookings.png`
- `08_vendor_feedback.png`

![Vendor Listings](assets/screenshots/06_vendor_listings.png)
![Vendor Bookings](assets/screenshots/07_vendor_bookings.png)
![Vendor Feedback](assets/screenshots/08_vendor_feedback.png)

### Admin Flow

- `09_admin_user_moderation.png`
- `10_admin_listing_moderation.png`
- `11_admin_destination_moderation.png`
- `12_admin_bookings_moderation.png`
- `13_admin_reports.png`

![Admin User Moderation](assets/screenshots/09_admin_user_moderation.png)
![Admin Listing Moderation](assets/screenshots/10_admin_listing_moderation.png)
![Admin Destination Moderation](assets/screenshots/11_admin_destination_moderation.png)
![Admin Bookings Moderation](assets/screenshots/12_admin_bookings_moderation.png)
![Admin Reports](assets/screenshots/13_admin_reports.png)

## Tech Stack

- Flutter (Material 3)
- State management: `provider`
- In-memory repositories with service layer abstraction + local snapshot persistence (`shared_preferences`)
- Firebase backend integration (opt-in via build flag):
  - `firebase/firestore.rules`
  - `firebase/firestore.indexes.json`
  - `functions/index.js` (Cloud Functions template)

## Project Structure

- `lib/domain/models.dart`: core entities and enums.
- `lib/data/`: seed data and in-memory repositories.
- `lib/services/`: auth, itinerary, booking, notification, admin services.
- `lib/state/app_state.dart`: app orchestration and role actions.
- `lib/ui/`: auth + traveler/vendor/admin screens.
- `firebase/`: Firestore security/index templates.
- `functions/`: Node Cloud Functions templates.

## Run

```bash
flutter pub get
flutter run
```

To enable Firebase runtime sync (when Firebase is configured):

```bash
flutter run --dart-define=USE_FIREBASE=true
```

Build APK (without Firebase):

```bash
flutter build apk --debug
```

Build APK (with Firebase):

```bash
flutter build apk --debug --dart-define=USE_FIREBASE=true
```

## Notes

- Current app runtime uses in-memory seeded data for deterministic demo behavior.
- App writes a local snapshot so data changes persist across restarts (bookings, reviews, inquiries, destinations, etc.).
- With `USE_FIREBASE=true`, app also subscribes to Firestore updates for cross-device sync of supported collections.
- Demo images are bundled offline under `assets/demo_images/` so image previews work without internet.
- Firebase files are provided to support transition to real backend deployment.

## Automated Testing

```bash
flutter test
flutter test integration_test/login_flow_test.dart -d linux
```
