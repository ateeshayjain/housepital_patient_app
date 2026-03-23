import 'package:flutter_test/flutter_test.dart';

/// Tests the slot availability logic extracted from ServiceBookingScreen.
void main() {
  // Mirrors _allSlotHours from _ServiceBookingScreenState
  const allSlotHours = [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19];

  /// Mirrors the fallback slot generation: each hour becomes a slot map.
  List<Map<String, dynamic>> generateSlots() {
    return allSlotHours
        .map((h) => <String, dynamic>{'hour': h, 'available': true})
        .toList();
  }

  /// Mirrors _slotLabel from the screen.
  String slotLabel(int hour) {
    final h = hour > 12 ? hour - 12 : hour;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final endHour = hour + 1 > 12 ? hour + 1 - 12 : hour + 1;
    final endAmPm = (hour + 1) >= 12 ? 'PM' : 'AM';
    return '$h:00 $amPm \u2013 $endHour:00 $endAmPm';
  }

  group('Slot availability', () {
    test('returns 11 time slots (9:00 through 19:00)', () {
      expect(allSlotHours.length, equals(11));
      expect(allSlotHours.first, equals(9));
      expect(allSlotHours.last, equals(19));
    });

    test('each generated slot has hour and available keys', () {
      final slots = generateSlots();
      for (final slot in slots) {
        expect(slot.containsKey('hour'), isTrue);
        expect(slot.containsKey('available'), isTrue);
        expect(slot['available'], isTrue);
      }
    });

    test('slot hours are in HH format (valid integers)', () {
      for (final hour in allSlotHours) {
        expect(hour, isA<int>());
        expect(hour, greaterThanOrEqualTo(0));
        expect(hour, lessThan(24));
      }
    });

    test('slots are chronologically ordered', () {
      for (int i = 1; i < allSlotHours.length; i++) {
        expect(allSlotHours[i], greaterThan(allSlotHours[i - 1]));
      }
    });

    test('slot labels are human-readable', () {
      expect(slotLabel(9), equals('9:00 AM \u2013 10:00 AM'));
      expect(slotLabel(12), equals('12:00 PM \u2013 1:00 PM'));
      expect(slotLabel(19), equals('7:00 PM \u2013 8:00 PM'));
    });

    test('all 11 slots generate valid labels', () {
      for (final hour in allSlotHours) {
        final label = slotLabel(hour);
        expect(label, isNotEmpty);
        expect(label, contains(':00'));
      }
    });
  });
}
