import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import 'vital_classifier.dart';

/// Presentation layer over [classifyVital]. Owns NO thresholds.
///
/// It used to own a second, different set — read from
/// `AppConstants.vitalRanges`, under different key names. SpO2 91 was RED via
/// classifyVital and BORDERLINE here; sugar 190 was YELLOW there and ALERT
/// here; and because this side spelled the key `systolic` while the other
/// spelled it `bp_systolic`, a blood-pressure reading matched neither map on
/// the trend screen and was counted as normal.
///
/// Everything now resolves through the single classifier. If a threshold
/// needs to change, it changes in vital_classifier.dart and both screens move
/// together — which is the only property that was ever missing.
class VitalHelper {
  static Color getVitalColor(String vitalType, double value) {
    switch (classifyVital(vitalType, value)) {
      case 'red':
        return HousepitalColors.vitalAlert;
      case 'yellow':
        return HousepitalColors.vitalBorderline;
      case 'green':
        return HousepitalColors.vitalNormal;
      default:
        // 'unknown' — an unrecognised vital type. Neutral, never reassuring.
        return HousepitalColors.greyLight;
    }
  }

  static String getVitalStatus(String vitalType, double value) {
    switch (classifyVital(vitalType, value)) {
      case 'red':
        return 'alert';
      case 'yellow':
        return 'borderline';
      case 'green':
        return 'normal';
      default:
        return 'unknown';
    }
  }
}

class DateHelper {
  static String formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  static String formatDate(DateTime dateTime) {
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  static String formatDateShort(DateTime dateTime) {
    return DateFormat('dd MMM').format(dateTime);
  }

  static String formatRelative(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatDate(dateTime);
  }

  static String formatCurrency(int amount) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0)
        .format(amount);
  }

  /// Format amount given in paise (1/100 rupee) — for payment gateway responses.
  static String formatCurrencyPaise(int amountPaise) {
    final rupees = amountPaise / 100;
    return NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0)
        .format(rupees);
  }
}

class AttendanceHelper {
  static Color getStatusColor(String status) {
    switch (status) {
      case 'checked_in':
        return HousepitalColors.checkedIn;
      case 'waiting':
        return HousepitalColors.waiting;
      case 'late':
        return HousepitalColors.late_;
      case 'absent':
        return HousepitalColors.absent;
      case 'on_leave':
        return HousepitalColors.onLeave;
      case 'checked_out':
        return HousepitalColors.checkedOut;
      default:
        return HousepitalColors.greyLight;
    }
  }

  static IconData getStatusIcon(String status) {
    switch (status) {
      case 'checked_in':
        return Icons.check_circle;
      case 'waiting':
        return Icons.schedule;
      case 'late':
        return Icons.warning_amber;
      case 'absent':
        return Icons.cancel;
      case 'on_leave':
        return Icons.event_busy;
      case 'checked_out':
        return Icons.logout;
      default:
        return Icons.help_outline;
    }
  }
}
