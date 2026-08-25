// test/services/notification_id_test.dart
//
// Notification IDs are a Java `int` on Android and an Int32 on iOS. The old
// generator was `medicationId.hashCode.abs() * 10 + slot`, and Dart's
// String.hashCode on the 64-bit VM ranges far past 2^31 — so IDs were
// routinely out of range.
//
// Truncation is the dangerous half: two medications whose IDs differ only
// above bit 31 collapse onto the same notification ID, and scheduling the
// second silently REPLACES the first. The patient is simply never reminded
// about one of their drugs, and nothing reports an error anywhere.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/services/medication_reminder_service.dart';

void main() {
  const int32Max = 2147483647;

  /// Real-shaped medication IDs plus adversarial ones. UUIDs matter because
  /// that is what the backend issues, and their hashCodes are large.
  final ids = <String>[
    'med-1',
    'med-2',
    'MED-0000001',
    '3f7a1c22-9b1e-4f0a-8b6d-6a2b7c9e1f01',
    '3f7a1c22-9b1e-4f0a-8b6d-6a2b7c9e1f02',
    'a' * 128,
    '',
    '💊-insulin-morning',
    'दवा-सुबह',
    for (var i = 0; i < 400; i++) 'generated-medication-id-$i',
  ];

  test('every generated ID fits in a signed 32-bit int', () {
    for (final id in ids) {
      for (final slot in [0, 1, 2, 3, 5]) {
        final generated = MedicationReminderService.getNotificationIds(id, 4);
        for (final n in generated) {
          expect(n, inInclusiveRange(0, int32Max),
              reason: 'id "$id" produced $n — the platform truncates this');
        }
        expect(slot, inInclusiveRange(0, 9));
      }
    }
  });

  test('IDs are non-negative — .abs() was not a safety net', () {
    // int.minValue.abs() returns int.minValue in Dart. Masking the sign bit
    // has no exceptional case; abs() does.
    for (final id in ids) {
      for (final n in MedicationReminderService.getNotificationIds(id, 4)) {
        expect(n, greaterThanOrEqualTo(0), reason: 'id "$id"');
      }
    }
  });

  test('slots within one medication never collide', () {
    for (final id in ids) {
      final n = MedicationReminderService.getNotificationIds(id, 4);
      expect(n.toSet().length, n.length, reason: 'id "$id" reused a slot ID');
    }
  });

  test('IDs are stable across calls — cancellation depends on it', () {
    for (final id in ids.take(20)) {
      expect(MedicationReminderService.getNotificationIds(id, 4),
          MedicationReminderService.getNotificationIds(id, 4));
    }
  });

  test('400 distinct medications produce 400 distinct ID blocks', () {
    // Not a claim that collisions are impossible — they are, at this scale of
    // hashing — but a regression guard on the realistic case.
    final all = <int>{};
    var collisions = 0;
    for (var i = 0; i < 400; i++) {
      for (final n
          in MedicationReminderService.getNotificationIds('med-uuid-$i', 4)) {
        if (!all.add(n)) collisions++;
      }
    }
    expect(collisions, 0);
  });
}
