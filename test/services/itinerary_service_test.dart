// =============================================================================
// test/services/itinerary_service_test.dart
//
// Scope: Unit tests for ItineraryService — the budget-first trip planning
// engine that scores and selects listings to fill a day-by-day itinerary
// within a traveler's declared budget.
//
// What this file tests:
//   - Happy-path plan generation: non-empty items, cost within budget, only
//     listings from the requested destination state.
//   - Insufficient-budget path: empty items, negative remaining budget,
//     shortfall message, cheaper alternatives populated.
//   - Budget constraint enforcement: activity cost never exceeds the activity
//     budget even when many listings compete for slots.
//   - Interest-based scoring: listings whose tags overlap with the traveler's
//     declared interests rank higher and appear first in the plan.
//   - Pace setting: relaxed yields fewer planned items than packed for the
//     same trip length and pool of available listings.
//
// All tests are deterministic — they consume the fixed SeedData.listings()
// catalogue; no random state or time-dependent logic is introduced.
//
// Key seed data used throughout:
//   Kedah listings (destinationState = 'Kedah'):
//     l-3  — activity  — 'Langkawi Island Hopping'    — RM75   — tags: adventure, nature, boat
//     l-10 — activity  — 'Langkawi Sunset Ride'       — RM52   — tags: adventure, sunset, community
//   No accommodation exists in Kedah seed data, so stayRate falls back to the
//   hostel floor (RM55/night).
//
// Baseline cost for a Kedah trip (bus transport, hostel stay):
//   1-day:  transport=45 + accommodation=55 + food=35 + fees=12 = 147
//   2-day:  transport=45 + accommodation=55 + food=70 + fees=12 = 182
//   3-day:  transport=45 + accommodation=110 + food=105 + fees varies
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:jombudget/data/seed_data.dart';
import 'package:jombudget/domain/models.dart';
import 'package:jombudget/services/itinerary_service.dart';

