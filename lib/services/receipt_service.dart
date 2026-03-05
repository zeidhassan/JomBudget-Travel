import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core_utils.dart';
import '../domain/models.dart';

class ReceiptService {
  String buildReceiptText(Booking booking) {
    return 'JomBudget Booking Receipt\n'
        'Receipt ID: ${booking.id}\n'
        'Listing: ${booking.listingTitle}\n'
        'Traveler ID: ${booking.travelerId}\n'
        'Date range: ${formatDate(booking.startDate)} - ${formatDate(booking.endDate)}\n'
        'Pax: ${booking.pax}\n'
        'Payment status: ${booking.paymentStatus.name}\n'
        'Booking status: ${booking.status.name}\n'
        'Total paid: ${formatMoney(booking.totalAmount)}\n';
  }

  Future<String> saveToDownloads(Booking booking) async {
    final content = buildReceiptText(booking);
    final downloads = await getDownloadsDirectory();
    final targetDir = downloads ?? await getApplicationDocumentsDirectory();
    final file = File('${targetDir.path}/jombudget-receipt-${booking.id}.txt');
    await file.writeAsString(content);
    return file.path;
  }

  Future<void> shareReceipt(Booking booking) async {
    final content = buildReceiptText(booking);
    await SharePlus.instance.share(ShareParams(text: content));
  }
}
