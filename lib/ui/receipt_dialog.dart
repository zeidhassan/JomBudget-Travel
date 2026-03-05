import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/models.dart';
import '../state/app_state.dart';

Future<void> showReceiptDialog(BuildContext context, Booking booking) async {
  final appState = context.read<AppState>();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Booking Receipt'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: SelectableText(appState.receiptPreview(booking)),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              final path = await appState.exportReceipt(booking);
              if (!dialogContext.mounted) {
                return;
              }
              final message = path == null
                  ? (appState.lastError ?? 'Unable to save receipt.')
                  : 'Saved to: $path';
              ScaffoldMessenger.of(
                dialogContext,
              ).showSnackBar(SnackBar(content: Text(message)));
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () => appState.shareReceipt(booking),
            child: const Text('Share'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
