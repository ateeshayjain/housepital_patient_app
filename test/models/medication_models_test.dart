// test/models/medication_models_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/medication_models.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _medicationJson({
  String id = 'med-1',
  String patientId = 'pat-1',
  String name = 'Metformin',
  String dosage = '500mg',
  String form = 'tablet',
  String frequency = 'twice_daily',
  List<String>? timeSlots,
  String? instructions,
  String? prescribedBy,
  String? prescribedDate,
  String? endDate,
  int? stockCount,
  String? stockUnit,
  String? prescriptionPhotoUrl,
  bool isActive = true,
}) =>
    {
      'id': id,
      'patient_id': patientId,
      'name': name,
      'dosage': dosage,
      'form': form,
      'frequency': frequency,
      'time_slots': ?timeSlots,
      'instructions': ?instructions,
      'prescribed_by': ?prescribedBy,
      'prescribed_date': ?prescribedDate,
      'end_date': ?endDate,
      'stock_count': ?stockCount,
      'stock_unit': ?stockUnit,
      'prescription_photo_url': ?prescriptionPhotoUrl,
      'is_active': isActive,
    };

MedicationFull _buildMedication({
  String id = 'med-1',
  String patientId = 'pat-1',
  String name = 'Metformin',
  String dosage = '500mg',
  String frequency = 'twice_daily',
  int? stockCount,
}) =>
    MedicationFull.fromJson(_medicationJson(
      id: id,
      patientId: patientId,
      name: name,
      dosage: dosage,
      frequency: frequency,
      stockCount: stockCount,
    ));

MedicationLog _buildLog({
  String id = 'log-1',
  String medicationId = 'med-1',
  String scheduledTime = '2026-03-21T08:00:00',
  String? actualTime,
  String status = 'administered',
  String? skipReason,
  String? notes,
  String? staffId,
  String? staffName,
}) =>
    MedicationLog.fromJson({
      'id': id,
      'medication_id': medicationId,
      'staff_id': ?staffId,
      'staff_name': ?staffName,
      'scheduled_time': scheduledTime,
      'actual_time': ?actualTime,
      'status': status,
      'skip_reason': ?skipReason,
      'notes': ?notes,
    });

// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // MedicationFull
  // =========================================================================
  group('MedicationFull', () {
    // -----------------------------------------------------------------------
    // fromJson
    // -----------------------------------------------------------------------
    group('fromJson', () {
      test('parses all fields when fully populated', () {
        final json = _medicationJson(
          id: 'med-42',
          patientId: 'pat-7',
          name: 'Atorvastatin',
          dosage: '10mg',
          form: 'tablet',
          frequency: 'once_daily',
          timeSlots: ['21:00'],
          instructions: 'Take at bedtime',
          prescribedBy: 'Dr. Mehta',
          prescribedDate: '2026-01-15',
          endDate: '2026-04-15',
          stockCount: 60,
          stockUnit: 'tablets',
          prescriptionPhotoUrl: 'https://cdn.example.com/rx.jpg',
          isActive: true,
        );

        final med = MedicationFull.fromJson(json);

        expect(med.id, 'med-42');
        expect(med.patientId, 'pat-7');
        expect(med.name, 'Atorvastatin');
        expect(med.dosage, '10mg');
        expect(med.form, 'tablet');
        expect(med.frequency, 'once_daily');
        expect(med.timeSlots, ['21:00']);
        expect(med.instructions, 'Take at bedtime');
        expect(med.prescribedBy, 'Dr. Mehta');
        expect(med.prescribedDate, DateTime(2026, 1, 15));
        expect(med.endDate, DateTime(2026, 4, 15));
        expect(med.stockCount, 60);
        expect(med.stockUnit, 'tablets');
        expect(med.prescriptionPhotoUrl, 'https://cdn.example.com/rx.jpg');
        expect(med.isActive, isTrue);
      });

      test('applies defaults when optional fields are absent', () {
        final json = {
          'id': 'med-min',
          'patient_id': 'pat-1',
          'name': 'Paracetamol',
        };

        final med = MedicationFull.fromJson(json);

        expect(med.dosage, '');
        expect(med.form, 'tablet');
        expect(med.frequency, 'once_daily');
        expect(med.timeSlots, isEmpty);
        expect(med.instructions, isNull);
        expect(med.prescribedBy, isNull);
        expect(med.prescribedDate, isNull);
        expect(med.endDate, isNull);
        expect(med.stockCount, isNull);
        expect(med.stockUnit, isNull);
        expect(med.prescriptionPhotoUrl, isNull);
        expect(med.isActive, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // toJson round-trip
    // -----------------------------------------------------------------------
    group('toJson', () {
      test('round-trip preserves key scalar fields', () {
        final original = MedicationFull.fromJson(_medicationJson(
          name: 'Metformin',
          dosage: '500mg',
          form: 'tablet',
          frequency: 'twice_daily',
          timeSlots: ['08:00', '21:00'],
          instructions: 'With food',
          prescribedBy: 'Dr. Gupta',
          prescribedDate: '2026-01-10',
          endDate: '2026-04-10',
          stockCount: 56,
          stockUnit: 'tablets',
        ));

        final json = original.toJson();

        expect(json['name'], 'Metformin');
        expect(json['dosage'], '500mg');
        expect(json['form'], 'tablet');
        expect(json['frequency'], 'twice_daily');
        expect(json['time_slots'], ['08:00', '21:00']);
        expect(json['instructions'], 'With food');
        expect(json['prescribed_by'], 'Dr. Gupta');
        expect(json['prescribed_date'], '2026-01-10');
        expect(json['end_date'], '2026-04-10');
        expect(json['stock_count'], 56);
        expect(json['stock_unit'], 'tablets');
      });

      test('toJson sets date fields to null when dates are absent', () {
        final med = MedicationFull.fromJson(_medicationJson());
        final json = med.toJson();
        expect(json['prescribed_date'], isNull);
        expect(json['end_date'], isNull);
      });
    });

    // -----------------------------------------------------------------------
    // daysOfSupplyLeft
    // -----------------------------------------------------------------------
    group('daysOfSupplyLeft', () {
      test('returns 14 for 28 tablets at twice_daily (28 / 2 = 14)', () {
        final med = _buildMedication(frequency: 'twice_daily', stockCount: 28);
        expect(med.daysOfSupplyLeft, 14);
      });

      test('returns 28 for 28 tablets at once_daily (28 / 1 = 28)', () {
        final med = _buildMedication(frequency: 'once_daily', stockCount: 28);
        expect(med.daysOfSupplyLeft, 28);
      });

      test('returns 9 for 28 tablets at thrice_daily (floor(28 / 3) = 9)', () {
        final med = _buildMedication(frequency: 'thrice_daily', stockCount: 28);
        expect(med.daysOfSupplyLeft, 9);
      });

      test('returns 7 for 28 tablets at four_times_daily (28 / 4 = 7)', () {
        final med = _buildMedication(frequency: 'four_times_daily', stockCount: 28);
        expect(med.daysOfSupplyLeft, 7);
      });

      test('returns null when stockCount is null', () {
        final med = _buildMedication(frequency: 'once_daily', stockCount: null);
        expect(med.daysOfSupplyLeft, isNull);
      });

      test('returns null when stockCount is 0', () {
        final med = _buildMedication(frequency: 'once_daily', stockCount: 0);
        expect(med.daysOfSupplyLeft, isNull);
      });

      test('floors fractional days (5 tablets at twice_daily = 2 days)', () {
        final med = _buildMedication(frequency: 'twice_daily', stockCount: 5);
        expect(med.daysOfSupplyLeft, 2);
      });
    });

    // -----------------------------------------------------------------------
    // isLowStock
    // -----------------------------------------------------------------------
    group('isLowStock', () {
      test('true when daysOfSupplyLeft is less than 5 (e.g. 4 days)', () {
        // 8 tablets / twice_daily = 4 days → low stock
        final med = _buildMedication(frequency: 'twice_daily', stockCount: 8);
        expect(med.daysOfSupplyLeft, 4);
        expect(med.isLowStock, isTrue);
      });

      test('true when daysOfSupplyLeft is exactly 1', () {
        // 2 tablets / twice_daily = 1 day
        final med = _buildMedication(frequency: 'twice_daily', stockCount: 2);
        expect(med.isLowStock, isTrue);
      });

      test('false when daysOfSupplyLeft is exactly 5', () {
        // 10 tablets / twice_daily = 5 days → not low
        final med = _buildMedication(frequency: 'twice_daily', stockCount: 10);
        expect(med.daysOfSupplyLeft, 5);
        expect(med.isLowStock, isFalse);
      });

      test('false when daysOfSupplyLeft is greater than 5', () {
        // 28 tablets / twice_daily = 14 days
        final med = _buildMedication(frequency: 'twice_daily', stockCount: 28);
        expect(med.isLowStock, isFalse);
      });

      test('false (defaults to 999) when daysOfSupplyLeft is null', () {
        final med = _buildMedication(frequency: 'once_daily', stockCount: null);
        expect(med.isLowStock, isFalse);
      });

      test('false (defaults to 999) when stockCount is 0', () {
        final med = _buildMedication(frequency: 'once_daily', stockCount: 0);
        expect(med.isLowStock, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // frequencyLabel
    // -----------------------------------------------------------------------
    group('frequencyLabel', () {
      test('once_daily returns "Once daily"', () {
        final med = _buildMedication(frequency: 'once_daily');
        expect(med.frequencyLabel, 'Once daily');
      });

      test('twice_daily returns "Twice daily"', () {
        final med = _buildMedication(frequency: 'twice_daily');
        expect(med.frequencyLabel, 'Twice daily');
      });

      test('thrice_daily returns "Three times daily"', () {
        final med = _buildMedication(frequency: 'thrice_daily');
        expect(med.frequencyLabel, 'Three times daily');
      });

      test('four_times_daily returns "Four times daily"', () {
        final med = _buildMedication(frequency: 'four_times_daily');
        expect(med.frequencyLabel, 'Four times daily');
      });

      test('as_needed returns "As needed"', () {
        final med = _buildMedication(frequency: 'as_needed');
        expect(med.frequencyLabel, 'As needed');
      });

      test('unknown frequency falls back to the raw frequency string', () {
        final med = _buildMedication(frequency: 'every_other_day');
        expect(med.frequencyLabel, 'every_other_day');
      });
    });
  });

  // =========================================================================
  // MedicationLog
  // =========================================================================
  group('MedicationLog', () {
    group('fromJson', () {
      test('parses all fields when fully populated', () {
        final json = {
          'id': 'log-99',
          'medication_id': 'med-42',
          'staff_id': 'staff-7',
          'staff_name': 'Nurse Priya',
          'scheduled_time': '2026-03-21T08:00:00',
          'actual_time': '2026-03-21T08:05:00',
          'status': 'administered',
          'skip_reason': null,
          'notes': 'Taken with water',
        };

        final log = MedicationLog.fromJson(json);

        expect(log.id, 'log-99');
        expect(log.medicationId, 'med-42');
        expect(log.staffId, 'staff-7');
        expect(log.staffName, 'Nurse Priya');
        expect(log.scheduledTime, DateTime.parse('2026-03-21T08:00:00'));
        expect(log.actualTime, DateTime.parse('2026-03-21T08:05:00'));
        expect(log.status, 'administered');
        expect(log.skipReason, isNull);
        expect(log.notes, 'Taken with water');
      });

      test('handles absent optional fields', () {
        final json = {
          'id': 'log-min',
          'medication_id': 'med-1',
          'scheduled_time': '2026-03-21T14:00:00',
          'status': 'missed',
        };

        final log = MedicationLog.fromJson(json);

        expect(log.staffId, isNull);
        expect(log.staffName, isNull);
        expect(log.actualTime, isNull);
        expect(log.skipReason, isNull);
        expect(log.notes, isNull);
      });

      test('handles skipped status with reason', () {
        final json = {
          'id': 'log-skip',
          'medication_id': 'med-1',
          'scheduled_time': '2026-03-21T21:00:00',
          'status': 'skipped',
          'skip_reason': 'Patient refused',
        };

        final log = MedicationLog.fromJson(json);

        expect(log.status, 'skipped');
        expect(log.skipReason, 'Patient refused');
      });
    });

    // -----------------------------------------------------------------------
    // wasGiven / wasSkipped / wasMissed
    // -----------------------------------------------------------------------
    group('computed status properties', () {
      test('wasGiven is true for administered status', () {
        final log = _buildLog(status: 'administered');
        expect(log.wasGiven, isTrue);
        expect(log.wasSkipped, isFalse);
        expect(log.wasMissed, isFalse);
      });

      test('wasSkipped is true for skipped status', () {
        final log = _buildLog(status: 'skipped');
        expect(log.wasGiven, isFalse);
        expect(log.wasSkipped, isTrue);
        expect(log.wasMissed, isFalse);
      });

      test('wasMissed is true for missed status', () {
        final log = _buildLog(status: 'missed');
        expect(log.wasGiven, isFalse);
        expect(log.wasSkipped, isFalse);
        expect(log.wasMissed, isTrue);
      });

      test('all three are false for an unknown status', () {
        final log = _buildLog(status: 'pending');
        expect(log.wasGiven, isFalse);
        expect(log.wasSkipped, isFalse);
        expect(log.wasMissed, isFalse);
      });
    });
  });

  // =========================================================================
  // ScheduledMedication
  // =========================================================================
  group('ScheduledMedication', () {
    MedicationFull med0() => _buildMedication();

    group('isPast', () {
      test('true when scheduledTime is in the past', () {
        final past = DateTime.now().subtract(const Duration(hours: 2));
        final scheduled = ScheduledMedication(
          medication: med0(),
          scheduledTime: past,
        );
        expect(scheduled.isPast, isTrue);
      });

      test('false when scheduledTime is in the future', () {
        final future = DateTime.now().add(const Duration(hours: 2));
        final scheduled = ScheduledMedication(
          medication: med0(),
          scheduledTime: future,
        );
        expect(scheduled.isPast, isFalse);
      });
    });
  });

  // =========================================================================
  // MedicationScheduleSlot
  // =========================================================================
  group('MedicationScheduleSlot', () {
    MedicationFull med0({String id = 'med-1'}) => MedicationFull.fromJson(
          _medicationJson(id: id, name: 'Med $id'),
        );

    ScheduledMedication scheduledWith({
      required MedicationFull med,
      MedicationLog? log,
      bool past = true,
    }) =>
        ScheduledMedication(
          medication: med,
          log: log,
          scheduledTime: past
              ? DateTime.now().subtract(const Duration(hours: 1))
              : DateTime.now().add(const Duration(hours: 1)),
        );

    test('givenCount counts medications where log.wasGiven is true', () {
      final slot = MedicationScheduleSlot(
        label: 'Morning',
        time: '08:00',
        icon: '☀️',
        medications: [
          scheduledWith(med: med0(id: 'med-1'), log: _buildLog(status: 'administered')),
          scheduledWith(med: med0(id: 'med-2'), log: _buildLog(status: 'administered')),
          scheduledWith(med: med0(id: 'med-3'), log: _buildLog(status: 'skipped')),
        ],
      );

      expect(slot.givenCount, 2);
    });

    test('totalCount returns number of medications in slot', () {
      final slot = MedicationScheduleSlot(
        label: 'Afternoon',
        time: '14:00',
        icon: '🌤️',
        medications: [
          scheduledWith(med: med0(id: 'med-1'), log: _buildLog(status: 'administered')),
          scheduledWith(med: med0(id: 'med-2')),
        ],
      );

      expect(slot.totalCount, 2);
    });

    test('allGiven is true when every medication has been administered', () {
      final slot = MedicationScheduleSlot(
        label: 'Morning',
        time: '08:00',
        icon: '☀️',
        medications: [
          scheduledWith(med: med0(id: 'med-1'), log: _buildLog(status: 'administered')),
          scheduledWith(med: med0(id: 'med-2'), log: _buildLog(status: 'administered')),
        ],
      );

      expect(slot.allGiven, isTrue);
    });

    test('allGiven is false when at least one medication is not administered', () {
      final slot = MedicationScheduleSlot(
        label: 'Morning',
        time: '08:00',
        icon: '☀️',
        medications: [
          scheduledWith(med: med0(id: 'med-1'), log: _buildLog(status: 'administered')),
          scheduledWith(med: med0(id: 'med-2'), log: _buildLog(status: 'skipped')),
        ],
      );

      expect(slot.allGiven, isFalse);
    });

    test('allGiven is false when the slot is empty', () {
      final slot = MedicationScheduleSlot(
        label: 'Night',
        time: '21:00',
        icon: '🌙',
        medications: [],
      );

      expect(slot.allGiven, isFalse);
    });

    test('hasPending is true when a medication has no log and is not yet past', () {
      final slot = MedicationScheduleSlot(
        label: 'Night',
        time: '21:00',
        icon: '🌙',
        medications: [
          scheduledWith(med: med0(id: 'med-1'), log: null, past: false),
        ],
      );

      expect(slot.hasPending, isTrue);
    });

    test('hasPending is false when medication is past but has no log', () {
      final slot = MedicationScheduleSlot(
        label: 'Morning',
        time: '08:00',
        icon: '☀️',
        medications: [
          scheduledWith(med: med0(id: 'med-1'), log: null, past: true),
        ],
      );

      expect(slot.hasPending, isFalse);
    });

    test('hasPending is false when all medications have logs', () {
      final slot = MedicationScheduleSlot(
        label: 'Afternoon',
        time: '14:00',
        icon: '🌤️',
        medications: [
          scheduledWith(
            med: med0(id: 'med-1'),
            log: _buildLog(status: 'administered'),
            past: false,
          ),
        ],
      );

      expect(slot.hasPending, isFalse);
    });

    test('givenCount is 0 when no medications have been administered', () {
      final slot = MedicationScheduleSlot(
        label: 'Morning',
        time: '08:00',
        icon: '☀️',
        medications: [
          scheduledWith(med: med0(id: 'med-1'), log: null),
          scheduledWith(med: med0(id: 'med-2'), log: _buildLog(status: 'missed')),
        ],
      );

      expect(slot.givenCount, 0);
    });

    test('constructs correctly with empty medications list', () {
      final slot = MedicationScheduleSlot(
        label: 'Morning',
        time: '08:00',
        icon: '☀️',
      );

      expect(slot.givenCount, 0);
      expect(slot.totalCount, 0);
      expect(slot.allGiven, isFalse);
      expect(slot.hasPending, isFalse);
    });
  });
}
