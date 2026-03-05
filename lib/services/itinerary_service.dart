import 'dart:math';

import 'package:uuid/uuid.dart';

import '../domain/models.dart';

class ItineraryService {
  ItineraryService();

  final Uuid _uuid = const Uuid();

  ItineraryPlan generatePlan({
    required TripRequest request,
    required List<Listing> listings,
  }) {
    final destinationListings = listings
        .where(
          (listing) =>
              listing.state == request.destinationState && listing.isActive,
        )
        .toList();

    final baseline = _buildBaseline(
      request: request,
      listings: destinationListings,
    );

    if (baseline.total > request.budget) {
      final shortfall = baseline.total - request.budget;
      return ItineraryPlan(
        id: _uuid.v4(),
        request: request,
        items: const <ItineraryItem>[],
        cost: baseline,
        remainingBudget: -shortfall,
        cheaperAlternatives: _cheapestListings(destinationListings),
        upgradeAlternatives: _bestRatedListings(destinationListings),
        message:
            'Budget is below minimum feasible trip by RM${shortfall.toStringAsFixed(2)}. '
            'Try fewer days, hostel stay, or a cheaper destination.',
      );
    }

    final activityBudget =
        request.budget -
        (baseline.transport +
            baseline.accommodation +
            baseline.foodEstimate +
            baseline.fees);
    final candidates = destinationListings
        .where((listing) => listing.type != ListingType.accommodation)
        .toList();

    final scored =
        candidates
            .map(
              (listing) => _ScoredListing(
                listing: listing,
                score: _scoreListing(
                  listing: listing,
                  request: request,
                  budget: activityBudget,
                ),
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final items = _buildDayPlan(
      request: request,
      scoredListings: scored,
      activityBudget: activityBudget,
    );

    final totalActivities = items.fold<double>(
      0,
      (sum, item) => sum + item.estimatedCost,
    );
    final adjustedItems = _rebalanceIfNeeded(
      items: items,
      maxActivitiesCost: activityBudget,
      scoredListings: scored,
    );
    final adjustedActivities = adjustedItems.fold<double>(
      0,
      (sum, item) => sum + item.estimatedCost,
    );
    final finalCost = CostBreakdown(
      transport: baseline.transport,
      accommodation: baseline.accommodation,
      activities: adjustedActivities,
      foodEstimate: baseline.foodEstimate,
      fees: baseline.fees,
    );

    final remaining = request.budget - finalCost.total;
    final overloaded = totalActivities > activityBudget;

    return ItineraryPlan(
      id: _uuid.v4(),
      request: request,
      items: adjustedItems,
      cost: finalCost,
      remainingBudget: remaining,
      cheaperAlternatives: _cheapestListings(destinationListings),
      upgradeAlternatives: _bestRatedListings(destinationListings),
      message: overloaded
          ? 'Plan was rebalanced to keep total cost under budget.'
          : 'Plan generated successfully under budget.',
    );
  }

  CostBreakdown _buildBaseline({
    required TripRequest request,
    required List<Listing> listings,
  }) {
    final dayCount = request.days;
    final nights = max(dayCount - 1, 1);

    final transport = switch (request.transportMode) {
      TransportMode.bus => 45.0,
      TransportMode.train => 70.0,
      TransportMode.flight => 220.0,
      TransportMode.mixed => 120.0,
    };

    final stayFloor = switch (request.stayType) {
      StayType.hostel => 55.0,
      StayType.budgetHotel => 95.0,
      StayType.midRange => 150.0,
    };

    final accommodations =
        listings
            .where((listing) => listing.type == ListingType.accommodation)
            .toList()
          ..sort((a, b) => a.priceBase.compareTo(b.priceBase));

    final stayRate = accommodations.isEmpty
        ? stayFloor
        : max(stayFloor, accommodations.first.priceBase);

    final foodEstimate = dayCount * 35.0;
    final fees = max(12.0, request.budget * 0.03);

    return CostBreakdown(
      transport: transport,
      accommodation: stayRate * nights,
      activities: 0,
      foodEstimate: foodEstimate,
      fees: fees,
    );
  }

  double _scoreListing({
    required Listing listing,
    required TripRequest request,
    required double budget,
  }) {
    final interests = request.interests
        .map((entry) => entry.toLowerCase())
        .toSet();
    final tags = listing.tags.map((entry) => entry.toLowerCase()).toSet();

    final matchCount = tags.intersection(interests).length;
    final interestScore = matchCount * 1.7;
    final ratingScore = listing.ratingAvg * 1.3;
    final priceFit = budget <= 0
        ? 0
        : (1 - min(listing.priceBase / budget, 1)) * 2;

    final paceMultiplier = switch (request.pace) {
      Pace.relaxed => listing.type == ListingType.activity ? 0.8 : 1.0,
      Pace.balanced => 1.0,
      Pace.packed => listing.type == ListingType.activity ? 1.25 : 1.0,
    };

    final typeBoost = switch (listing.type) {
      ListingType.activity => 1.2,
      ListingType.attraction => 1.1,
      ListingType.restaurant => 0.9,
      ListingType.accommodation => 0.2,
    };

    return (interestScore + ratingScore + priceFit + typeBoost) *
        paceMultiplier;
  }

  List<ItineraryItem> _buildDayPlan({
    required TripRequest request,
    required List<_ScoredListing> scoredListings,
    required double activityBudget,
  }) {
    if (activityBudget <= 0 || scoredListings.isEmpty) {
      return const <ItineraryItem>[];
    }

    final targetItems = switch (request.pace) {
      Pace.relaxed => request.days,
      Pace.balanced => request.days * 2,
      Pace.packed => request.days * 3,
    };

    final List<ItineraryItem> plan = <ItineraryItem>[];
    var runningCost = 0.0;
    var dayIndex = 1;
    var slotCycle = 0;

    for (final candidate in scoredListings) {
      if (plan.length >= targetItems) {
        break;
      }
      if ((runningCost + candidate.listing.priceBase) > activityBudget) {
        continue;
      }

      final slot = TimeSlot.values[slotCycle % TimeSlot.values.length];
      plan.add(
        ItineraryItem(
          dayIndex: dayIndex,
          timeSlot: slot,
          listingId: candidate.listing.id,
          listingTitle: candidate.listing.title,
          estimatedCost: candidate.listing.priceBase,
          category: candidate.listing.type.name,
          notes: 'Auto-selected based on budget fit and interests.',
          score: candidate.score,
        ),
      );

      runningCost += candidate.listing.priceBase;
      slotCycle++;
      if (slotCycle % TimeSlot.values.length == 0) {
        dayIndex = min(dayIndex + 1, request.days);
      }
    }

    return plan;
  }

  List<ItineraryItem> _rebalanceIfNeeded({
    required List<ItineraryItem> items,
    required double maxActivitiesCost,
    required List<_ScoredListing> scoredListings,
  }) {
    final mutable = List<ItineraryItem>.from(items);

    double total = mutable.fold<double>(
      0,
      (sum, item) => sum + item.estimatedCost,
    );
    if (total <= maxActivitiesCost) {
      return mutable;
    }

    mutable.sort((a, b) {
      final scoreComparison = a.score.compareTo(b.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return b.estimatedCost.compareTo(a.estimatedCost);
    });

    while (total > maxActivitiesCost && mutable.isNotEmpty) {
      final removed = mutable.removeAt(0);
      total -= removed.estimatedCost;
    }

    if (total > maxActivitiesCost) {
      return const <ItineraryItem>[];
    }

    // Try filling with cheaper alternatives if there is room.
    final existingIds = mutable.map((item) => item.listingId).toSet();
    for (final candidate in scoredListings.reversed) {
      if (existingIds.contains(candidate.listing.id)) {
        continue;
      }
      if (total + candidate.listing.priceBase > maxActivitiesCost) {
        continue;
      }
      mutable.add(
        ItineraryItem(
          dayIndex: 1,
          timeSlot: TimeSlot.afternoon,
          listingId: candidate.listing.id,
          listingTitle: candidate.listing.title,
          estimatedCost: candidate.listing.priceBase,
          category: candidate.listing.type.name,
          notes: 'Added as budget-friendly replacement.',
          score: candidate.score,
        ),
      );
      total += candidate.listing.priceBase;
    }

    return mutable;
  }

  List<Listing> _cheapestListings(List<Listing> listings) {
    final sorted = List<Listing>.from(listings)
      ..sort((a, b) => a.priceBase.compareTo(b.priceBase));
    return sorted.take(3).toList();
  }

  List<Listing> _bestRatedListings(List<Listing> listings) {
    final sorted = List<Listing>.from(listings)
      ..sort((a, b) => b.ratingAvg.compareTo(a.ratingAvg));
    return sorted.take(3).toList();
  }
}

class _ScoredListing {
  const _ScoredListing({required this.listing, required this.score});

  final Listing listing;
  final double score;
}