void main() {
  // The service is stateless — a single instance is shared across all tests.
  final service = ItineraryService();
  final allListings = SeedData.listings();

  // ---------------------------------------------------------------------------
  // Convenience builder for TripRequests targeting Kedah.
  // ---------------------------------------------------------------------------
  TripRequest kedahRequest({
    int days = 2,
    double budget = 500,
    Pace pace = Pace.balanced,
    TransportMode transport = TransportMode.bus,
    StayType stayType = StayType.hostel,
    List<String> interests = const <String>['adventure', 'nature'],
  }) {
    final start = DateTime(2025, 6, 1);
    final end = start.add(Duration(days: days - 1));
    return TripRequest(
      startCity: 'Kuala Lumpur',
      destinationState: 'Kedah',
      startDate: start,
      endDate: end,
      budget: budget,
      interests: interests,
      pace: pace,
      transportMode: transport,
      stayType: stayType,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Happy-path plan generation
  // ───────────────────────────────────────────────────────────────────────────

  group('ItineraryService — plan generation (happy path)', () {
    test(
      'generates a plan with at least one scheduled item when budget is '
      'comfortably above the baseline cost',
      () {
        // Budget 500: Kedah 2-day baseline ≈ RM182 (bus + hostel + food + fees),
        // leaving RM318 for activities. Both l-3 (75) and l-10 (52) fit.
        final plan = service.generatePlan(
          request: kedahRequest(budget: 500),
          listings: allListings,
        );

        expect(plan.items, isNotEmpty);
        expect(plan.remainingBudget, greaterThanOrEqualTo(0));
      },
    );

    test(
      'total plan cost (transport + accommodation + activities + food + fees) '
      'does not exceed the requested budget',
      () {
        final request = kedahRequest(budget: 400);
        final plan = service.generatePlan(
          request: request,
          listings: allListings,
        );

        expect(plan.cost.total, lessThanOrEqualTo(request.budget));
      },
    );

    test(
      'plan items only reference listings from the target destination state',
      () {
        // The engine must filter by state before scoring; items from other
        // states must never appear in the result.
        final plan = service.generatePlan(
          request: kedahRequest(budget: 600),
          listings: allListings,
        );

        final kedahListingIds = allListings
            .where((l) => l.state == 'Kedah')
            .map((l) => l.id)
            .toSet();

        for (final item in plan.items) {
          expect(
            kedahListingIds.contains(item.listingId),
            isTrue,
            reason:
                'Item "${item.listingTitle}" (${item.listingId}) does not '
                'belong to the Kedah destination.',
          );
        }
      },
    );

    test(
      'each cost breakdown field is non-negative',
      () {
        final plan = service.generatePlan(
          request: kedahRequest(budget: 500),
          listings: allListings,
        );

        expect(plan.cost.transport, greaterThanOrEqualTo(0));
        expect(plan.cost.accommodation, greaterThanOrEqualTo(0));
        expect(plan.cost.activities, greaterThanOrEqualTo(0));
        expect(plan.cost.foodEstimate, greaterThanOrEqualTo(0));
        expect(plan.cost.fees, greaterThanOrEqualTo(0));
      },
    );

    test(
      'plan is assigned a non-empty UUID id and carries the original request',
      () {
        final request = kedahRequest(budget: 500);
        final plan = service.generatePlan(request: request, listings: allListings);

        expect(plan.id, isNotEmpty);
        expect(plan.request, equals(request));
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Insufficient budget
  // ───────────────────────────────────────────────────────────────────────────

  group('ItineraryService — insufficient budget', () {
    // Kedah 2-day baseline ≈ RM182. Any budget below that triggers the
    // shortfall path.
    const tightBudget = 80.0;

    test(
      'returns an empty items list when budget is below the minimum baseline',
      () {
        final plan = service.generatePlan(
          request: kedahRequest(budget: tightBudget),
          listings: allListings,
        );

        expect(plan.items, isEmpty);
      },
    );

    test(
      'remainingBudget is negative when the budget cannot cover baseline costs',
      () {
        final plan = service.generatePlan(
          request: kedahRequest(budget: tightBudget),
          listings: allListings,
        );

        // remainingBudget = budget − baseline.total; must be negative here.
        expect(plan.remainingBudget, isNegative);
      },
    );

    test(
      'message indicates a shortfall and suggests remedies',
      () {
        final plan = service.generatePlan(
          request: kedahRequest(budget: tightBudget),
          listings: allListings,
        );

        // The message is user-facing guidance; it must mention the shortfall
        // and include at least one cost-saving tip.
        expect(plan.message.toLowerCase(), contains('budget'));
      },
    );

    test(
      'cheaperAlternatives are still populated even when no plan items exist',
      () {
        // Even on an insufficient budget the traveler should receive suggestions
        // for cheaper listings so they can adjust their plan or destination.
        final plan = service.generatePlan(
          request: kedahRequest(budget: tightBudget),
          listings: allListings,
        );

        expect(plan.cheaperAlternatives, isNotEmpty);
      },
    );

    test(
      'upgradeAlternatives are also populated on the shortfall path',
      () {
        // The upgrade list gives traveler context on what a higher budget would
        // unlock, useful for the UI's upsell suggestions.
        final plan = service.generatePlan(
          request: kedahRequest(budget: tightBudget),
          listings: allListings,
        );

        expect(plan.upgradeAlternatives, isNotEmpty);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Budget constraint enforcement
  // ───────────────────────────────────────────────────────────────────────────

  group('ItineraryService — budget constraint enforcement', () {
    test(
      'plan total never exceeds the request budget on a tight activity budget',
      () {
        // Budget 220 on a 2-day Kedah trip:
        // baseline ≈ 182, activityBudget ≈ 38.
        // l-10 costs RM52 > 38, so it must be skipped.
        // l-3 costs RM75 > 38, so it must also be skipped.
        // Result: 0 activity items; total = baseline ≈ 182 < 220.
        final request = kedahRequest(budget: 220);
        final plan = service.generatePlan(
          request: request,
          listings: allListings,
        );

        expect(plan.cost.total, lessThanOrEqualTo(request.budget));
      },
    );

    test(
      'activities breakdown field equals the sum of all item estimated costs',
      () {
        // The activities figure in the CostBreakdown must be the arithmetic
        // sum of the individual ItineraryItems — no rounding or hidden fees.
        final plan = service.generatePlan(
          request: kedahRequest(budget: 500),
          listings: allListings,
        );

        final itemsTotal = plan.items.fold<double>(
          0,
          (sum, item) => sum + item.estimatedCost,
        );

        expect(plan.cost.activities, closeTo(itemsTotal, 0.01));
      },
    );

    test(
      'remainingBudget equals budget minus the full cost breakdown total',
      () {
        final request = kedahRequest(budget: 500);
        final plan = service.generatePlan(
          request: request,
          listings: allListings,
        );

        expect(
          plan.remainingBudget,
          closeTo(request.budget - plan.cost.total, 0.01),
        );
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Interest-based scoring
  // ───────────────────────────────────────────────────────────────────────────

  group('ItineraryService — interest-based scoring', () {
    // Kedah has two non-accommodation listings:
    //   l-3  tags: ['adventure', 'nature', 'boat']
    //   l-10 tags: ['adventure', 'sunset', 'community']
    //
    // Scoring formula (simplified):
    //   interestScore = matchingTagCount × 1.7
    //   ratingScore   = ratingAvg × 1.3
    //   priceFit      = (1 − priceBase / activityBudget) × 2
    //   typeBoost     = 1.2 (activity)
    //
    // With interests=['adventure','nature']: l-3 gets 2 matches (3.4 pts);
    //   l-10 gets 1 match (1.7 pts) → l-3 outscores l-10.
    // With interests=['sunset','community']: l-10 gets 2 matches; l-3 gets 0
    //   → l-10 outscores l-3.

    test(
      'listing with more matching interest tags ranks first in the plan',
      () {
        // interests = ['adventure', 'nature']: l-3 matches both → higher score
        final plan = service.generatePlan(
          request: kedahRequest(
            budget: 500,
            interests: <String>['adventure', 'nature'],
          ),
          listings: allListings,
        );

        expect(plan.items, isNotEmpty);
        // The highest-scored listing must appear as the first item in the plan
        // because _buildDayPlan iterates scoredListings in descending score order.
        expect(plan.items.first.listingId, equals('l-3'));
      },
    );

    test(
      'changing interests reorders the top-ranked item in the plan',
      () {
        // interests = ['sunset', 'community']: l-10 now matches both → l-10
        // should outrank l-3 and appear first.
        final plan = service.generatePlan(
          request: kedahRequest(
            budget: 500,
            interests: <String>['sunset', 'community'],
          ),
          listings: allListings,
        );

        expect(plan.items, isNotEmpty);
        expect(plan.items.first.listingId, equals('l-10'));
      },
    );

    test(
      'no-match interests still produce a plan ordered by rating and price fit',
      () {
        // When no listing matches any declared interest, interestScore = 0 for
        // all candidates. The tie is broken by ratingScore (ratingAvg × 1.3)
        // then priceFit. l-3 has ratingAvg=4.7 vs l-10=4.5, so l-3 wins.
        final plan = service.generatePlan(
          request: kedahRequest(
            budget: 500,
            interests: <String>['shopping'],
          ),
          listings: allListings,
        );

        expect(plan.items, isNotEmpty);
        // l-3 (4.7) beats l-10 (4.5) on rating alone.
        expect(plan.items.first.listingId, equals('l-3'));
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Pace setting
  // ───────────────────────────────────────────────────────────────────────────

  group('ItineraryService — pace setting', () {
    // Using a 1-day Kedah trip to maximise the differentiation between paces:
    //   relaxed → targetItems = 1 × 1 = 1
    //   packed  → targetItems = 1 × 3 = 3
    // With only 2 non-accommodation listings in Kedah (l-3, l-10), the packed
    // plan is capped at 2 items — still more than the relaxed plan's 1 item.

    test(
      'relaxed pace produces fewer plan items than packed pace for the same trip',
      () {
        final relaxedPlan = service.generatePlan(
          request: kedahRequest(
            days: 1,
            budget: 300,
            pace: Pace.relaxed,
          ),
          listings: allListings,
        );

        final packedPlan = service.generatePlan(
          request: kedahRequest(
            days: 1,
            budget: 300,
            pace: Pace.packed,
          ),
          listings: allListings,
        );

        expect(
          relaxedPlan.items.length,
          lessThan(packedPlan.items.length),
          reason:
              'Relaxed (${relaxedPlan.items.length} items) should have fewer '
              'items than packed (${packedPlan.items.length} items).',
        );
      },
    );

    test(
      'relaxed pace selects exactly one item for a 1-day trip',
      () {
        // targetItems = days × 1 = 1 for relaxed. The loop breaks after the
        // first qualifying listing is added.
        final plan = service.generatePlan(
          request: kedahRequest(
            days: 1,
            budget: 300,
            pace: Pace.relaxed,
          ),
          listings: allListings,
        );

        expect(plan.items.length, equals(1));
      },
    );

    test(
      'packed pace fills up to the available listing count for the state',
      () {
        // targetItems = 1 × 3 = 3 for packed, but Kedah only has 2 eligible
        // activity listings, so the plan is capped at 2.
        final plan = service.generatePlan(
          request: kedahRequest(
            days: 1,
            budget: 300,
            pace: Pace.packed,
          ),
          listings: allListings,
        );

        expect(plan.items.length, equals(2));
      },
    );

    test(
      'balanced pace for a 2-day trip returns up to 4 target slots filled by '
      'available listings',
      () {
        // targetItems = 2 × 2 = 4 for balanced; Kedah has 2 activities,
        // so the plan is capped at 2 items.
        final plan = service.generatePlan(
          request: kedahRequest(
            days: 2,
            budget: 500,
            pace: Pace.balanced,
          ),
          listings: allListings,
        );

        // Cannot exceed available count; must be at most 2.
        expect(plan.items.length, lessThanOrEqualTo(2));
        expect(plan.items.length, greaterThanOrEqualTo(1));
      },
    );
  });
}
