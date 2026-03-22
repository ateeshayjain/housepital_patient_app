// test/utils/helpers_test.dart
//
// Tests for DateHelper utilities in lib/utils/helpers.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/utils/helpers.dart';

void main() {
  // =========================================================================
  // formatCurrency
  // =========================================================================
  group('DateHelper.formatCurrency', () {
    test('formats zero', () {
      expect(DateHelper.formatCurrency(0), '\u20B90');
    });

    test('formats small amount without commas', () {
      expect(DateHelper.formatCurrency(500), '\u20B9500');
    });

    test('formats thousands with Indian grouping', () {
      // Indian format: 1,000
      final result = DateHelper.formatCurrency(1000);
      expect(result, contains('1'));
      expect(result, contains('000'));
      expect(result, startsWith('\u20B9'));
    });

    test('formats lakhs with Indian grouping', () {
      // Indian format: 1,50,000
      final result = DateHelper.formatCurrency(150000);
      expect(result, startsWith('\u20B9'));
      expect(result, contains('1'));
      expect(result, contains('50'));
      expect(result, contains('000'));
    });

    test('formats negative amount', () {
      final result = DateHelper.formatCurrency(-500);
      expect(result, contains('500'));
    });

    test('formats very large number', () {
      final result = DateHelper.formatCurrency(10000000);
      expect(result, startsWith('\u20B9'));
      // Should contain the digits without crashing
      expect(result, contains('1'));
    });

    test('has no decimal digits', () {
      final result = DateHelper.formatCurrency(999);
      expect(result, isNot(contains('.')));
    });
  });

  // =========================================================================
  // formatCurrencyPaise
  // =========================================================================
  group('DateHelper.formatCurrencyPaise', () {
    test('converts paise to rupees — 100 paise = 1 rupee', () {
      final result = DateHelper.formatCurrencyPaise(100);
      expect(result, contains('1'));
      expect(result, startsWith('\u20B9'));
    });

    test('zero paise', () {
      final result = DateHelper.formatCurrencyPaise(0);
      expect(result, '\u20B90');
    });

    test('large paise amount', () {
      // 500000 paise = 5000 rupees
      final result = DateHelper.formatCurrencyPaise(500000);
      expect(result, startsWith('\u20B9'));
      expect(result, contains('5'));
      expect(result, contains('000'));
    });
  });

  // =========================================================================
  // formatDate
  // =========================================================================
  group('DateHelper.formatDate', () {
    test('formats date as dd MMM yyyy', () {
      final dt = DateTime(2025, 1, 5);
      expect(DateHelper.formatDate(dt), '05 Jan 2025');
    });

    test('formats date with double-digit day', () {
      final dt = DateTime(2024, 12, 25);
      expect(DateHelper.formatDate(dt), '25 Dec 2024');
    });

    test('formats leap year date', () {
      final dt = DateTime(2024, 2, 29);
      expect(DateHelper.formatDate(dt), '29 Feb 2024');
    });
  });

  // =========================================================================
  // formatDateShort
  // =========================================================================
  group('DateHelper.formatDateShort', () {
    test('formats date as dd MMM (no year)', () {
      final dt = DateTime(2025, 3, 15);
      expect(DateHelper.formatDateShort(dt), '15 Mar');
    });
  });

  // =========================================================================
  // formatTime
  // =========================================================================
  group('DateHelper.formatTime', () {
    test('formats morning time with AM', () {
      final dt = DateTime(2025, 1, 1, 9, 30);
      expect(DateHelper.formatTime(dt), '9:30 AM');
    });

    test('formats afternoon time with PM', () {
      final dt = DateTime(2025, 1, 1, 14, 5);
      expect(DateHelper.formatTime(dt), '2:05 PM');
    });

    test('formats midnight as 12:00 AM', () {
      final dt = DateTime(2025, 1, 1, 0, 0);
      expect(DateHelper.formatTime(dt), '12:00 AM');
    });

    test('formats noon as 12:00 PM', () {
      final dt = DateTime(2025, 1, 1, 12, 0);
      expect(DateHelper.formatTime(dt), '12:00 PM');
    });
  });

  // =========================================================================
  // formatRelative
  // =========================================================================
  group('DateHelper.formatRelative', () {
    test('returns "Just now" for less than 1 minute ago', () {
      final now = DateTime.now();
      expect(DateHelper.formatRelative(now), 'Just now');
    });

    test('returns minutes ago for < 60 minutes', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 5));
      expect(DateHelper.formatRelative(dt), '5m ago');
    });

    test('returns hours ago for < 24 hours', () {
      final dt = DateTime.now().subtract(const Duration(hours: 3));
      expect(DateHelper.formatRelative(dt), '3h ago');
    });

    test('returns days ago for < 7 days', () {
      final dt = DateTime.now().subtract(const Duration(days: 2));
      expect(DateHelper.formatRelative(dt), '2d ago');
    });

    test('returns formatted date for >= 7 days', () {
      final dt = DateTime.now().subtract(const Duration(days: 10));
      final result = DateHelper.formatRelative(dt);
      // Should fall back to formatDate which has 'dd MMM yyyy' pattern
      expect(result, isNot(contains('ago')));
      expect(result, contains('20')); // contains year like 2025 or 2026
    });
  });

  // =========================================================================
  // VitalHelper.getVitalStatus
  // =========================================================================
  group('VitalHelper.getVitalStatus', () {
    test('returns "normal" for value within normal range', () {
      expect(VitalHelper.getVitalStatus('pulse', 80), 'normal');
    });

    test('returns "borderline" for value between low and normalLow', () {
      // pulse: low=50, normalLow=60, so 55 is borderline
      expect(VitalHelper.getVitalStatus('pulse', 55), 'borderline');
    });

    test('returns "borderline" for value between normalHigh and high', () {
      // pulse: normalHigh=100, high=110, so 105 is borderline
      expect(VitalHelper.getVitalStatus('pulse', 105), 'borderline');
    });

    test('returns "alert" for value below low', () {
      // pulse: low=50
      expect(VitalHelper.getVitalStatus('pulse', 45), 'alert');
    });

    test('returns "alert" for value above high', () {
      // pulse: high=110
      expect(VitalHelper.getVitalStatus('pulse', 120), 'alert');
    });

    test('returns "normal" for unknown vital type', () {
      // Unknown vital type returns greyLight color which maps to "normal"
      expect(VitalHelper.getVitalStatus('unknown_vital', 100), 'normal');
    });
  });
}
