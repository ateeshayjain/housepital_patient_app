// test/providers/app_provider_test.dart
//
// Tests for AppProvider initial state and synchronous behavior.
// Uses SharedPreferences mock and a minimal ApiService stub.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/utils/vital_classifier.dart';

/// Records the vitals POST so tests can assert the API was attempted.
class _RecordingVitalsApi extends ApiService {
  String? submittedPatientId;
  VitalReading? submittedReading;

  @override
  Future<void> submitVitalReading(
      String patientId, VitalReading reading) async {
    submittedPatientId = patientId;
    submittedReading = reading;
  }
}

/// Simulates the demo-mode condition: the vitals POST always fails.
class _FailingVitalsApi extends ApiService {
  @override
  Future<void> submitVitalReading(
      String patientId, VitalReading reading) async {
    throw Exception('api.housepital.in unreachable');
  }
}

VitalReading _bpReading({double systolic = 120, double diastolic = 80}) =>
    VitalReading(
      id: 'manual_test_${systolic.toInt()}_${diastolic.toInt()}',
      patientId: 'pat_demo_rajesh',
      recordedAt: DateTime.now(),
      systolic: systolic,
      diastolic: diastolic,
    );

void main() {
  // Ensure Flutter bindings are initialised for SharedPreferences
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppProvider provider;

  setUp(() {
    // Seed empty SharedPreferences so _loadLanguage doesn't crash
    SharedPreferences.setMockInitialValues({});
    provider = AppProvider(ApiService());
  });

  // =========================================================================
  // Initial state
  // =========================================================================
  group('AppProvider — initial state', () {
    test('currentPatient is null', () {
      expect(provider.currentPatient, isNull);
    });

    test('patients list is empty', () {
      expect(provider.patients, isEmpty);
    });

    test('activeDeployment is null', () {
      expect(provider.activeDeployment, isNull);
    });

    test('latestVitals is null', () {
      expect(provider.latestVitals, isNull);
    });

    test('todayAttendance is null', () {
      expect(provider.todayAttendance, isNull);
    });

    test('todayReport is null', () {
      expect(provider.todayReport, isNull);
    });

    test('dashboardError is null', () {
      expect(provider.dashboardError, isNull);
    });

    test('isDashboardLoading starts false', () {
      expect(provider.isDashboardLoading, isFalse);
    });

    test('amountDue starts at 0', () {
      expect(provider.amountDue, 0);
    });

    test('dueDate is null', () {
      expect(provider.dueDate, isNull);
    });
  });

  // =========================================================================
  // Locale defaults
  // =========================================================================
  group('AppProvider — locale', () {
    test('locale defaults to "en"', () {
      // _loadLanguage is async and reads SharedPreferences.
      // With empty prefs, default is 'en'.
      expect(provider.locale.languageCode, 'en');
    });

    test('setLanguage changes locale to "hi"', () async {
      await provider.setLanguage('hi');
      expect(provider.locale.languageCode, 'hi');
    });

    test('setLanguage persists to SharedPreferences', () async {
      await provider.setLanguage('hi');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('preferred_language'), 'hi');
    });

    test('setLanguage back to "en"', () async {
      await provider.setLanguage('hi');
      await provider.setLanguage('en');
      expect(provider.locale.languageCode, 'en');
    });
  });

  // =========================================================================
  // Language loaded from SharedPreferences
  // =========================================================================
  group('AppProvider — language from prefs', () {
    test('loads saved language on construction', () async {
      SharedPreferences.setMockInitialValues({
        'preferred_language': 'hi',
      });
      final p = AppProvider(ApiService());
      // Give _loadLanguage a tick to complete
      await Future.delayed(Duration.zero);
      expect(p.locale.languageCode, 'hi');
    });
  });

  // =========================================================================
  // Manual vitals entry (addVitalReading)
  // =========================================================================
  group('AppProvider — addVitalReading', () {
    test('vitalsHistory starts empty', () {
      expect(provider.vitalsHistory, isEmpty);
    });

    test('appends to history and updates latestVitals', () async {
      final api = _RecordingVitalsApi();
      final p = AppProvider(api);
      final reading = _bpReading();

      await p.addVitalReading(reading);

      expect(p.vitalsHistory, hasLength(1));
      expect(p.vitalsHistory.single.id, reading.id);
      expect(p.latestVitals?.systolic, 120);
      expect(p.latestVitals?.diastolic, 80);
    });

    test('notifies listeners synchronously (chart updates immediately)', () {
      final p = AppProvider(_RecordingVitalsApi());
      var notified = false;
      p.addListener(() => notified = true);

      // Intentionally NOT awaited — the local append + notify must happen
      // before the API post resolves.
      p.addVitalReading(_bpReading());

      expect(notified, isTrue);
      expect(p.vitalsHistory, hasLength(1));
    });

    test('attempts the API post with the reading', () async {
      final api = _RecordingVitalsApi();
      final p = AppProvider(api);

      await p.addVitalReading(_bpReading());

      expect(api.submittedPatientId, 'pat_demo_rajesh');
      expect(api.submittedReading?.systolic, 120);
    });

    test('keeps the reading locally when the API post fails (demo mode)',
        () async {
      final p = AppProvider(_FailingVitalsApi());

      // Must not throw — failure is tolerated (Log.warn) and local state kept.
      await p.addVitalReading(_bpReading(systolic: 135, diastolic: 88));

      expect(p.vitalsHistory, hasLength(1));
      expect(p.latestVitals?.systolic, 135);
    });

    test('an older reading does not displace a newer latestVitals', () async {
      final p = AppProvider(_RecordingVitalsApi());
      await p.addVitalReading(_bpReading(systolic: 124, diastolic: 82));

      final older = VitalReading(
        id: 'manual_test_old',
        patientId: 'pat_demo_rajesh',
        recordedAt: DateTime.now().subtract(const Duration(days: 2)),
        systolic: 110,
        diastolic: 70,
      );
      await p.addVitalReading(older);

      expect(p.vitalsHistory, hasLength(2));
      // History stays sorted oldest-first.
      expect(p.vitalsHistory.first.id, 'manual_test_old');
      // Latest remains the newer reading.
      expect(p.latestVitals?.systolic, 124);
    });

    test('dangerous reading classifies red via vital_classifier', () async {
      final p = AppProvider(_RecordingVitalsApi());
      await p.addVitalReading(_bpReading(systolic: 190, diastolic: 110));

      // Reuses vital_classifier.dart, so wherever latest-vitals status is
      // rendered (My Care, entry sheet) the entry shows its warning state.
      expect(classifyVital('bp_systolic', p.latestVitals!.systolic!), 'red');
    });

    test('normal reading classifies green via vital_classifier', () async {
      final p = AppProvider(_RecordingVitalsApi());
      await p.addVitalReading(_bpReading());

      expect(classifyVital('bp_systolic', p.latestVitals!.systolic!), 'green');
    });
  });
}
