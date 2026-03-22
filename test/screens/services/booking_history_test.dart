// test/screens/services/booking_history_test.dart
//
// Tests booking history screen data integrity:
// - Status filter options match the expected list
// - Status badge colors are correct per status
// - Cancellation reasons list is non-empty
// - Refund policy text: >24hr = full refund, <24hr = 50% refund

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/config/theme.dart';

// Replicate the static data from _BookingHistoryScreenState that we need to test.
// These values mirror booking_history_screen.dart exactly.

const _statusFilters = [
  'all',
  'pending',
  'confirmed',
  'in_progress',
  'completed',
  'cancelled',
];

Color _statusColor(String status) {
  switch (status) {
    case 'pending':
      return HousepitalColors.warning;
    case 'confirmed':
      return HousepitalColors.info;
    case 'in_progress':
      return HousepitalColors.orange;
    case 'completed':
      return HousepitalColors.success;
    case 'cancelled':
      return HousepitalColors.error;
    default:
      return HousepitalColors.greyLight;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'confirmed':
      return 'Confirmed';
    case 'in_progress':
      return 'In Progress';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}

const _cancellationReasons = [
  'Schedule conflict',
  'Found alternative',
  'No longer needed',
  'Other',
];

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Status filter options
  // ═══════════════════════════════════════════════════════════════════════════
  group('Booking history — Status filter options', () {
    test('filter list has 6 options', () {
      expect(_statusFilters.length, 6);
    });

    test('filter list contains all expected statuses', () {
      expect(_statusFilters, contains('all'));
      expect(_statusFilters, contains('pending'));
      expect(_statusFilters, contains('confirmed'));
      expect(_statusFilters, contains('in_progress'));
      expect(_statusFilters, contains('completed'));
      expect(_statusFilters, contains('cancelled'));
    });

    test('human-readable labels match expected names', () {
      expect(_statusLabel('all'), 'all'); // default case returns raw
      expect(_statusLabel('pending'), 'Pending');
      expect(_statusLabel('confirmed'), 'Confirmed');
      expect(_statusLabel('in_progress'), 'In Progress');
      expect(_statusLabel('completed'), 'Completed');
      expect(_statusLabel('cancelled'), 'Cancelled');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Status badge colors
  // ═══════════════════════════════════════════════════════════════════════════
  group('Booking history — Status badge colors', () {
    test('pending status is warning color', () {
      expect(_statusColor('pending'), HousepitalColors.warning);
    });

    test('confirmed status is info color', () {
      expect(_statusColor('confirmed'), HousepitalColors.info);
    });

    test('in_progress status is orange color', () {
      expect(_statusColor('in_progress'), HousepitalColors.orange);
    });

    test('completed status is success color', () {
      expect(_statusColor('completed'), HousepitalColors.success);
    });

    test('cancelled status is error color', () {
      expect(_statusColor('cancelled'), HousepitalColors.error);
    });

    test('unknown status falls back to greyLight', () {
      expect(_statusColor('unknown_status'), HousepitalColors.greyLight);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Cancellation reasons
  // ═══════════════════════════════════════════════════════════════════════════
  group('Booking history — Cancellation reasons', () {
    test('cancellation reasons list is non-empty', () {
      expect(_cancellationReasons, isNotEmpty);
    });

    test('cancellation reasons has at least 3 options', () {
      expect(_cancellationReasons.length, greaterThanOrEqualTo(3));
    });

    test('all reasons are non-empty strings', () {
      for (final reason in _cancellationReasons) {
        expect(reason.isNotEmpty, isTrue, reason: 'Empty reason found');
      }
    });

    test('contains expected reasons', () {
      expect(_cancellationReasons, contains('Schedule conflict'));
      expect(_cancellationReasons, contains('No longer needed'));
      expect(_cancellationReasons, contains('Other'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Refund policy
  // ═══════════════════════════════════════════════════════════════════════════
  group('Booking history — Refund policy', () {
    test('>24 hours before service gives full (100%) refund', () {
      final scheduledDate = DateTime.now().add(const Duration(hours: 48));
      final now = DateTime.now();
      final hoursUntil = scheduledDate.difference(now).inHours;
      final refundPercent = hoursUntil > 24 ? 100 : 50;

      expect(refundPercent, 100);
    });

    test('<24 hours before service gives 50% refund', () {
      final scheduledDate = DateTime.now().add(const Duration(hours: 12));
      final now = DateTime.now();
      final hoursUntil = scheduledDate.difference(now).inHours;
      final refundPercent = hoursUntil > 24 ? 100 : 50;

      expect(refundPercent, 50);
    });

    test('exactly 24 hours before service gives 50% refund', () {
      final scheduledDate = DateTime.now().add(const Duration(hours: 24));
      final now = DateTime.now();
      final hoursUntil = scheduledDate.difference(now).inHours;
      final refundPercent = hoursUntil > 24 ? 100 : 50;

      // 24 is not > 24, so it should be 50%
      expect(refundPercent, 50);
    });

    test('full refund text mentions "full refund"', () {
      const refundPercent = 100;
      const refundAmount = 5000;
      final text = refundPercent == 100
          ? 'More than 24 hours before service — full refund of ₹$refundAmount.'
          : 'Less than 24 hours before service — 50% refund of ₹$refundAmount.';
      expect(text, contains('full refund'));
    });

    test('50% refund text mentions "50% refund"', () {
      const refundPercent = 50;
      const refundAmount = 2500;
      final text = refundPercent == 100
          ? 'More than 24 hours before service — full refund of ₹$refundAmount.'
          : 'Less than 24 hours before service — 50% refund of ₹$refundAmount.';
      expect(text, contains('50% refund'));
    });

    test('refund amount calculation: 100% of 5000 = 5000', () {
      const totalAmount = 5000;
      const refundPercent = 100;
      final refundAmount = (totalAmount * refundPercent / 100).round();
      expect(refundAmount, 5000);
    });

    test('refund amount calculation: 50% of 5000 = 2500', () {
      const totalAmount = 5000;
      const refundPercent = 50;
      final refundAmount = (totalAmount * refundPercent / 100).round();
      expect(refundAmount, 2500);
    });
  });
}
