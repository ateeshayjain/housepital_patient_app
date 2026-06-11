// test/providers/medication_provider_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/providers/medication_provider.dart';
import 'package:housepital_patient/models/medication_models.dart';

import 'mock_api_service.dart';

// ── Fixture helpers ──────────────────────────────────────────────────────────

MedicationFull _makeMedication({
  String id = 'm1',
  String name = 'Paracetamol',
  String frequency = 'twice_daily',
  List<String> timeSlots = const ['08:00', '20:00'],
  bool isActive = true,
  int? stockCount,
}) {
  return MedicationFull(
    id: id,
    patientId: 'patient1',
    name: name,
    dosage: '500 mg',
    form: 'tablet',
    frequency: frequency,
    timeSlots: timeSlots,
    isActive: isActive,
    stockCount: stockCount,
  );
}

MedicationLog _makeLog({
  String id = 'log1',
  String medicationId = 'm1',
  required DateTime scheduledTime,
  String status = 'administered',
}) {
  return MedicationLog(
    id: id,
    medicationId: medicationId,
    scheduledTime: scheduledTime,
    status: status,
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockApiService mock;
  late MedicationProvider provider;

  setUp(() {
    mock = MockApiService();
    provider = MedicationProvider(mock);
  });

  // ── loadMedications ────────────────────────────────────────────────────────

  group('MedicationProvider — loadMedications', () {
    test('success: populates medications list and clears error', () async {
      mock.medicationsResult = [_makeMedication(), _makeMedication(id: 'm2', name: 'Metformin')];

      await provider.loadMedications('patient1');

      expect(provider.medications, hasLength(2));
      expect(provider.medications[0].name, 'Paracetamol');
      expect(provider.medications[1].name, 'Metformin');
      expect(provider.error, isNull);
    });

    test('success with empty list: medications is empty', () async {
      mock.medicationsResult = [];
      await provider.loadMedications('patient1');

      expect(provider.medications, isEmpty);
      expect(provider.error, isNull);
    });

    test('ApiException: seeds demo data, medications NOT empty', () async {
      mock.shouldThrowApiException = true;
      mock.apiExceptionMessage = 'Server error';

      await provider.loadMedications('patient1');

      // Provider now seeds demo data instead of setting error
      expect(provider.medications, isNotEmpty);
      expect(provider.error, isNull);
    });

    test('generic error: seeds demo data, medications NOT empty', () async {
      mock.shouldThrowGenericError = true;

      await provider.loadMedications('patient1');

      // Provider now seeds demo data instead of setting error
      expect(provider.medications, isNotEmpty);
    });

    test('isLoading is true during load, false after', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));

      mock.medicationsResult = [_makeMedication()];
      await provider.loadMedications('patient1');

      expect(states, containsAllInOrder([true, false]));
      expect(provider.isLoading, isFalse);
    });

    test('isLoading is false after error', () async {
      mock.shouldThrowApiException = true;
      await provider.loadMedications('patient1');

      expect(provider.isLoading, isFalse);
    });
  });

  // ── loadTodaySchedule ──────────────────────────────────────────────────────

  group('MedicationProvider — loadTodaySchedule', () {
    test('success: builds schedule slots from medications and logs', () async {
      final today = DateTime.now();
      final morningTime = DateTime(today.year, today.month, today.day, 8, 0);

      final med = _makeMedication(
        timeSlots: ['08:00', '20:00'],
        frequency: 'twice_daily',
        isActive: true,
      );
      final log = _makeLog(
        medicationId: 'm1',
        scheduledTime: morningTime,
        status: 'administered',
      );

      mock.medicationsResult = [med];
      mock.medicationLogsResult = [log];

      await provider.loadTodaySchedule('patient1');

      expect(provider.schedule, hasLength(2));

      final morning = provider.schedule.first;
      expect(morning.time, '08:00');
      expect(morning.label, 'Morning');
      expect(morning.medications, hasLength(1));
      expect(morning.medications.first.log?.status, 'administered');

      final night = provider.schedule.last;
      expect(night.time, '20:00');
      expect(night.label, 'Night');
      // No log for 20:00 slot
      expect(night.medications.first.log, isNull);
    });

    test('as_needed medications are excluded from schedule slots', () async {
      final med = _makeMedication(
        frequency: 'as_needed',
        timeSlots: [],
        isActive: true,
      );
      mock.medicationsResult = [med];
      mock.medicationLogsResult = [];

      await provider.loadTodaySchedule('patient1');

      expect(provider.schedule, isEmpty);
    });

    test('inactive medications are excluded from schedule', () async {
      final inactive = _makeMedication(id: 'm1', isActive: false, timeSlots: ['08:00']);
      mock.medicationsResult = [inactive];
      mock.medicationLogsResult = [];

      await provider.loadTodaySchedule('patient1');

      expect(provider.schedule, isEmpty);
    });

    // Contract change (field bug, 2026-06-11): API failure must FALL BACK to
    // demo data like every other loader in this provider — the device showed
    // "Couldn't load data" on Today's Schedule in demo mode. No error is set;
    // the schedule is built from DemoData.medications.
    test('ApiException during schedule load falls back to demo schedule',
        () async {
      mock.shouldThrowApiException = true;
      mock.apiExceptionMessage = 'Forbidden';

      await provider.loadTodaySchedule('patient1');

      expect(provider.error, isNull);
      expect(provider.medications, isNotEmpty);
      expect(provider.schedule, isNotEmpty);
      expect(provider.isLoading, isFalse);
    });

    test('generic error during schedule load falls back to demo schedule',
        () async {
      mock.shouldThrowGenericError = true;

      await provider.loadTodaySchedule('patient1');

      expect(provider.error, isNull);
      expect(provider.schedule, isNotEmpty);
    });

    test('morning slot label for hour < 12', () async {
      final med = _makeMedication(timeSlots: ['06:00'], frequency: 'once_daily');
      mock.medicationsResult = [med];
      mock.medicationLogsResult = [];

      await provider.loadTodaySchedule('patient1');

      expect(provider.schedule.first.label, 'Morning');
    });

    test('afternoon slot label for hour 12-16', () async {
      final med = _makeMedication(timeSlots: ['14:00'], frequency: 'once_daily');
      mock.medicationsResult = [med];
      mock.medicationLogsResult = [];

      await provider.loadTodaySchedule('patient1');

      expect(provider.schedule.first.label, 'Afternoon');
    });

    test('night slot label for hour >= 17', () async {
      final med = _makeMedication(timeSlots: ['21:00'], frequency: 'once_daily');
      mock.medicationsResult = [med];
      mock.medicationLogsResult = [];

      await provider.loadTodaySchedule('patient1');

      expect(provider.schedule.first.label, 'Night');
    });

    test('slots are sorted chronologically', () async {
      final med = _makeMedication(
        timeSlots: ['21:00', '08:00', '14:00'],
        frequency: 'thrice_daily',
      );
      mock.medicationsResult = [med];
      mock.medicationLogsResult = [];

      await provider.loadTodaySchedule('patient1');

      expect(provider.schedule.map((s) => s.time).toList(),
          ['08:00', '14:00', '21:00']);
    });
  });

  // ── addMedication ──────────────────────────────────────────────────────────

  group('MedicationProvider — addMedication', () {
    test('success: returns true and appends medication to list', () async {
      final newMed = _makeMedication(id: 'm99', name: 'Atorvastatin');
      mock.addMedicationResult = newMed;

      final result = await provider.addMedication('patient1', {'name': 'Atorvastatin'});

      expect(result, isTrue);
      expect(provider.medications, hasLength(1));
      expect(provider.medications.first.id, 'm99');
    });

    test('success: appends to existing list without removing others', () async {
      // Pre-load one medication
      mock.medicationsResult = [_makeMedication(id: 'm1')];
      await provider.loadMedications('patient1');

      final newMed = _makeMedication(id: 'm2', name: 'Metformin');
      mock.addMedicationResult = newMed;
      await provider.addMedication('patient1', {'name': 'Metformin'});

      expect(provider.medications, hasLength(2));
    });

    test('ApiException: returns false and sets error', () async {
      mock.shouldThrowApiException = true;
      mock.apiExceptionMessage = 'Validation error';

      final result = await provider.addMedication('patient1', {});

      expect(result, isFalse);
      expect(provider.error, 'Validation error');
      expect(provider.medications, isEmpty);
    });

    test('isSaving is true during save and false after success', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isSaving));

      mock.addMedicationResult = _makeMedication();
      await provider.addMedication('patient1', {});

      expect(states, containsAllInOrder([true, false]));
      expect(provider.isSaving, isFalse);
    });

    test('isSaving is false after ApiException', () async {
      mock.shouldThrowApiException = true;
      await provider.addMedication('patient1', {});

      expect(provider.isSaving, isFalse);
    });
  });

  // ── updateMedication ───────────────────────────────────────────────────────

  group('MedicationProvider — updateMedication', () {
    setUp(() async {
      // Pre-populate with a medication
      mock.medicationsResult = [_makeMedication(id: 'm1', name: 'Paracetamol')];
      await provider.loadMedications('patient1');
    });

    test('success: returns true and updates medication in list', () async {
      final updated = _makeMedication(id: 'm1', name: 'Paracetamol 650mg');
      mock.updateMedicationResult = updated;

      final result =
          await provider.updateMedication('patient1', 'm1', {'dosage': '650 mg'});

      expect(result, isTrue);
      expect(provider.medications.first.name, 'Paracetamol 650mg');
    });

    test('success: list length does not change after update', () async {
      final updated = _makeMedication(id: 'm1', name: 'Updated');
      mock.updateMedicationResult = updated;

      await provider.updateMedication('patient1', 'm1', {});

      expect(provider.medications, hasLength(1));
    });

    test('ApiException: returns false and sets error', () async {
      mock.shouldThrowApiException = true;
      mock.apiExceptionMessage = 'Not found';

      final result =
          await provider.updateMedication('patient1', 'm1', {});

      expect(result, isFalse);
      expect(provider.error, 'Not found');
    });

    test('isSaving is false after ApiException', () async {
      mock.shouldThrowApiException = true;
      await provider.updateMedication('patient1', 'm1', {});

      expect(provider.isSaving, isFalse);
    });

    test('isSaving transitions through true then false on success', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isSaving));

      mock.updateMedicationResult = _makeMedication(id: 'm1');
      await provider.updateMedication('patient1', 'm1', {});

      expect(states, containsAllInOrder([true, false]));
    });
  });

  // ── deleteMedication ───────────────────────────────────────────────────────

  group('MedicationProvider — deleteMedication', () {
    setUp(() async {
      mock.medicationsResult = [
        _makeMedication(id: 'm1'),
        _makeMedication(id: 'm2', name: 'Metformin'),
      ];
      await provider.loadMedications('patient1');
    });

    test('success: returns true and removes medication from list', () async {
      final result = await provider.deleteMedication('patient1', 'm1');

      expect(result, isTrue);
      expect(provider.medications, hasLength(1));
      expect(provider.medications.first.id, 'm2');
    });

    test('success: deleting non-existent id leaves list unchanged', () async {
      final result = await provider.deleteMedication('patient1', 'unknown');

      expect(result, isTrue);
      expect(provider.medications, hasLength(2));
    });

    test('ApiException: returns false and sets error', () async {
      mock.shouldThrowApiException = true;
      mock.apiExceptionMessage = 'Cannot delete';

      final result = await provider.deleteMedication('patient1', 'm1');

      expect(result, isFalse);
      expect(provider.error, 'Cannot delete');
    });

    test('ApiException: list is not modified on failure', () async {
      mock.shouldThrowApiException = true;
      await provider.deleteMedication('patient1', 'm1');

      expect(provider.medications, hasLength(2));
    });
  });

  // ── activeMedications ──────────────────────────────────────────────────────

  group('MedicationProvider — activeMedications', () {
    test('returns only active medications', () async {
      mock.medicationsResult = [
        _makeMedication(id: 'm1', isActive: true),
        _makeMedication(id: 'm2', isActive: false),
        _makeMedication(id: 'm3', isActive: true),
      ];
      await provider.loadMedications('patient1');

      expect(provider.activeMedications, hasLength(2));
      expect(provider.activeMedications.map((m) => m.id), containsAll(['m1', 'm3']));
    });

    test('returns empty list when no active medications', () async {
      mock.medicationsResult = [
        _makeMedication(id: 'm1', isActive: false),
      ];
      await provider.loadMedications('patient1');

      expect(provider.activeMedications, isEmpty);
    });

    test('returns all medications when all are active', () async {
      mock.medicationsResult = [
        _makeMedication(id: 'm1'),
        _makeMedication(id: 'm2', name: 'Metformin'),
      ];
      await provider.loadMedications('patient1');

      expect(provider.activeMedications, hasLength(2));
    });
  });

  // ── lowStockMedications ────────────────────────────────────────────────────

  group('MedicationProvider — lowStockMedications', () {
    test('flags medication as low stock when daysOfSupply < 5', () async {
      // twice_daily: 2 doses/day => 6 tablets = 3 days => low stock
      mock.medicationsResult = [
        _makeMedication(id: 'm1', frequency: 'twice_daily', stockCount: 6),
      ];
      await provider.loadMedications('patient1');

      expect(provider.lowStockMedications, hasLength(1));
    });

    test('does not flag when daysOfSupply >= 5', () async {
      // once_daily: 1 dose/day => 10 tablets = 10 days => not low stock
      mock.medicationsResult = [
        _makeMedication(id: 'm1', frequency: 'once_daily', stockCount: 10),
      ];
      await provider.loadMedications('patient1');

      expect(provider.lowStockMedications, isEmpty);
    });

    test('excludes inactive medications even if stock is low', () async {
      mock.medicationsResult = [
        _makeMedication(id: 'm1', isActive: false, stockCount: 2),
      ];
      await provider.loadMedications('patient1');

      expect(provider.lowStockMedications, isEmpty);
    });

    test('returns empty list initially', () {
      expect(provider.lowStockMedications, isEmpty);
    });

    test('medication with null stockCount is flagged as low stock', () async {
      // daysOfSupplyLeft returns null when stockCount is null,
      // and isLowStock treats null as (null ?? 999) < 5 => false
      mock.medicationsResult = [
        _makeMedication(id: 'm1', stockCount: null),
      ];
      await provider.loadMedications('patient1');

      // null stockCount => daysOfSupplyLeft is null => (null ?? 999) = 999 >= 5 => not low
      expect(provider.lowStockMedications, isEmpty);
    });
  });

  // ── Single-tap dose logging (logNextDoseToday / logDoseToday) ────────────

  group('MedicationProvider — single-tap dose logging', () {
    setUp(() async {
      mock.medicationsResult = [
        _makeMedication(id: 'm1', timeSlots: ['08:00', '20:00']),
      ];
      await provider.loadMedications('patient1');
    });

    test('logNextDoseToday logs the next pending slot (earliest first)', () {
      expect(provider.nextPendingSlotToday('m1'), '08:00');

      final result = provider.logNextDoseToday('m1');

      expect(result, isTrue);
      expect(provider.isDoseTakenToday('m1', '08:00'), isTrue);
      expect(provider.isSlotLoggedToday('m1', '08:00'), isTrue);
      expect(provider.isSlotLoggedToday('m1', '20:00'), isFalse);
      // Session-local log recorded so Today's Schedule rows flip too.
      expect(provider.todayLogs, hasLength(1));
      expect(provider.todayLogs.single.medicationId, 'm1');
      expect(provider.todayLogs.single.wasGiven, isTrue);
      expect(provider.todayLogs.single.scheduledTime.hour, 8);
    });

    test('second call logs the following slot', () {
      provider.logNextDoseToday('m1');

      final result = provider.logNextDoseToday('m1');

      expect(result, isTrue);
      expect(provider.isDoseTakenToday('m1', '20:00'), isTrue);
      expect(provider.nextPendingSlotToday('m1'), isNull);
      expect(provider.todayLogs, hasLength(2));
    });

    test('all slots logged: returns false and is a no-op', () {
      provider.logNextDoseToday('m1');
      provider.logNextDoseToday('m1');

      final result = provider.logNextDoseToday('m1');

      expect(result, isFalse);
      expect(provider.todayLogs, hasLength(2));
      expect(provider.dosesMarkedTakenToday, 2);
    });

    test('unknown medication id returns false', () {
      expect(provider.logNextDoseToday('nope'), isFalse);
      expect(provider.todayLogs, isEmpty);
    });

    test('staff-administered log counts as logged: next pending skips it',
        () async {
      final today = DateTime.now();
      mock.medicationLogsResult = [
        _makeLog(
          medicationId: 'm1',
          scheduledTime: DateTime(today.year, today.month, today.day, 8, 0),
        ),
      ];
      await provider.loadTodaySchedule('patient1');

      expect(provider.isSlotLoggedToday('m1', '08:00'), isTrue);
      expect(provider.nextPendingSlotToday('m1'), '20:00');
      expect(provider.logNextDoseToday('m1'), isTrue);
      expect(provider.isDoseTakenToday('m1', '20:00'), isTrue);
    });

    test('logDoseToday updates the built schedule (slot shows wasGiven)',
        () async {
      mock.medicationLogsResult = [];
      await provider.loadTodaySchedule('patient1');
      final before = provider.schedule.firstWhere((s) => s.time == '08:00');
      expect(before.medications.first.log, isNull);

      provider.logDoseToday('m1', '08:00');

      final morning = provider.schedule.firstWhere((s) => s.time == '08:00');
      expect(morning.medications.first.log?.wasGiven, isTrue);
    });

    test('logDoseToday same slot twice: second returns false (no duplicate)',
        () {
      expect(provider.logDoseToday('m1', '08:00'), isTrue);
      expect(provider.logDoseToday('m1', '08:00'), isFalse);
      expect(provider.todayLogs, hasLength(1));
    });

    test('notifies listeners when a dose is logged', () {
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.logNextDoseToday('m1');

      expect(notifications, greaterThan(0));
    });
  });

  // ── Loading/saving state edge cases ──────────────────────────────────────

  group('MedicationProvider — loading and saving state', () {
    test('isLoading starts false', () {
      expect(provider.isLoading, isFalse);
    });

    test('isSaving starts false', () {
      expect(provider.isSaving, isFalse);
    });

    test('error starts null', () {
      expect(provider.error, isNull);
    });

    test('error is cleared before a successful loadMedications', () async {
      // With demo data seeding, error is never set — but confirm
      // that a subsequent successful load still results in no error
      mock.shouldThrowApiException = true;
      await provider.loadMedications('patient1');

      mock.shouldThrowApiException = false;
      mock.medicationsResult = [];
      await provider.loadMedications('patient1');

      expect(provider.error, isNull);
    });
  });
}
