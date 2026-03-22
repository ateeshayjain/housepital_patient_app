import 'package:flutter/material.dart';
import 'api_service.dart';

/// Represents a saved payment method for auto-pay.
class SavedPaymentMethod {
  final String id;
  final String type; // card, upi, netbanking
  final String displayName; // "HDFC •••• 4521", "UPI: user@okaxis"
  final String? cardNetwork; // visa, mastercard, rupay
  final bool isDefault;
  final bool autoPayEnabled;

  SavedPaymentMethod({
    required this.id,
    required this.type,
    required this.displayName,
    this.cardNetwork,
    this.isDefault = false,
    this.autoPayEnabled = false,
  });
}

/// Represents an upcoming payment reminder.
class PaymentReminder {
  final String id;
  final String serviceName; // "Nurse — Priya Mehra", "Equipment Rental"
  final String billingCycle; // monthly, quarterly
  final double amount;
  final DateTime dueDate;
  final String status; // upcoming, due_today, overdue, paid
  final bool autoPayEnabled;

  PaymentReminder({
    required this.id,
    required this.serviceName,
    required this.billingCycle,
    required this.amount,
    required this.dueDate,
    this.status = 'upcoming',
    this.autoPayEnabled = false,
  });

  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  String get urgencyLabel {
    final days = daysUntilDue;
    if (days < 0) return 'Overdue by ${-days} days';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }

  Color get urgencyColor {
    final days = daysUntilDue;
    if (days < 0) return const Color(0xFFDC3545); // red
    if (days <= 1) return const Color(0xFFF59E0B); // amber
    if (days <= 3) return const Color(0xFFE8820E); // orange
    return const Color(0xFF10B981); // green
  }

  /// Whether we should show a prominent reminder (2 days or less).
  bool get shouldShowReminder => daysUntilDue <= 2;
}

/// Service to manage payment reminders and saved payment methods.
///
/// Fetches upcoming payments from the backend API.
/// Future enhancements:
/// - Razorpay Subscriptions API for auto-debit
/// - Firebase Cloud Messaging for push notifications
/// - Tokenized cards via Razorpay's token hub
class PaymentReminderService {
  final ApiService _apiService;

  PaymentReminderService({required ApiService apiService})
      : _apiService = apiService;

  /// Returns saved payment methods from the backend.
  /// Falls back to empty list on error.
  Future<List<SavedPaymentMethod>> getSavedMethods() async {
    try {
      final result = await _apiService.get('/payments/saved-methods');
      final items = result['data'] as List<dynamic>? ?? [];
      return items
          .map((json) => SavedPaymentMethod(
                id: json['id'] as String,
                type: json['type'] as String,
                displayName: json['display_name'] as String,
                cardNetwork: json['card_network'] as String?,
                isDefault: json['is_default'] as bool? ?? false,
                autoPayEnabled: json['auto_pay_enabled'] as bool? ?? false,
              ))
          .toList();
    } catch (e) {
      debugPrint('PaymentReminderService: getSavedMethods failed: $e');
      return [];
    }
  }

  /// Fetches upcoming payment reminders from the backend.
  /// Falls back to empty list on error.
  Future<List<PaymentReminder>> getUpcomingReminders() async {
    try {
      final result = await _apiService.get('/payments/upcoming-reminders');
      final items = result['data'] as List<dynamic>? ?? [];
      return items
          .map((json) => PaymentReminder(
                id: json['id'] as String,
                serviceName: json['service_name'] as String,
                billingCycle: json['billing_cycle'] as String? ?? 'monthly',
                amount: (json['amount'] as num).toDouble(),
                dueDate: DateTime.parse(json['due_date'] as String),
                status: json['status'] as String? ?? 'upcoming',
                autoPayEnabled: json['auto_pay_enabled'] as bool? ?? false,
              ))
          .toList();
    } catch (e) {
      debugPrint('PaymentReminderService: getUpcomingReminders failed: $e');
      return [];
    }
  }

  /// Notification messages for payment reminders (Airtel-style).
  static List<Map<String, String>> getReminderMessages(PaymentReminder reminder) {
    final messages = <Map<String, String>>[];
    final days = reminder.daysUntilDue;

    if (days == 2) {
      messages.add({
        'title': 'Payment due in 2 days',
        'body':
            '₹${reminder.amount.toInt()} for ${reminder.serviceName} is due on ${_formatDate(reminder.dueDate)}. Pay now to avoid service interruption.',
      });
    } else if (days == 1) {
      messages.add({
        'title': 'Payment due tomorrow!',
        'body':
            '₹${reminder.amount.toInt()} for ${reminder.serviceName}. Pay today to avoid late charges.',
      });
    } else if (days == 0) {
      messages.add({
        'title': 'Payment due today',
        'body':
            '₹${reminder.amount.toInt()} for ${reminder.serviceName} is due today. Pay now to continue uninterrupted service.',
      });
    } else if (days < 0) {
      messages.add({
        'title': 'Payment overdue',
        'body':
            '₹${reminder.amount.toInt()} for ${reminder.serviceName} was due ${-days} days ago. Late charges may apply. Pay now.',
      });
    }

    return messages;
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
