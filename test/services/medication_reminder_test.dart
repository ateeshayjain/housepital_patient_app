import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/medication_models.dart';
import 'package:housepital_patient/services/medication_reminder_service.dart';

void main() {
  group('MedicationReminderService', () {
    // ---- default slot mapping ----
    group('default slot times', () {
      test('morning maps to 08:00', () {
        expect(
          MedicationReminderService.defaultSlotTimes['morning'],
          '08:00',
        );
      });

      test('afternoon maps to 13:00', () {
        expect(
          MedicationReminderService.defaultSlotTimes['afternoon'],
          '13:00',
        );
      });

      test('evening maps to 18:00', () {
        expect(
          MedicationReminderService.defaultSlotTimes['evening'],
          '18:00',
        );
      });

      test('bedtime maps to 22:00', () {
        expect(
          MedicationReminderService.defaultSlotTimes['bedtime'],
          '22:00',
        );
      });
    });

    // ---- notification ID generation ----
    group('notification ID generation', () {
      test('IDs are unique per medication + slot index', () {
        final ids1 = MedicationReminderService.getNotificationIds('med_1', 3);
        final ids2 = MedicationReminderService.getNotificationIds('med_2', 3);

        // All IDs within a medication should be unique
        expect(ids1.toSet().length, 3);
        expect(ids2.toSet().length, 3);

        // IDs across different medications should not overlap
        final allIds = {...ids1, ...ids2};
        expect(allIds.length, 6);
      });

      test('same medication + slot produces same ID', () {
        final id1 = MedicationReminderService.getNotificationIds('med_abc', 2);
        final id2 = MedicationReminderService.getNotificationIds('med_abc', 2);
        expect(id1, equals(id2));
      });

      test('different slot indices produce different IDs', () {
        final ids = MedicationReminderService.getNotificationIds('med_x', 4);
        expect(ids[0], isNot(ids[1]));
        expect(ids[1], isNot(ids[2]));
        expect(ids[2], isNot(ids[3]));
      });
    });

    // ---- getNextReminder ----
    group('getNextReminder', () {
      MedicationFull _makeMed({
        String id = 'med_1',
        String name = 'Paracetamol',
        String dosage = '500mg',
        List<String> timeSlots = const ['08:00', '13:00', '20:00'],
        bool remindersEnabled = true,
        bool isActive = true,
        String frequency = 'thrice_daily',
      }) {
        return MedicationFull(
          id: id,
          patientId: 'p1',
          name: name,
          dosage: dosage,
          timeSlots: timeSlots,
          remindersEnabled: remindersEnabled,
          isActive: isActive,
          frequency: frequency,
        );
      }

      test('returns null when no medications are provided', () {
        final result = MedicationReminderService.getNextReminder([]);
        expect(result, isNull);
      });

      test('returns null for as_needed frequency', () {
        final med = _makeMed(frequency: 'as_needed', timeSlots: []);
        final result = MedicationReminderService.getNextReminder([med]);
        expect(result, isNull);
      });

      test('skips medications with remindersEnabled=false', () {
        final med = _makeMed(remindersEnabled: false);
        final result = MedicationReminderService.getNextReminder([med]);
        expect(result, isNull);
      });

      test('skips inactive medications', () {
        final med = _makeMed(isActive: false);
        final result = MedicationReminderService.getNextReminder([med]);
        expect(result, isNull);
      });

      test('picks the closest upcoming slot', () {
        // Create a medication with a slot far in the future (23:59)
        final med = _makeMed(timeSlots: ['23:59']);
        final result = MedicationReminderService.getNextReminder([med]);

        // It should find 23:59 as upcoming if we are before that time
        final now = DateTime.now();
        if (now.hour < 23 || (now.hour == 23 && now.minute < 59)) {
          expect(result, isNotNull);
          expect(result!.time, '23:59');
          expect(result.medicationName, 'Paracetamol');
        }
      });

      test('picks earlier slot over later slot when both upcoming', () {
        final med1 = _makeMed(
          id: 'a',
          name: 'DrugA',
          timeSlots: ['23:58'],
        );
        final med2 = _makeMed(
          id: 'b',
          name: 'DrugB',
          timeSlots: ['23:59'],
        );

        final now = DateTime.now();
        if (now.hour < 23 || (now.hour == 23 && now.minute < 58)) {
          final result =
              MedicationReminderService.getNextReminder([med1, med2]);
          expect(result, isNotNull);
          expect(result!.time, '23:58');
          expect(result.medicationName, 'DrugA');
        }
      });
    });

    // ---- getSlotStatus ----
    group('getSlotStatus', () {
      test('returns taken when isTaken is true', () {
        expect(
          MedicationReminderService.getSlotStatus('08:00', isTaken: true),
          'taken',
        );
      });

      test('returns upcoming for a future time slot', () {
        final status = MedicationReminderService.getSlotStatus(
          '23:59',
          isTaken: false,
        );
        final now = DateTime.now();
        if (now.hour < 23 || (now.hour == 23 && now.minute < 59)) {
          expect(status, 'upcoming');
        }
      });

      test('returns missed for a past time slot that was not taken', () {
        final status = MedicationReminderService.getSlotStatus(
          '00:01',
          isTaken: false,
        );
        final now = DateTime.now();
        if (now.hour > 0 || now.minute > 1) {
          expect(status, 'missed');
        }
      });
    });
  });
}
