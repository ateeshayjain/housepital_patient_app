// test/providers/patient_scope_isolation_test.dart
//
// Regression guard for the PHI leak found by the Sync & Multi-Device audit
// (2026-08-03): switching the active patient, and logging out, left every
// provider's in-memory state untouched. Patient A's deployment, vitals,
// report, amount due, medications and orders kept rendering under patient B's
// name — in an app explicitly designed to be shared between a patient, a
// primary contact, and family members.
//
// These tests assert the CONTRACT, not the implementation: after a switch or a
// logout, nothing belonging to the previous patient may still be readable.
// If a provider gains new patient-scoped state, add it to SessionScope AND
// add an assertion here — the point of this file is that the next person
// cannot forget.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/data/demo_mode.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/billing_provider.dart';
import 'package:housepital_patient/providers/medication_provider.dart';
import 'package:housepital_patient/providers/my_care_provider.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/services/api_service.dart';

/// Every call fails, which is the real-world condition this app runs in today
/// (api.housepital.in does not resolve) and the condition under which the leak
/// was permanent: the API never overwrote the stale patient's data.
class _UnreachableApi extends ApiService {
  @override
  Future<Deployment?> getActiveDeployment(String patientId) async =>
      throw Exception('unreachable');
  @override
  Future<Attendance?> getTodayAttendance(String patientId) async =>
      throw Exception('unreachable');
  @override
  Future<VitalReading?> getLatestVitals(String patientId) async =>
      throw Exception('unreachable');
  @override
  Future<DailyReport?> getTodayReport(String patientId) async =>
      throw Exception('unreachable');
  @override
  Future<Map<String, dynamic>> getBillingSummary(String patientId) async =>
      throw Exception('unreachable');
}

Patient _otherPatient() => Patient(
      id: 'pat_other_sunita',
      name: 'Sunita Devi',
      age: 68,
      gender: 'F',
      address: 'A-1, Dwarka, Delhi',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppProvider patient scoping', () {
    test('clearPatientScopedData nulls every per-patient field', () async {
      final app = AppProvider(_UnreachableApi());
      await app.loadPatients();
      await app.loadDashboard();

      // Precondition: something is loaded for the first patient.
      expect(app.activeDeployment, isNotNull,
          reason: 'test is meaningless unless data was present first');

      app.clearPatientScopedData();

      expect(app.activeDeployment, isNull,
          reason: "previous patient's deployment must not survive");
      expect(app.todayAttendance, isNull);
      expect(app.latestVitals, isNull);
      expect(app.todayReport, isNull);
      expect(app.amountDue, 0,
          reason: 'an amount due under the wrong name is the most '
              'misleading value on the screen');
      expect(app.dueDate, isNull);
      expect(app.lastUpdatedText, isNull);
    });

    test('switchPatient clears before adopting the new patient', () async {
      final app = AppProvider(_UnreachableApi());
      await app.loadPatients();
      await app.loadDashboard();
      final firstPatientId = app.currentPatient?.id;

      app.switchPatient(_otherPatient());

      expect(app.currentPatient?.id, isNot(firstPatientId));
      expect(app.currentPatient?.id, 'pat_other_sunita');

      // NOTE ON WHAT THIS CAN AND CANNOT ASSERT: switchPatient clears and then
      // immediately calls loadDashboard, which re-seeds the demo fallback
      // because the backend is unreachable. So the fields are non-null again
      // by the time we look — but they are the NEW load's values, not the
      // outgoing patient's, and they are announced as sample data. The
      // clearing itself is asserted by the test above; what matters here is
      // that the freshly-loaded state is flagged as demo rather than passed
      // off as this patient's record.
      expect(app.lastUpdatedText, 'Demo data');
    });

    test('clearSession forgets the patient entirely', () async {
      final app = AppProvider(_UnreachableApi());
      await app.loadPatients();
      await app.loadDashboard();
      expect(app.currentPatient, isNotNull);

      app.clearSession();

      expect(app.currentPatient, isNull,
          reason: 'after logout the app must not know who the patient was');
      expect(app.patients, isEmpty);
      expect(app.activeDeployment, isNull);
      expect(app.amountDue, 0);
    });
  });

  group('per-patient providers clear their own data', () {
    test('MyCareProvider', () async {
      final p = MyCareProvider(_UnreachableApi());
      await p.loadMyCareData('pat_demo_rajesh');
      expect(p.activeServices, isNotEmpty);

      p.clearPatientScopedData();

      expect(p.activeServices, isEmpty);
      expect(p.healthManager, isNull);
      expect(p.error, isNull);
    });

    test('MedicationProvider clears doses and refill markers too', () async {
      final p = MedicationProvider(_UnreachableApi());
      await p.loadMedications('pat_demo_rajesh');
      expect(p.medications, isNotEmpty);

      p.clearPatientScopedData();

      expect(p.medications, isEmpty);
      expect(p.todayLogs, isEmpty);
    });

    test('BillingProvider', () async {
      final p = BillingProvider(_UnreachableApi());
      await p.loadBillingSummary('pat_demo_rajesh');

      p.clearPatientScopedData();

      expect(p.amountDue, 0);
      expect(p.dueDate, isNull);
    });

    test('OrdersProvider', () async {
      final p = OrdersProvider();
      // Constructor loads from storage and seeds demo orders in memory when
      // persistence is empty; give that microtask a turn.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(p.orders, isNotEmpty,
          reason: 'demo orders seed in memory so the clear is observable');

      p.clearPatientScopedData();

      expect(p.orders, isEmpty);
      expect(p.assessments, isEmpty);
    });
  });

  test('demo data is announced, not silently substituted', () async {
    // The other half of the same problem: falling back to sample records is
    // fine, presenting them as the patient's own is not. The shell renders a
    // banner off this flag, so it is the difference between an honest
    // fallback and a patient reading someone else's chart as their own.
    DemoMode.reset();
    final app = AppProvider(_UnreachableApi());
    await app.loadPatients();
    await app.loadDashboard();

    expect(app.activeDeployment, isNotNull,
        reason: 'precondition: the demo fallback ran');
    expect(app.lastUpdatedText, 'Demo data');
    expect(DemoMode.isServingDemoData.value, isTrue,
        reason: 'serving sample data without saying so is the bug');
  });
}
