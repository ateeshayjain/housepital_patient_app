// test/models/booking_state_machine_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/utils/booking_state_machine.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Valid transitions
  // ═══════════════════════════════════════════════════════════════════════════
  group('Valid transitions', () {
    test('pending -> confirmed', () {
      expect(canTransition('pending', 'confirmed'), isTrue);
      expect(transition('pending', 'confirmed'), 'confirmed');
    });

    test('pending -> cancelled', () {
      expect(canTransition('pending', 'cancelled'), isTrue);
      expect(transition('pending', 'cancelled'), 'cancelled');
    });

    test('confirmed -> in_progress', () {
      expect(canTransition('confirmed', 'in_progress'), isTrue);
      expect(transition('confirmed', 'in_progress'), 'in_progress');
    });

    test('confirmed -> cancelled', () {
      expect(canTransition('confirmed', 'cancelled'), isTrue);
      expect(transition('confirmed', 'cancelled'), 'cancelled');
    });

    test('in_progress -> completed', () {
      expect(canTransition('in_progress', 'completed'), isTrue);
      expect(transition('in_progress', 'completed'), 'completed');
    });

    test('full happy path: pending -> confirmed -> in_progress -> completed', () {
      String status = 'pending';
      status = transition(status, 'confirmed');
      expect(status, 'confirmed');

      status = transition(status, 'in_progress');
      expect(status, 'in_progress');

      status = transition(status, 'completed');
      expect(status, 'completed');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Invalid transitions
  // ═══════════════════════════════════════════════════════════════════════════
  group('Invalid transitions', () {
    test('completed -> pending: should fail', () {
      expect(canTransition('completed', 'pending'), isFalse);
      expect(
        () => transition('completed', 'pending'),
        throwsStateError,
      );
    });

    test('cancelled -> confirmed: should fail', () {
      expect(canTransition('cancelled', 'confirmed'), isFalse);
      expect(
        () => transition('cancelled', 'confirmed'),
        throwsStateError,
      );
    });

    test('completed -> cancelled: should fail (terminal state)', () {
      expect(canTransition('completed', 'cancelled'), isFalse);
      expect(
        () => transition('completed', 'cancelled'),
        throwsStateError,
      );
    });

    test('cancelled -> in_progress: should fail (terminal state)', () {
      expect(canTransition('cancelled', 'in_progress'), isFalse);
    });

    test('pending -> in_progress: should fail (must confirm first)', () {
      expect(canTransition('pending', 'in_progress'), isFalse);
      expect(
        () => transition('pending', 'in_progress'),
        throwsStateError,
      );
    });

    test('pending -> completed: should fail (cannot skip steps)', () {
      expect(canTransition('pending', 'completed'), isFalse);
    });

    test('in_progress -> confirmed: should fail (cannot go backwards)', () {
      expect(canTransition('in_progress', 'confirmed'), isFalse);
    });

    test('in_progress -> cancelled: should fail (must complete or it is a dispute)', () {
      expect(canTransition('in_progress', 'cancelled'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // validNextStatuses
  // ═══════════════════════════════════════════════════════════════════════════
  group('validNextStatuses', () {
    test('pending can go to confirmed or cancelled', () {
      final next = validNextStatuses('pending');
      expect(next, containsAll(['confirmed', 'cancelled']));
      expect(next.length, 2);
    });

    test('confirmed can go to in_progress or cancelled', () {
      final next = validNextStatuses('confirmed');
      expect(next, containsAll(['in_progress', 'cancelled']));
      expect(next.length, 2);
    });

    test('in_progress can only go to completed', () {
      final next = validNextStatuses('in_progress');
      expect(next, contains('completed'));
      expect(next.length, 1);
    });

    test('completed is terminal (no next statuses)', () {
      expect(validNextStatuses('completed'), isEmpty);
    });

    test('cancelled is terminal (no next statuses)', () {
      expect(validNextStatuses('cancelled'), isEmpty);
    });

    test('unknown status returns empty set', () {
      expect(validNextStatuses('nonexistent'), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Edge cases
  // ═══════════════════════════════════════════════════════════════════════════
  group('Edge cases', () {
    test('self-transition is not allowed', () {
      expect(canTransition('pending', 'pending'), isFalse);
      expect(canTransition('confirmed', 'confirmed'), isFalse);
      expect(canTransition('completed', 'completed'), isFalse);
    });

    test('unknown from-status returns false', () {
      expect(canTransition('nonexistent', 'confirmed'), isFalse);
    });

    test('unknown to-status returns false', () {
      expect(canTransition('pending', 'nonexistent'), isFalse);
    });

    test('BookingStatus.all contains all 5 statuses', () {
      expect(BookingStatus.all.length, 5);
      expect(BookingStatus.all, containsAll([
        'pending', 'confirmed', 'in_progress', 'completed', 'cancelled',
      ]));
    });
  });
}
