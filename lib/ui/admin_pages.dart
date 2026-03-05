import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core_utils.dart';
import '../data/seed_data.dart';
import '../domain/models.dart';
import '../state/app_state.dart';
import 'receipt_dialog.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      _AdminUsersPage(),
      _AdminListingsPage(),
      _AdminDestinationsPage(),
      _AdminBookingsPage(),
      _AdminReviewsAndReportsPage(),
      _AdminProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const <Widget>[
          NavigationDestination(icon: Icon(Icons.groups), label: 'Users'),
          NavigationDestination(
            icon: Icon(Icons.inventory_2),
            label: 'Listings',
          ),
          NavigationDestination(icon: Icon(Icons.place), label: 'Destinations'),
          NavigationDestination(
            icon: Icon(Icons.manage_search),
            label: 'Bookings',
          ),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _AdminUsersPage extends StatelessWidget {
  const _AdminUsersPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final users = state.allUsers();

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Card(
          child: ListTile(
            title: Text(user.name),
            subtitle: Text('${user.email}\nRole: ${userRoleLabel(user.role)}'),
            trailing: Switch(
              value: user.isActive,
              onChanged: (value) => state.setUserActive(user.id, value),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class _AdminListingsPage extends StatelessWidget {
  const _AdminListingsPage();

  Future<void> _deleteListing(BuildContext context, Listing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete listing?'),
          content: Text(
            'This will permanently remove "${listing.title}" if it has no active bookings.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final state = context.read<AppState>();
    final success = state.adminDeleteListing(listing.id);
    final message = success
        ? 'Listing deleted.'
        : (state.lastError ?? 'Unable to delete listing.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final listings = state.allListings();

    return ListView.builder(
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final listing = listings[index];
        return Card(
          child: ListTile(
            title: Text(listing.title),
            subtitle: Text(
              '${listingTypeLabel(listing.type)} • ${listing.state}\n${formatMoney(listing.priceBase)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Switch(
                  value: listing.isActive,
                  onChanged: (value) =>
                      state.setListingActive(listing.id, value),
                ),
                IconButton(
                  tooltip: 'Delete listing',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteListing(context, listing),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class _AdminDestinationsPage extends StatelessWidget {
  const _AdminDestinationsPage();

  Future<void> _deleteDestination(
    BuildContext context,
    Destination destination,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete destination?'),
          content: Text(
            'Delete "${destination.name}" from destination recommendations.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final state = context.read<AppState>();
    final success = state.deleteDestination(destination.id);
    final message = success
        ? 'Destination deleted.'
        : (state.lastError ?? 'Unable to delete destination.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDestinationEditor(
    BuildContext context, {
    Destination? destination,
  }) async {
    final state = context.read<AppState>();
    final nameController = TextEditingController(text: destination?.name ?? '');
    final descriptionController = TextEditingController(
      text: destination?.description ?? '',
    );
    final budgetLowController = TextEditingController(
      text: (destination?.budgetLow ?? 150).toStringAsFixed(0),
    );
    final budgetHighController = TextEditingController(
      text: (destination?.budgetHigh ?? 450).toStringAsFixed(0),
    );
    final recommendedDaysController = TextEditingController(
      text: (destination?.recommendedDays ?? 3).toString(),
    );
    final highlightsController = TextEditingController(
      text: (destination?.highlights ?? const <String>[]).join(', '),
    );
    String selectedState = destination?.state ?? SeedData.malaysiaStates.first;
    bool isActive = destination?.isActive ?? true;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                destination == null ? 'Add Destination' : 'Edit Destination',
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedState,
                        decoration: const InputDecoration(labelText: 'State'),
                        items: SeedData.malaysiaStates
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry,
                                child: Text(entry),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() => selectedState = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Short Description',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: budgetLowController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Budget low (RM)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: budgetHighController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Budget high (RM)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: recommendedDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Recommended days',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: highlightsController,
                        decoration: const InputDecoration(
                          labelText: 'Highlights (comma separated)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (value) =>
                            setDialogState(() => isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true || !context.mounted) {
      nameController.dispose();
      descriptionController.dispose();
      budgetLowController.dispose();
      budgetHighController.dispose();
      recommendedDaysController.dispose();
      highlightsController.dispose();
      return;
    }

    final budgetLow = double.tryParse(budgetLowController.text) ?? 150;
    final parsedBudgetHigh = double.tryParse(budgetHighController.text) ?? 450;
    final budgetHigh = parsedBudgetHigh < budgetLow
        ? budgetLow
        : parsedBudgetHigh;
    final recommendedDays = (int.tryParse(recommendedDaysController.text) ?? 3)
        .clamp(1, 14)
        .toInt();
    final highlights = highlightsController.text
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();

    bool success;
    if (destination == null) {
      success = state.addDestination(
        name: nameController.text,
        state: selectedState,
        description: descriptionController.text,
        budgetLow: budgetLow,
        budgetHigh: budgetHigh,
        recommendedDays: recommendedDays,
        highlights: highlights,
        isActive: isActive,
      );
    } else {
      success = state.updateDestination(
        destination.copyWith(
          name: nameController.text.trim(),
          state: selectedState,
          description: descriptionController.text.trim(),
          budgetLow: budgetLow,
          budgetHigh: budgetHigh,
          recommendedDays: recommendedDays,
          highlights: highlights,
          isActive: isActive,
        ),
      );
    }

    final message = success
        ? 'Destination saved.'
        : (state.lastError ?? 'Unable to save destination.');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    nameController.dispose();
    descriptionController.dispose();
    budgetLowController.dispose();
    budgetHighController.dispose();
    recommendedDaysController.dispose();
    highlightsController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final destinations = state.allDestinations(activeOnly: false);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _openDestinationEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Destination'),
            ),
          ),
        ),
        Expanded(
          child: destinations.isEmpty
              ? const Center(child: Text('No destinations yet.'))
              : ListView.builder(
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    final destination = destinations[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    destination.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  destination.isActive ? 'Active' : 'Paused',
                                  style: TextStyle(
                                    color: destination.isActive
                                        ? Colors.green.shade700
                                        : Colors.orange.shade800,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(destination.state),
                            const SizedBox(height: 4),
                            Text(destination.description),
                            const SizedBox(height: 4),
                            Text(
                              'Budget: ${formatMoney(destination.budgetLow)} - ${formatMoney(destination.budgetHigh)} • ${destination.recommendedDays} days',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              destination.highlights.isEmpty
                                  ? 'Highlights: none'
                                  : 'Highlights: ${destination.highlights.join(', ')}',
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: <Widget>[
                                OutlinedButton.icon(
                                  onPressed: () => _openDestinationEditor(
                                    context,
                                    destination: destination,
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit'),
                                ),
                                FilledButton.icon(
                                  onPressed: () {
                                    state.updateDestination(
                                      destination.copyWith(
                                        isActive: !destination.isActive,
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    destination.isActive
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_outline,
                                  ),
                                  label: Text(
                                    destination.isActive ? 'Pause' : 'Activate',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _deleteDestination(context, destination),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
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
}

class _AdminBookingsPage extends StatefulWidget {
  const _AdminBookingsPage();

  @override
  State<_AdminBookingsPage> createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends State<_AdminBookingsPage> {
  BookingStatus? _statusFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openOverrideDialog(
    BuildContext context,
    Booking booking,
  ) async {
    final reasonController = TextEditingController(
      text: 'Traveler changed plans',
    );

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Admin Cancellation Override'),
          content: TextField(
            controller: reasonController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep Booking'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancel + Refund Mock'),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true && context.mounted) {
      context.read<AppState>().adminOverrideCancellation(
        bookingId: booking.id,
        reason: reasonController.text.trim().isEmpty
            ? 'Administrative override'
            : reasonController.text.trim(),
      );
    }

    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bookings = state.currentUserBookings();
    final usersById = <String, String>{
      for (final user in state.allUsers()) user.id: user.name,
    };

    final loweredQuery = _searchController.text.trim().toLowerCase();
    final filteredBookings = bookings.where((booking) {
      final statusMatches =
          _statusFilter == null || booking.status == _statusFilter;
      final queryMatches =
          loweredQuery.isEmpty ||
          booking.listingTitle.toLowerCase().contains(loweredQuery) ||
          booking.travelerId.toLowerCase().contains(loweredQuery) ||
          booking.vendorId.toLowerCase().contains(loweredQuery);
      return statusMatches && queryMatches;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search listing, traveler id, vendor id',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('All (${bookings.length})'),
                  selected: _statusFilter == null,
                  onSelected: (_) => setState(() => _statusFilter = null),
                ),
              ),
              ...BookingStatus.values.map(
                (status) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      '${bookingStatusLabel(status)} '
                      '(${bookings.where((booking) => booking.status == status).length})',
                    ),
                    selected: _statusFilter == status,
                    onSelected: (_) => setState(() => _statusFilter = status),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filteredBookings.isEmpty
              ? const Center(child: Text('No bookings match current filters.'))
              : ListView.builder(
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    final booking = filteredBookings[index];
                    final travelerName =
                        usersById[booking.travelerId] ?? booking.travelerId;
                    final vendorName =
                        usersById[booking.vendorId] ?? booking.vendorId;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              booking.listingTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text('Traveler: $travelerName'),
                            Text('Vendor: $vendorName'),
                            Text(
                              '${formatDate(booking.startDate)} - ${formatDate(booking.endDate)}',
                            ),
                            Text('Amount: ${formatMoney(booking.totalAmount)}'),
                            Text(
                              'Payment: ${booking.paymentStatus.name.toUpperCase()}',
                            ),
                            Text(
                              'Status: ${bookingStatusLabel(booking.status)}',
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      showReceiptDialog(context, booking),
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  label: const Text('Receipt'),
                                ),
                                if (booking.status ==
                                    BookingStatus.cancelRequested)
                                  FilledButton(
                                    onPressed: () =>
                                        _openOverrideDialog(context, booking),
                                    child: const Text('Override Cancel'),
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
}

class _AdminReviewsAndReportsPage extends StatelessWidget {
  const _AdminReviewsAndReportsPage();

  Future<void> _answerInquiry(BuildContext context, Inquiry inquiry) async {
    final answerController = TextEditingController(text: inquiry.answer ?? '');

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Admin inquiry response'),
          content: TextField(
            controller: answerController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Answer'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave == true && context.mounted) {
      final success = context.read<AppState>().answerInquiry(
        inquiryId: inquiry.id,
        answer: answerController.text,
      );
      final message = success
          ? 'Inquiry answered.'
          : (context.read<AppState>().lastError ?? 'Unable to answer inquiry.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    answerController.dispose();
  }

  Future<void> _openAnnouncementComposer(BuildContext context) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    UserRole? targetRole;

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Send announcement'),
              content: SizedBox(
                width: 430,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: bodyController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Message'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<UserRole?>(
                        value: targetRole,
                        decoration: const InputDecoration(
                          labelText: 'Audience',
                        ),
                        items: <DropdownMenuItem<UserRole?>>[
                          const DropdownMenuItem<UserRole?>(
                            value: null,
                            child: Text('All active users'),
                          ),
                          ...UserRole.values.map(
                            (role) => DropdownMenuItem<UserRole?>(
                              value: role,
                              child: Text(userRoleLabel(role)),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => targetRole = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSend == true && context.mounted) {
      final count = context.read<AppState>().sendAnnouncement(
        title: titleController.text,
        body: bodyController.text,
        targetRole: targetRole,
      );
      final message = count < 0
          ? (context.read<AppState>().lastError ??
                'Unable to send announcement.')
          : 'Announcement sent to $count users.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    titleController.dispose();
    bodyController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reviews = state.allReviews();
    final inquiries = state.allInquiries();
    final report = state.report();
    final records = state.allItineraryRecords();
    final usersById = <String, String>{
      for (final user in state.allUsers()) user.id: user.name,
    };

    final totalPlannerRuns = records.length;
    final infeasibleCount = records
        .where((record) => record.plan.remainingBudget < 0)
        .length;
    final averagePlannerSpend = totalPlannerRuns == 0
        ? 0.0
        : records.fold<double>(
                0,
                (sum, record) => sum + record.plan.cost.total,
              ) /
              totalPlannerRuns;
    final destinationFrequency = <String, int>{};
    for (final record in records) {
      destinationFrequency.update(
        record.plan.request.destinationState,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final topDestinations = destinationFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Admin tools: send platform announcements to travelers, vendors, or everyone.',
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _openAnnouncementComposer(context),
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Announcement'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Report Snapshot', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Total bookings: ${report.totalBookings}'),
                Text('Pending bookings: ${report.pendingBookings}'),
                Text('Revenue proxy: ${formatMoney(report.totalRevenue)}'),
                const SizedBox(height: 6),
                Text(
                  'Popular listings: ${report.popularListingTitles.join(', ')}',
                ),
                const SizedBox(height: 6),
                ...report.cancellationReasons.entries.map(
                  (entry) => Text('${entry.key}: ${entry.value}'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Planner Analytics',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Total planner runs: $totalPlannerRuns'),
                Text('Infeasible plans: $infeasibleCount'),
                Text(
                  'Average projected spend: ${formatMoney(averagePlannerSpend)}',
                ),
                const SizedBox(height: 6),
                Text(
                  topDestinations.isEmpty
                      ? 'Top destination states: No planner data yet.'
                      : 'Top destination states: ${topDestinations.take(3).map((entry) => '${entry.key} (${entry.value})').join(', ')}',
                ),
              ],
            ),
          ),
        ),
        if (records.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          ...records
              .take(5)
              .map(
                (record) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(
                      '${record.plan.request.destinationState} • ${formatMoney(record.plan.request.budget)}',
                    ),
                    subtitle: Text(
                      '${usersById[record.travelerId] ?? record.travelerId} • '
                      '${formatDate(record.plan.request.startDate)} - ${formatDate(record.plan.request.endDate)} • '
                      '${record.plan.message}',
                    ),
                  ),
                ),
              ),
        ],
        const SizedBox(height: 12),
        Text('Inquiry Threads', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        if (inquiries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('No inquiries available.'),
            ),
          )
        else
          ...inquiries.map(
            (inquiry) => Card(
              child: ListTile(
                title: Text(inquiry.question),
                subtitle: Text(
                  'Listing: ${inquiry.listingId}\n'
                  'Traveler: ${inquiry.travelerId}\n'
                  '${inquiry.isAnswered ? 'Answer: ${inquiry.answer}' : 'Pending answer'}',
                ),
                trailing: TextButton(
                  onPressed: () => _answerInquiry(context, inquiry),
                  child: Text(inquiry.isAnswered ? 'Edit' : 'Answer'),
                ),
                isThreeLine: true,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Review Moderation',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        if (reviews.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('No reviews available.'),
            ),
          )
        else
          ...reviews.map(
            (review) => Card(
              child: ListTile(
                title: Text('${review.rating}/5 • ${review.comment}'),
                subtitle: Text('Listing: ${review.listingId}'),
                trailing: Switch(
                  value: review.isFlagged,
                  onChanged: (value) => state.flagReview(review.id, value),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminProfilePage extends StatelessWidget {
  const _AdminProfilePage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final notifications = state.notificationsForCurrentUser();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: ListTile(
            title: Text(user.name),
            subtitle: Text('${user.email}\n${userRoleLabel(user.role)}'),
            isThreeLine: true,
          ),
        ),
        FilledButton.icon(
          onPressed: state.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Log Out'),
        ),
        const SizedBox(height: 8),
        Text('Admin notifications (${notifications.length})'),
        const SizedBox(height: 6),
        ...notifications
            .take(6)
            .map(
              (item) => ListTile(
                dense: true,
                title: Text(item.title),
                subtitle: Text(item.body),
                trailing: item.isRead
                    ? const Icon(Icons.done_all)
                    : const Icon(Icons.markunread),
                onTap: () => state.markNotificationRead(item),
              ),
            ),
      ],
    );
  }
}
