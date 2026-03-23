import 'package:flutter/material.dart';

/// Routes push notification taps to the correct screen based on the
/// `type` and `id` fields in the notification data payload.
class NotificationRouter {
  /// Handle a notification tap and navigate to the appropriate screen.
  static void handleNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final type = data['type'] as String?;
    final id = data['id'] as String?;

    if (type == null) return;

    switch (type) {
      case 'booking_confirmed':
      case 'staff_assigned':
        Navigator.pushNamed(
          context,
          '/order-tracking',
          arguments: {
            'bookingId': id ?? '',
            'orderType': 'booking',
          },
        );
        break;

      case 'staff_arrived':
        Navigator.pushNamed(context, '/staff-otp', arguments: id);
        break;

      case 'vitals_alert':
        Navigator.pushNamed(context, '/vitals');
        break;

      case 'report_ready':
        Navigator.pushNamed(context, '/report-detail', arguments: id ?? '');
        break;

      case 'payment_due':
        Navigator.pushNamed(context, '/billing');
        break;

      case 'assessment_quote':
        // Navigate to My Orders screen, Assessment Requests tab (index 1)
        Navigator.pushNamed(context, '/booking-history', arguments: 1);
        break;

      case 'concern_update':
        Navigator.pushNamed(context, '/raise-concern');
        break;

      case 'chat_message':
        Navigator.pushNamed(context, '/chat', arguments: id);
        break;

      default:
        debugPrint('NotificationRouter: unknown type "$type"');
        break;
    }
  }

  /// Show a foreground notification SnackBar with an action button.
  static void showForegroundSnackBar(
    BuildContext context,
    String? title,
    String? body,
    Map<String, dynamic> data,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            if (body != null)
              Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => handleNotification(context, data),
        ),
      ),
    );
  }
}
