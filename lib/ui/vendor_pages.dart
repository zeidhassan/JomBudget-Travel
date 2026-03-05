import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core_utils.dart';
import '../data/seed_data.dart';
import '../domain/models.dart';
import '../state/app_state.dart';
import 'receipt_dialog.dart';

class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      _VendorListingsPage(),
      _VendorBookingsPage(),
      _VendorPerformancePage(),
      _VendorFeedbackPage(),
      _VendorProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Dashboard')),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const <Widget>[
          NavigationDestination(icon: Icon(Icons.store), label: 'Listings'),
          NavigationDestination(
            icon: Icon(Icons.assignment_turned_in),
            label: 'Bookings',
          ),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.reviews), label: 'Feedback'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _VendorListingsPage extends StatelessWidget {
  const _VendorListingsPage();

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

  Widget _buildListingImage(String source) {
    final dataBytes = _bytesFromDataUri(source);
    if (dataBytes != null) {
      return Image.memory(dataBytes, fit: BoxFit.cover);
    }
    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Text(
            'No image',
            style: TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Image.network(
      source,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Text(
          'No image',
          style: TextStyle(fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<String?> _pickAndUploadImage(BuildContext context) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (selected == null || selected.files.isEmpty) {
      return null;
    }

    final file = selected.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to read selected image bytes.')),
      );
      return null;
    }

    final ext = (file.extension ?? 'png').toLowerCase();
    final filename = 'listing-${DateTime.now().millisecondsSinceEpoch}.$ext';
    return appState.uploadImageBytes(
      bytes: bytes,
      filename: filename,
      folder: 'listings',
    );
  }

  Future<void> _openAvailabilityManager(
    BuildContext context,
    Listing listing,
  ) async {
    final state = context.read<AppState>();
    final reasonController = TextEditingController(text: 'Maintenance');
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    DateTime endDate = DateTime.now().add(const Duration(days: 2));

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final windows = state.availabilityForListing(listing.id);

            return AlertDialog(
              title: Text('Availability: ${listing.title}'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (windows.isEmpty)
                        const Text('No blackout windows configured.')
                      else
                        ...windows.map(
                          (window) => Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              title: Text(
                                '${formatDate(window.startDate)} - ${formatDate(window.endDate)}',
                              ),
                              subtitle: Text(window.reason),
                              trailing: IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  final success = state
                                      .removeAvailabilityWindow(window.id);
                                  if (!success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          state.lastError ??
                                              'Unable to remove availability window.',
                                        ),
                                      ),
                                    );
                                  }
                                  setDialogState(() {});
                                },
                              ),
                            ),
                          ),
                        ),
                      const Divider(height: 20),
                      const Text(
                        'Add blackout window',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final selected = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 30),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 730),
                                  ),
                                  initialDate: startDate,
                                );
                                if (selected == null) {
                                  return;
                                }
                                setDialogState(() {
                                  startDate = DateUtils.dateOnly(selected);
                                  if (endDate.isBefore(startDate)) {
                                    endDate = startDate;
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
                                    const Duration(days: 730),
                                  ),
                                  initialDate: endDate,
                                );
                                if (selected == null) {
                                  return;
                                }
                                setDialogState(
                                  () => endDate = DateUtils.dateOnly(selected),
                                );
                              },
                              child: Text('End: ${formatDate(endDate)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reasonController,
                        minLines: 1,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Reason'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: () {
                    final success = state.addAvailabilityWindow(
                      listingId: listing.id,
                      startDate: startDate,
                      endDate: endDate,
                      reason: reasonController.text,
                    );
                    final message = success
                        ? 'Blackout window added.'
                        : (state.lastError ?? 'Unable to add blackout window.');
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                    if (success) {
                      setDialogState(() {});
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();
  }

  Future<void> _openListingEditor(
    BuildContext context, {
    Listing? listing,
  }) async {
    final state = context.read<AppState>();

    final titleController = TextEditingController(text: listing?.title ?? '');
    final descriptionController = TextEditingController(
      text: listing?.description ?? '',
    );
    final locationController = TextEditingController(
      text: listing?.location ?? '',
    );
    final priceController = TextEditingController(
      text: listing == null ? '40' : listing.priceBase.toStringAsFixed(0),
    );
    final tagsController = TextEditingController(
      text: listing == null ? 'budget,student' : listing.tags.join(','),
    );

    ListingType type = listing?.type ?? ListingType.activity;
    String selectedState = listing?.state ?? 'Kuala Lumpur';
    final List<String> imageUrls = List<String>.from(
      listing?.imageUrls ?? const <String>[],
    );
    var isUploading = false;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(listing == null ? 'Create Listing' : 'Edit Listing'),
              content: SizedBox(
                width: 460,
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
                        controller: descriptionController,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                        ),
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
                      DropdownButtonFormField<ListingType>(
                        value: type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: ListingType.values
                            .map(
                              (entry) => DropdownMenuItem<ListingType>(
                                value: entry,
                                child: Text(listingTypeLabel(entry)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() => type = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Base price (RM)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text(
                            'Listing photos',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextButton.icon(
                            onPressed: isUploading
                                ? null
                                : () async {
                                    setDialogState(() => isUploading = true);
                                    final uploaded = await _pickAndUploadImage(
                                      context,
                                    );
                                    if (uploaded != null) {
                                      setDialogState(() {
                                        imageUrls.add(uploaded);
                                      });
                                    }
                                    if (context.mounted) {
                                      setDialogState(() => isUploading = false);
                                    }
                                  },
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Add photo'),
                          ),
                        ],
                      ),
                      if (isUploading) ...<Widget>[
                        const LinearProgressIndicator(minHeight: 3),
                        const SizedBox(height: 8),
                      ],
                      if (imageUrls.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('No photo selected yet.'),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: imageUrls
                              .map(
                                (imageUrl) => Stack(
                                  children: <Widget>[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 84,
                                        height: 84,
                                        child: _buildListingImage(imageUrl),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: InkWell(
                                        onTap: () => setDialogState(
                                          () => imageUrls.remove(imageUrl),
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.55,
                                            ),
                                            borderRadius:
                                                const BorderRadius.only(
                                                  bottomLeft: Radius.circular(
                                                    8,
                                                  ),
                                                ),
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
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
      titleController.dispose();
      descriptionController.dispose();
      locationController.dispose();
      priceController.dispose();
      tagsController.dispose();
      return;
    }

    final price = double.tryParse(priceController.text) ?? 0;
    final tags = tagsController.text
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();

    bool success;
    if (listing == null) {
      success = state.addVendorListing(
        type: type,
        title: titleController.text,
        description: descriptionController.text,
        location: locationController.text,
        state: selectedState,
        priceBase: price,
        tags: tags,
        imageUrls: imageUrls,
      );
    } else {
      success = state.updateVendorListing(
        listing.copyWith(
          type: type,
          title: titleController.text,
          description: descriptionController.text,
          location: locationController.text,
          state: selectedState,
          priceBase: price,
          tags: tags,
          imageUrls: imageUrls,
        ),
      );
    }

    final message = success
        ? 'Listing saved.'
        : (state.lastError ?? 'Unable to save listing.');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    priceController.dispose();
    tagsController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final listings = state.vendorListings();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _openListingEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Listing'),
            ),
          ),
        ),
        Expanded(
          child: listings.isEmpty
              ? const Center(child: Text('No listings found.'))
              : ListView.builder(
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    final blockCount = state
                        .availabilityForListing(listing.id)
                        .length;
                    final statusColor = listing.isActive
                        ? Colors.green.shade700
                        : Colors.orange.shade800;

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: listing.imageUrls.isEmpty
                                ? Container(
                                    color: Colors.grey.shade200,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.image_outlined,
                                      size: 40,
                                    ),
                                  )
                                : _buildListingImage(listing.imageUrls.first),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        listing.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        listing.isActive ? 'Active' : 'Paused',
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  listing.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: <Widget>[
                                    Chip(
                                      label: Text(
                                        listingTypeLabel(listing.type),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    Chip(
                                      label: Text(listing.state),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    Chip(
                                      label: Text(
                                        formatMoney(listing.priceBase),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    Chip(
                                      avatar: Icon(
                                        Icons.star,
                                        color: Colors.amber.shade800,
                                        size: 16,
                                      ),
                                      label: Text(
                                        listing.ratingAvg.toStringAsFixed(1),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    Chip(
                                      avatar: const Icon(
                                        Icons.calendar_month_outlined,
                                        size: 16,
                                      ),
                                      label: Text('Blackouts: $blockCount'),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    OutlinedButton.icon(
                                      onPressed: () => _openListingEditor(
                                        context,
                                        listing: listing,
                                      ),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Edit'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _openAvailabilityManager(
                                        context,
                                        listing,
                                      ),
                                      icon: const Icon(
                                        Icons.calendar_month_outlined,
                                      ),
                                      label: const Text('Availability'),
                                    ),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          state.updateVendorListing(
                                            listing.copyWith(
                                              isActive: !listing.isActive,
                                            ),
                                          ),
                                      icon: Icon(
                                        listing.isActive
                                            ? Icons.pause_circle_outline
                                            : Icons.play_circle_outline,
                                      ),
                                      label: Text(
                                        listing.isActive
                                            ? 'Pause Listing'
                                            : 'Activate Listing',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _VendorBookingsPage extends StatelessWidget {
  const _VendorBookingsPage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bookings = state.currentUserBookings();

    return bookings.isEmpty
        ? const Center(
            child: Text('No bookings assigned to your listings yet.'),
          )
        : ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
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
                        '${formatDate(booking.startDate)} - ${formatDate(booking.endDate)}',
                      ),
                      Text(
                        'Pax: ${booking.pax} • ${formatMoney(booking.totalAmount)}',
                      ),
                      Text(
                        'Payment: ${booking.paymentStatus.name.toUpperCase()}',
                      ),
                      Text('Status: ${bookingStatusLabel(booking.status)}'),
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
                          if (booking.status == BookingStatus.pending &&
                              booking.paymentStatus == PaymentStatus.paid)
                            OutlinedButton(
                              onPressed: () => state.vendorDecision(
                                bookingId: booking.id,
                                accept: false,
                              ),
                              child: const Text('Reject'),
                            ),
                          if (booking.status == BookingStatus.pending &&
                              booking.paymentStatus == PaymentStatus.paid)
                            FilledButton(
                              onPressed: () => state.vendorDecision(
                                bookingId: booking.id,
                                accept: true,
                              ),
                              child: const Text('Confirm'),
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

class _VendorPerformancePage extends StatelessWidget {
  const _VendorPerformancePage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bookings = state.currentUserBookings();

    final totalPaid = bookings
        .where((booking) => booking.paymentStatus == PaymentStatus.paid)
        .fold<double>(0, (sum, booking) => sum + booking.totalAmount);

    final confirmedCount = bookings
        .where((booking) => booking.status == BookingStatus.confirmed)
        .length;
    final completionCount = bookings
        .where((booking) => booking.status == BookingStatus.completed)
        .length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: ListTile(
            title: const Text('Total Paid Revenue'),
            subtitle: Text(formatMoney(totalPaid)),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Confirmed Bookings'),
            subtitle: Text('$confirmedCount'),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Completed Bookings'),
            subtitle: Text('$completionCount'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Performance log',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ...bookings
            .take(10)
            .map(
              (booking) => ListTile(
                dense: true,
                title: Text(booking.listingTitle),
                subtitle: Text(
                  '${bookingStatusLabel(booking.status)} • ${formatMoney(booking.totalAmount)}',
                ),
              ),
            ),
      ],
    );
  }
}

class _VendorFeedbackPage extends StatelessWidget {
  const _VendorFeedbackPage();

  Future<void> _reply(BuildContext context, Review review) async {
    final replyController = TextEditingController(
      text: review.vendorReply ?? '',
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reply to review'),
          content: TextField(
            controller: replyController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Reply'),
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
      context.read<AppState>().vendorReplyToReview(
        review: review,
        reply: replyController.text.trim(),
      );
    }

    replyController.dispose();
  }

  Future<void> _answerInquiry(BuildContext context, Inquiry inquiry) async {
    final answerController = TextEditingController(text: inquiry.answer ?? '');

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Answer inquiry'),
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reviews = state.vendorReviews();
    final inquiries = state.vendorInquiries();

    if (reviews.isEmpty && inquiries.isEmpty) {
      return const Center(child: Text('No traveler feedback yet.'));
    }

    return ListView(
      children: <Widget>[
        if (inquiries.isNotEmpty) ...<Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Traveler Inquiries',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ...inquiries.map(
            (inquiry) => Card(
              child: ListTile(
                title: Text(inquiry.question),
                subtitle: inquiry.isAnswered
                    ? Text('Answer: ${inquiry.answer}')
                    : const Text('Pending response'),
                trailing: TextButton(
                  onPressed: () => _answerInquiry(context, inquiry),
                  child: Text(inquiry.isAnswered ? 'Edit' : 'Answer'),
                ),
              ),
            ),
          ),
        ],
        if (reviews.isNotEmpty) ...<Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Reviews',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ...reviews.map(
            (review) => Card(
              child: ListTile(
                title: Text('${review.rating}/5 • ${review.comment}'),
                subtitle: review.vendorReply == null
                    ? const Text('No reply yet')
                    : Text('Reply: ${review.vendorReply}'),
                trailing: TextButton(
                  onPressed: () => _reply(context, review),
                  child: const Text('Reply'),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VendorProfilePage extends StatelessWidget {
  const _VendorProfilePage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: ListTile(
            title: Text(user.name),
            subtitle: Text('${user.email}\nRole: ${userRoleLabel(user.role)}'),
            isThreeLine: true,
          ),
        ),
        FilledButton.icon(
          onPressed: state.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Log Out'),
        ),
        const SizedBox(height: 8),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Vendor goals: keep listing details up to date, respond to feedback, and confirm bookings quickly.',
            ),
          ),
        ),
      ],
    );
  }
}
