import 'package:intl/intl.dart';

import 'domain/models.dart';

String formatMoney(double value) => 'RM${value.toStringAsFixed(2)}';

String formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);

String userRoleLabel(UserRole role) {
  switch (role) {
    case UserRole.traveler:
      return 'Traveler';
    case UserRole.vendor:
      return 'Vendor';
    case UserRole.admin:
      return 'Admin';
  }
}

String listingTypeLabel(ListingType type) {
  switch (type) {
    case ListingType.accommodation:
      return 'Accommodation';
    case ListingType.activity:
      return 'Activity';
    case ListingType.restaurant:
      return 'Restaurant';
    case ListingType.attraction:
      return 'Attraction';
  }
}

String bookingStatusLabel(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return 'Pending Vendor Approval';
    case BookingStatus.confirmed:
      return 'Confirmed';
    case BookingStatus.rejected:
      return 'Rejected';
    case BookingStatus.cancelRequested:
      return 'Cancel Requested';
    case BookingStatus.cancelled:
      return 'Cancelled';
    case BookingStatus.completed:
      return 'Completed';
  }
}

String timeSlotLabel(TimeSlot slot) {
  switch (slot) {
    case TimeSlot.morning:
      return 'Morning';
    case TimeSlot.afternoon:
      return 'Afternoon';
    case TimeSlot.evening:
      return 'Evening';
  }
}

String paceLabel(Pace pace) {
  switch (pace) {
    case Pace.relaxed:
      return 'Relaxed';
    case Pace.balanced:
      return 'Balanced';
    case Pace.packed:
      return 'Packed';
  }
}

String transportModeLabel(TransportMode mode) {
  switch (mode) {
    case TransportMode.bus:
      return 'Bus';
    case TransportMode.train:
      return 'Train';
    case TransportMode.flight:
      return 'Flight';
    case TransportMode.mixed:
      return 'Mixed';
  }
}

String stayTypeLabel(StayType stayType) {
  switch (stayType) {
    case StayType.hostel:
      return 'Hostel';
    case StayType.budgetHotel:
      return 'Budget Hotel';
    case StayType.midRange:
      return 'Mid-range Hotel';
  }
}
