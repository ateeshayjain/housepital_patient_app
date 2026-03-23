import 'package:flutter_test/flutter_test.dart';

/// Tests the order tracking step logic extracted from OrderTrackingScreen.
void main() {
  // Mirrors _StepInfo and step lists from OrderTrackingScreen
  const bookingSteps = [
    'Placed',
    'Confirmed',
    'Staff Assigned',
    'En Route',
    'Arrived',
    'In Progress',
    'Completed',
  ];

  const equipmentSteps = [
    'Placed',
    'Confirmed',
    'Dispatched',
    'Out for Delivery',
    'Delivered',
  ];

  /// Mirrors the step status logic from _buildTimeline.
  String stepStatus(int stepIndex, int currentIndex) {
    if (stepIndex < currentIndex) return 'done';
    if (stepIndex == currentIndex) return 'active';
    return 'pending';
  }

  group('OrderTrackingScreen steps', () {
    test('booking flow has 7 steps', () {
      expect(bookingSteps.length, equals(7));
    });

    test('equipment flow has 5 steps', () {
      expect(equipmentSteps.length, equals(5));
    });

    test('all booking steps have non-empty titles', () {
      for (final step in bookingSteps) {
        expect(step, isNotEmpty);
      }
    });

    test('all equipment steps have non-empty titles', () {
      for (final step in equipmentSteps) {
        expect(step, isNotEmpty);
      }
    });

    test('step status: steps before current = done', () {
      const currentIndex = 3; // "En Route"
      expect(stepStatus(0, currentIndex), equals('done'));
      expect(stepStatus(1, currentIndex), equals('done'));
      expect(stepStatus(2, currentIndex), equals('done'));
    });

    test('step status: current step = active', () {
      const currentIndex = 3;
      expect(stepStatus(3, currentIndex), equals('active'));
    });

    test('step status: steps after current = pending', () {
      const currentIndex = 3;
      expect(stepStatus(4, currentIndex), equals('pending'));
      expect(stepStatus(5, currentIndex), equals('pending'));
      expect(stepStatus(6, currentIndex), equals('pending'));
    });

    test('first step is always Placed', () {
      expect(bookingSteps.first, equals('Placed'));
      expect(equipmentSteps.first, equals('Placed'));
    });

    test('last booking step is Completed', () {
      expect(bookingSteps.last, equals('Completed'));
    });

    test('last equipment step is Delivered', () {
      expect(equipmentSteps.last, equals('Delivered'));
    });
  });
}
