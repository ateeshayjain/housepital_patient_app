// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

/// Show the "request sent to primary contact" confirmation dialog.
/// Used wherever a FAMILY_MEMBER taps a Book/Add-to-Cart button.
void showRequestBookingStub(BuildContext context, String itemName) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: context.hc.success),
          SizedBox(width: 8),
          Expanded(child: Text('Request Sent')),
        ],
      ),
      content: Text(
        '"$itemName" booking request sent to your primary contact for approval. '
        "They'll receive a notification to confirm and pay.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Show a snackbar nudge for PATIENT_SELF (view-only) users.
void showViewOnlyToast(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(
          "You're viewing your own care. Ask your family caregiver to book this."),
      backgroundColor: context.hc.greyLight,
    ));
}
