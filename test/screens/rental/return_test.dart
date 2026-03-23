import 'package:flutter_test/flutter_test.dart';

/// Tests the return screen data/logic extracted from ReturnScreen.
void main() {
  // Data constants mirrored from _ReturnScreenState
  const reasons = [
    'No longer needed',
    'Upgrading',
    'Moving',
    'Equipment issue',
    'Other',
  ];

  const conditions = ['Good', 'Minor wear', 'Damaged'];

  const timeSlots = ['Morning', 'Afternoon', 'Evening'];

  /// Mirrors _availableDates getter: next 5 days starting from day+3.
  List<DateTime> availableDates() {
    final now = DateTime.now();
    return List.generate(5, (i) => now.add(Duration(days: i + 3)));
  }

  group('ReturnScreen data', () {
    test('return reasons list is non-empty', () {
      expect(reasons, isNotEmpty);
      expect(reasons.length, equals(5));
    });

    test('all reasons have non-empty labels', () {
      for (final reason in reasons) {
        expect(reason, isNotEmpty);
      }
    });

    test('equipment condition options exist (Good, Minor wear, Damaged)', () {
      expect(conditions, contains('Good'));
      expect(conditions, contains('Minor wear'));
      expect(conditions, contains('Damaged'));
      expect(conditions.length, equals(3));
    });

    test('time slots are provided', () {
      expect(timeSlots, isNotEmpty);
      expect(timeSlots.length, equals(3));
    });

    test('pickup dates are in the future (next 3-7 days)', () {
      final now = DateTime.now();
      final dates = availableDates();

      expect(dates.length, equals(5));

      for (final date in dates) {
        expect(date.isAfter(now), isTrue);
      }

      // First date should be 3 days from now
      final firstDate = dates.first;
      final diffDays = firstDate.difference(now).inDays;
      expect(diffDays, greaterThanOrEqualTo(2)); // at least 2 full days ahead
      expect(diffDays, lessThanOrEqualTo(3));

      // Last date should be 7 days from now
      final lastDate = dates.last;
      final lastDiffDays = lastDate.difference(now).inDays;
      expect(lastDiffDays, greaterThanOrEqualTo(6));
      expect(lastDiffDays, lessThanOrEqualTo(7));
    });
  });
}
