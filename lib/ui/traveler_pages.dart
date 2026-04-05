import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core_utils.dart';
import '../data/seed_data.dart';
import '../domain/models.dart';
import '../state/app_state.dart';
import 'receipt_dialog.dart';

class TravelerHomeScreen extends StatefulWidget {
  const TravelerHomeScreen({super.key});

  @override
  State<TravelerHomeScreen> createState() => _TravelerHomeScreenState();
}

class _TravelerHomeScreenState extends State<TravelerHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      _TravelerBrowsePage(),
      _TravelerPlannerPage(),
      _TravelerBookingsPage(),
      _NotificationsPage(),
      _ProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Traveler Dashboard')),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.travel_explore),
            label: 'Browse',
          ),
          NavigationDestination(icon: Icon(Icons.route), label: 'Planner'),
          NavigationDestination(
            icon: Icon(Icons.book_online),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}

class _TravelerBrowsePage extends StatefulWidget {
  const _TravelerBrowsePage();

  @override
  State<_TravelerBrowsePage> createState() => _TravelerBrowsePageState();
}

class _TravelerBrowsePageState extends State<_TravelerBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  String? _state;
  ListingType? _type;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bookListing(BuildContext context, Listing listing) async {
    final blockedWindows = context.read<AppState>().availabilityForListing(
      listing.id,
    );
    DateTime startDate = DateTime.now().add(const Duration(days: 3));
    DateTime endDate = DateTime.now().add(const Duration(days: 4));
    int pax = 1;
    String paymentMethod = 'Card';

    final shouldBook = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final hasBlackoutConflict = blockedWindows.any(
              (window) => _datesOverlap(
                startDate,
                endDate,
                window.startDate,
                window.endDate,
              ),
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Book ${listing.title}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final selected = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              initialDate: startDate,
                            );
                            if (selected == null) {
                              return;
                            }
                            setModalState(() {
                              startDate = selected;
                              if (endDate.isBefore(startDate)) {
                                endDate = startDate.add(
                                  const Duration(days: 1),
                                );
                              }
                            });
                          },
                          child: Text('Start: ${formatDate(startDate)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final selected = await showDatePicker(
                              context: context,
                              firstDate: startDate,
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              initialDate: endDate,
                            );
                            if (selected == null) {
                              return;
                            }
                            setModalState(() => endDate = selected);
                          },
                          child: Text('End: ${formatDate(endDate)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      const Text('Pax'),
                      Expanded(
                        child: Slider(
                          min: 1,
                          max: 6,
                          divisions: 5,
                          value: pax.toDouble(),
                          label: '$pax',
                          onChanged: (value) =>
                              setModalState(() => pax = value.round()),
                        ),
                      ),
                      Text('$pax'),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                    ),
                    items: const <String>['Card', 'E-Wallet', 'Online Banking']
                        .map(
                          (method) => DropdownMenuItem<String>(
                            value: method,
                            child: Text(method),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setModalState(() => paymentMethod = value);
                    },
                  ),
                  if (blockedWindows.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Vendor blackout windows',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...blockedWindows
                        .take(3)
                        .map(
                          (window) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${formatDate(window.startDate)} - ${formatDate(window.endDate)} (${window.reason})',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                    if (blockedWindows.length > 3)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '+ ${blockedWindows.length - 3} more',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                  ],
                  if (hasBlackoutConflict) ...<Widget>[
                    const SizedBox(height: 8),
                    const Text(
                      'Selected dates overlap a blackout window. Please change dates.',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: hasBlackoutConflict
                        ? null
                        : () => Navigator.of(context).pop(true),
                    child: const Text('Confirm Mock Checkout'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (shouldBook != true || !context.mounted) {
      return;
    }

    final appState = context.read<AppState>();
    final booking = appState.createBooking(
      listingId: listing.id,
      startDate: startDate,
      endDate: endDate,
      pax: pax,
      paymentMethod: paymentMethod,
    );

    if (booking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appState.lastError ?? 'Unable to create booking.'),
        ),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    await showReceiptDialog(context, booking);
  }

  Future<bool> _askQuestion(BuildContext context, Listing listing) async {
    final questionController = TextEditingController();
    bool isPublic = true;

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Ask about ${listing.title}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: questionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Your question',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Public question'),
                    subtitle: const Text('Visible to other travelers'),
                    value: isPublic,
                    onChanged: (value) =>
                        setDialogState(() => isPublic = value),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSubmit != true || !context.mounted) {
      questionController.dispose();
      return false;
    }

    final success = context.read<AppState>().submitInquiry(
      listingId: listing.id,
      question: questionController.text,
      isPublic: isPublic,
    );
    final message = success
        ? 'Question submitted.'
        : (context.read<AppState>().lastError ?? 'Unable to submit question.');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    questionController.dispose();
    return success;
  }

  Future<void> _openReviewsDialog(BuildContext context, Listing listing) async {
    final reviews =
        context.read<AppState>().reviewsForListing(listing.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Reviews - ${listing.title}'),
          content: SizedBox(
            width: 360,
            height: 340,
            child: reviews.isEmpty
                ? const Center(child: Text('No reviews yet.'))
                : ListView.separated(
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${review.rating}/5 - ${review.comment}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Posted: ${formatDate(review.createdAt)}'),
                            if (review.vendorReply != null &&
                                review.vendorReply!.trim().isNotEmpty)
                              Text('Vendor reply: ${review.vendorReply}'),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openInquiryDialog(BuildContext context, Listing listing) async {
    final inquiries =
        context.read<AppState>().inquiriesForListing(listing.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Q&A - ${listing.title}'),
          content: SizedBox(
            width: 360,
            height: 340,
            child: inquiries.isEmpty
                ? const Center(
                    child: Text('No public questions yet for this listing.'),
                  )
                : ListView.separated(
                    itemCount: inquiries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final inquiry = inquiries[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Q: ${inquiry.question}'),
                        subtitle: Text(
                          inquiry.isAnswered
                              ? 'A: ${inquiry.answer}'
                              : 'A: Pending vendor response',
                        ),
                      );
                    },
                  ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final submitted = await _askQuestion(context, listing);
                if (submitted && context.mounted) {
                  await _openInquiryDialog(context, listing);
                }
              },
              child: const Text('Ask Question'),
            ),
          ],
        );
      },
    );
  }

  Uint8List? _bytesFromDataUri(String? source) {
    if (source == null || !source.startsWith('data:image')) {
      return null;
    }
    final commaIndex = source.indexOf(',');
    if (commaIndex == -1) {
      return null;
    }
    final encoded = source.substring(commaIndex + 1);
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  bool _datesOverlap(
    DateTime startA,
    DateTime endA,
    DateTime startB,
    DateTime endB,
  ) {
    return !endA.isBefore(startB) && !startA.isAfter(endB);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final listings = appState.browseListings(
      query: _searchController.text,
      state: _state,
      type: _type,
    );

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search listing, tag, or description',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _state,
                      decoration: const InputDecoration(labelText: 'State'),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All States'),
                        ),
                        ...SeedData.malaysiaStates.map(
                          (entry) => DropdownMenuItem<String?>(
                            value: entry,
                            child: Text(entry),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _state = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<ListingType?>(
                      value: _type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: <DropdownMenuItem<ListingType?>>[
                        const DropdownMenuItem<ListingType?>(
                          value: null,
                          child: Text('All Types'),
                        ),
                        ...ListingType.values.map(
                          (entry) => DropdownMenuItem<ListingType?>(
                            value: entry,
                            child: Text(listingTypeLabel(entry)),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _type = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: listings.isEmpty
              ? const Center(child: Text('No listings match your filters.'))
              : ListView.builder(
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    final reviews = appState.reviewsForListing(listing.id);
                    final inquiries = appState.inquiriesForListing(listing.id);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (listing.imageUrls.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _buildListingImage(
                                  listing.imageUrls.first,
                                ),
                              ),
                            if (listing.imageUrls.isNotEmpty)
                              const SizedBox(height: 8),
                            Text(
                              listing.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text('${listing.location}, ${listing.state}'),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              children: listing.tags
                                  .take(4)
                                  .map((tag) => Chip(label: Text(tag)))
                                  .toList(),
                            ),
                            const SizedBox(height: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(formatMoney(listing.priceBase)),
                                    const SizedBox(width: 10),
                                    Icon(
                                      Icons.star,
                                      size: 18,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(listing.ratingAvg.toStringAsFixed(1)),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          _openReviewsDialog(context, listing),
                                      child: Text('Reviews (${reviews.length})'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _openInquiryDialog(context, listing),
                                      child: Text('Q&A (${inquiries.length})'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          _bookListing(context, listing),
                                      child: const Text('Book'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildListingImage(String source) {
    final dataBytes = _bytesFromDataUri(source);
    if (dataBytes != null) {
      return Image.memory(
        dataBytes,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 150,
          width: double.infinity,
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Text('Image not available'),
        ),
      );
    }
    return Image.network(
      source,
      height: 150,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 150,
        width: double.infinity,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Text('Image not available'),
      ),
    );
  }
}

class _TravelerPlannerPage extends StatefulWidget {
  const _TravelerPlannerPage();

  @override
  State<_TravelerPlannerPage> createState() => _TravelerPlannerPageState();
}

class _TravelerPlannerPageState extends State<_TravelerPlannerPage> {
  final TextEditingController _startCityController = TextEditingController(
    text: 'Kuala Lumpur',
  );
  final TextEditingController _budgetController = TextEditingController(
    text: '450',
  );

  String _destination = 'Penang';
  String? _selectedDestinationId;
  DateTime _startDate = DateTime.now().add(const Duration(days: 14));
  DateTime _endDate = DateTime.now().add(const Duration(days: 16));
  Pace _pace = Pace.balanced;
  TransportMode _transport = TransportMode.mixed;
  StayType _stayType = StayType.hostel;
  final Set<String> _interests = <String>{'food', 'culture', 'nature'};

  static const List<String> _allInterests = <String>[
    'food',
    'nature',
    'culture',
    'history',
    'shopping',
    'adventure',
    'night-life',
    'community',
  ];
  static const List<_PlannerPreset> _presets = <_PlannerPreset>[
    _PlannerPreset(
      title: 'Budget Saver',
      icon: Icons.savings_outlined,
      defaultBudget: 320,
      pace: Pace.relaxed,
      transport: TransportMode.bus,
      stayType: StayType.hostel,
      interests: <String>['food', 'culture'],
    ),
    _PlannerPreset(
      title: 'Balanced',
      icon: Icons.balance_outlined,
      defaultBudget: 500,
      pace: Pace.balanced,
      transport: TransportMode.mixed,
      stayType: StayType.budgetHotel,
      interests: <String>['food', 'culture', 'nature'],
    ),
    _PlannerPreset(
      title: 'Adventure',
      icon: Icons.hiking_outlined,
      defaultBudget: 620,
      pace: Pace.packed,
      transport: TransportMode.mixed,
      stayType: StayType.hostel,
      interests: <String>['adventure', 'nature', 'community'],
    ),
    _PlannerPreset(
      title: 'Food Trail',
      icon: Icons.ramen_dining_outlined,
      defaultBudget: 460,
      pace: Pace.balanced,
      transport: TransportMode.train,
      stayType: StayType.hostel,
      interests: <String>['food', 'culture', 'night-life'],
    ),
  ];

  @override
  void dispose() {
    _startCityController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _generate() {
    final budget = double.tryParse(_budgetController.text) ?? 0;
    final appState = context.read<AppState>();

    final request = TripRequest(
      startCity: _startCityController.text,
      destinationState: _destination,
      startDate: _startDate,
      endDate: _endDate,
      budget: budget,
      interests: _interests.toList(),
      pace: _pace,
      transportMode: _transport,
      stayType: _stayType,
    );

    appState.generateItinerary(request);
  }

  void _applyPreset(_PlannerPreset preset) {
    _budgetController.text = preset.defaultBudget.toStringAsFixed(0);
    _pace = preset.pace;
    _transport = preset.transport;
    _stayType = preset.stayType;
    _interests
      ..clear()
      ..addAll(preset.interests);
  }

  void _applyPlanTemplate(ItineraryPlan plan) {
    _startCityController.text = plan.request.startCity;
    _budgetController.text = plan.request.budget.toStringAsFixed(0);
    _destination = plan.request.destinationState;
    _startDate = plan.request.startDate;
    _endDate = plan.request.endDate;
    _pace = plan.request.pace;
    _transport = plan.request.transportMode;
    _stayType = plan.request.stayType;
    _interests
      ..clear()
      ..addAll(plan.request.interests);
  }

  String _budgetHint({
    required Destination? destination,
    required double budget,
    required int days,
  }) {
    if (destination == null) {
      return 'Set a budget and generate plan. The optimizer will rebalance activities to stay within it.';
    }
    final recommendedDays = destination.recommendedDays < 1
        ? 1
        : destination.recommendedDays;
    final scale = days / recommendedDays;
    final low = destination.budgetLow * scale;
    final high = destination.budgetHigh * scale;
    if (budget < low) {
      return 'Your budget is below the typical range (${formatMoney(low)} to ${formatMoney(high)}). Consider fewer days or hostel mode.';
    }
    if (budget > high) {
      return 'Your budget is above the typical range (${formatMoney(low)} to ${formatMoney(high)}). You should get more upgrade options.';
    }
    return 'Your budget is inside the typical range (${formatMoney(low)} to ${formatMoney(high)}) for this trip length.';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final plan = appState.lastGeneratedPlan;
    final history = appState.itineraryHistory();
    final destinations = appState.allDestinations(activeOnly: true);
    final destinationStates =
        destinations.map((destination) => destination.state).toSet().toList()
          ..sort();
    final plannerStates = destinationStates.isEmpty
        ? SeedData.malaysiaStates
        : destinationStates;
    if (!plannerStates.contains(_destination) && plannerStates.isNotEmpty) {
      _destination = plannerStates.first;
    }
    final suggestedForState = destinations
        .where((destination) => destination.state == _destination)
        .toList();
    if (suggestedForState.isNotEmpty &&
        !suggestedForState.any(
          (destination) => destination.id == _selectedDestinationId,
        )) {
      _selectedDestinationId = suggestedForState.first.id;
    }
    final selectedDestination = suggestedForState.isEmpty
        ? null
        : suggestedForState.firstWhere(
            (destination) => destination.id == _selectedDestinationId,
            orElse: () => suggestedForState.first,
          );
    final budget = double.tryParse(_budgetController.text) ?? 0;
    final tripDays = _endDate.difference(_startDate).inDays + 1;
    final safeTripDays = tripDays < 1 ? 1 : tripDays;
    final recentTemplates = List<ItineraryPlan>.from(history)
      ..sort((a, b) => b.request.startDate.compareTo(a.request.startDate));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        const Text(
          'Budget-first Itinerary Optimizer',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const Text('Quick presets'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _presets
              .map(
                (preset) => ActionChip(
                  avatar: Icon(preset.icon, size: 18),
                  label: Text(preset.title),
                  onPressed: () => setState(() => _applyPreset(preset)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _startCityController,
          decoration: const InputDecoration(labelText: 'Start city'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _destination,
          decoration: const InputDecoration(labelText: 'Destination state'),
          items: plannerStates
              .map(
                (entry) =>
                    DropdownMenuItem<String>(value: entry, child: Text(entry)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _destination = value;
              _selectedDestinationId = null;
            });
          },
        ),
        if (suggestedForState.length > 1) ...<Widget>[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedDestinationId,
            decoration: const InputDecoration(
              labelText: 'Preferred destination spot',
            ),
            items: suggestedForState
                .map(
                  (destination) => DropdownMenuItem<String>(
                    value: destination.id,
                    child: Text(destination.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedDestinationId = value);
            },
          ),
        ],
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: selectedDestination == null
                ? const Text(
                    'No curated destination insights available for this state yet.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        selectedDestination.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(selectedDestination.description),
                      const SizedBox(height: 8),
                      Text(
                        'Typical budget: ${formatMoney(selectedDestination.budgetLow)} - ${formatMoney(selectedDestination.budgetHigh)}',
                      ),
                      Text(
                        'Recommended duration: ${selectedDestination.recommendedDays} days',
                      ),
                      if (selectedDestination
                          .highlights
                          .isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: selectedDestination.highlights
                              .map(
                                (highlight) => Chip(
                                  label: Text(highlight),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          final suggestedBudget =
                              (selectedDestination.budgetLow +
                                  selectedDestination.budgetHigh) /
                              2;
                          setState(() {
                            _budgetController.text = suggestedBudget
                                .toStringAsFixed(0);
                          });
                        },
                        icon: const Icon(Icons.tune),
                        label: const Text('Use suggested budget'),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _budgetHint(
                destination: selectedDestination,
                budget: budget,
                days: safeTripDays,
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (recentTemplates.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          const Text(
            'Reuse from recent plans',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ...recentTemplates
              .take(3)
              .map(
                (entry) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(
                      '${entry.request.destinationState} • ${formatMoney(entry.request.budget)}',
                    ),
                    subtitle: Text(
                      '${formatDate(entry.request.startDate)} - ${formatDate(entry.request.endDate)}',
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          setState(() => _applyPlanTemplate(entry)),
                      child: const Text('Reuse'),
                    ),
                  ),
                ),
              ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _budgetController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Budget (RM)'),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: _startDate,
                  );
                  if (date == null) {
                    return;
                  }
                  setState(() {
                    _startDate = date;
                    if (_endDate.isBefore(_startDate)) {
                      _endDate = _startDate.add(const Duration(days: 1));
                    }
                  });
                },
                child: Text('Start: ${formatDate(_startDate)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: _startDate,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: _endDate,
                  );
                  if (date == null) {
                    return;
                  }
                  setState(() => _endDate = date);
                },
                child: Text('End: ${formatDate(_endDate)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<Pace>(
                value: _pace,
                decoration: const InputDecoration(labelText: 'Pace'),
                items: Pace.values
                    .map(
                      (value) => DropdownMenuItem<Pace>(
                        value: value,
                        child: Text(paceLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _pace = value ?? Pace.balanced),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<TransportMode>(
                value: _transport,
                decoration: const InputDecoration(labelText: 'Transport'),
                items: TransportMode.values
                    .map(
                      (value) => DropdownMenuItem<TransportMode>(
                        value: value,
                        child: Text(transportModeLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _transport = value ?? TransportMode.mixed),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<StayType>(
          value: _stayType,
          decoration: const InputDecoration(labelText: 'Stay type'),
          items: StayType.values
              .map(
                (value) => DropdownMenuItem<StayType>(
                  value: value,
                  child: Text(stayTypeLabel(value)),
                ),
              )
              .toList(),
          onChanged: (value) =>
              setState(() => _stayType = value ?? StayType.hostel),
        ),
        const SizedBox(height: 10),
        const Text('Interests'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: _allInterests
              .map(
                (entry) => FilterChip(
                  selected: _interests.contains(entry),
                  label: Text(entry),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _interests.add(entry);
                      } else {
                        _interests.remove(entry);
                      }
                    });
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: _generate, child: const Text('Generate Plan')),
        const SizedBox(height: 14),
        if (plan != null) _PlanResultCard(plan: plan),
      ],
    );
  }
}

class _PlannerPreset {
  const _PlannerPreset({
    required this.title,
    required this.icon,
    required this.defaultBudget,
    required this.pace,
    required this.transport,
    required this.stayType,
    required this.interests,
  });

  final String title;
  final IconData icon;
  final double defaultBudget;
  final Pace pace;
  final TransportMode transport;
  final StayType stayType;
  final List<String> interests;
}

class _PlanResultCard extends StatelessWidget {
  const _PlanResultCard({required this.plan});

  final ItineraryPlan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Result: ${plan.message}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text('Transport: ${formatMoney(plan.cost.transport)}'),
            Text('Accommodation: ${formatMoney(plan.cost.accommodation)}'),
            Text('Activities: ${formatMoney(plan.cost.activities)}'),
            Text('Food estimate: ${formatMoney(plan.cost.foodEstimate)}'),
            Text('Fees: ${formatMoney(plan.cost.fees)}'),
            const Divider(),
            Text('Total: ${formatMoney(plan.cost.total)}'),
            Text('Remaining: ${formatMoney(plan.remainingBudget)}'),
            const SizedBox(height: 10),
            Text('Planned items (${plan.items.length})'),
            const SizedBox(height: 4),
            if (plan.items.isEmpty)
              const Text(
                'No activities selected due to budget or data constraints.',
              ),
            ...plan.items.map(
              (item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${item.dayIndex}')),
                title: Text(
                  '${timeSlotLabel(item.timeSlot)} - ${item.listingTitle}',
                ),
                subtitle: Text(
                  '${formatMoney(item.estimatedCost)} • ${item.notes}',
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (plan.cheaperAlternatives.isNotEmpty) ...<Widget>[
              const Text('Cheaper alternatives'),
              Wrap(
                spacing: 6,
                children: plan.cheaperAlternatives
                    .map(
                      (listing) => Chip(
                        label: Text(
                          '${listing.title} (${formatMoney(listing.priceBase)})',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (plan.upgradeAlternatives.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              const Text('Upgrade picks'),
              Wrap(
                spacing: 6,
                children: plan.upgradeAlternatives
                    .map(
                      (listing) => Chip(
                        label: Text(
                          '${listing.title} (${listing.ratingAvg.toStringAsFixed(1)}★)',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TravelerBookingsPage extends StatelessWidget {
  const _TravelerBookingsPage();

  Future<void> _showReviewDialog(BuildContext context, String bookingId) async {
    final commentController = TextEditingController();
    int rating = 4;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Leave Review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<int>(
                    value: rating,
                    items: List<int>.generate(5, (index) => index + 1)
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value / 5'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() => rating = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Comment'),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true || !context.mounted) {
      commentController.dispose();
      return;
    }

    context.read<AppState>().submitReview(
      bookingId: bookingId,
      rating: rating,
      comment: commentController.text.trim().isEmpty
          ? 'Auto-generated review: satisfied experience.'
          : commentController.text.trim(),
    );

    commentController.dispose();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Review submitted.')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bookings = appState.currentUserBookings();

    return bookings.isEmpty
        ? const Center(child: Text('No bookings yet.'))
        : ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final canRequestCancel =
                  booking.status == BookingStatus.pending ||
                  booking.status == BookingStatus.confirmed;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        booking.listingTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${formatDate(booking.startDate)} - ${formatDate(booking.endDate)} • ${booking.pax} pax',
                      ),
                      Text('Amount: ${formatMoney(booking.totalAmount)}'),
                      Text('Status: ${bookingStatusLabel(booking.status)}'),
                      Text(
                        'Payment: ${booking.paymentStatus.name.toUpperCase()}',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () =>
                                showReceiptDialog(context, booking),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('Receipt'),
                          ),
                          if (canRequestCancel)
                            OutlinedButton(
                              onPressed: () {
                                final success = appState.requestCancellation(
                                  booking.id,
                                );
                                final message = success
                                    ? 'Cancellation requested.'
                                    : (appState.lastError ??
                                          'Cancellation failed');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              },
                              child: const Text('Request Cancel'),
                            ),
                          if (booking.status == BookingStatus.confirmed)
                            OutlinedButton(
                              onPressed: () =>
                                  appState.markBookingCompleted(booking.id),
                              child: const Text('Mark Completed'),
                            ),
                          if (booking.status == BookingStatus.completed)
                            FilledButton(
                              onPressed: () =>
                                  _showReviewDialog(context, booking.id),
                              child: const Text('Leave Review'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final notifications = state.notificationsForCurrentUser();

    return notifications.isEmpty
        ? const Center(child: Text('No notifications yet.'))
        : ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final item = notifications[index];
              return ListTile(
                leading: Icon(
                  item.isRead ? Icons.mark_email_read : Icons.mark_email_unread,
                ),
                title: Text(item.title),
                subtitle: Text('${item.body}\n${formatDate(item.createdAt)}'),
                isThreeLine: true,
                onTap: () => state.markNotificationRead(item),
              );
            },
          );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    final itineraries = state.itineraryHistory();
    final budgetAvg = itineraries.isEmpty
        ? 0.0
        : itineraries.fold<double>(0.0, (sum, plan) => sum + plan.cost.total) /
              itineraries.length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(user.email),
                const SizedBox(height: 4),
                Text('Role: ${userRoleLabel(user.role)}'),
                const SizedBox(height: 12),
                Text('Trips planned: ${itineraries.length}'),
                Text('Average projected spend: ${formatMoney(budgetAvg)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => state.logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Log Out'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Budget policy hints',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ...List<String>.generate(
          3,
          (index) =>
              'Tip ${index + 1}: Keep at least RM${(index + 1) * 50} contingency.',
        ).map((tip) => ListTile(dense: true, title: Text(tip))),
      ],
    );
  }
}
