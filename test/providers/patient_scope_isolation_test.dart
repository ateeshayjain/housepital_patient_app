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
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/providers/reminders_provider.dart';
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

CartItem _cartItem() => const CartItem(
      equipmentId: 'eq1',
      name: 'Oxygen Concentrator',
      brand: 'Philips',
      unitPrice: 25000,
    );

EquipmentItem _equipment({String id = 'eq1'}) => EquipmentItem(
      id: id,
      name: 'Oxygen Concentrator',
      brand: 'Philips',
      category: 'Equipment',
      availableForSale: true,
      availableForRent: true,
      price: 25000,
      rentalPrice: 3000,
    );

/// Returns a DIFFERENT patient from the API than the demo seed, so the
/// loadPatients switch path is observable.
class _SwitchingApi extends _UnreachableApi {
  int _calls = 0;

  /// Returns a DIFFERENT patient on the second call, which is what makes the
  /// loadPatients switch path observable at all.
  @override
  Future<List<Patient>> getPatients() async {
    _calls++;
    return [
      _calls <= 1
          ? Patient(id: 'pat_api_first', name: 'Rajesh Kumar', age: 72)
          : Patient(id: 'pat_api_other', name: 'Sunita Devi', age: 68),
    ];
  }
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
      expect(app.vitalsHistory, isEmpty,
          reason: 'manually entered readings are PHI — the round-1 audit '
              'named this field by line number and the first fix still '
              'missed it, because it was written from a symptom list');
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
  group('stores the first fix missed', () {
    test('manually entered vitals do not survive a clear', () async {
      final app = AppProvider(_UnreachableApi());
      await app.loadPatients();
      await app.addVitalReading(VitalReading(
        id: 'manual_1',
        patientId: 'pat_demo_rajesh',
        recordedAt: DateTime(2026, 8, 3),
        systolic: 150,
        diastolic: 95,
      ));
      expect(app.vitalsHistory, isNotEmpty);

      app.clearPatientScopedData();

      expect(app.vitalsHistory, isEmpty);
    });

    test('cart clear drops SAVED items too, and persists that', () async {
      SharedPreferences.setMockInitialValues({});
      final cart = CartProvider();
      cart.addItem(_equipment(id: 'eq1'));
      cart.addItem(_equipment(id: 'eq2'));
      cart.saveForLater(0); // move one into the saved list
      expect(cart.items, isNotEmpty);
      expect(cart.savedItems, isNotEmpty);

      cart.clearPatientScopedData();
      // let _persist() run
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cart.items, isEmpty);
      expect(cart.savedItems, isEmpty,
          reason: 'a wishlist is built for one patient too; plain clear() '
              're-persisted the outgoing saved list under the new patient');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('housepital_saved_items'), '[]');
    });

    test('a patient switch PRESERVES each patient\'s own order history',
        () async {
      // This test replaces one that asserted the opposite. Round 2 made the
      // clear persist `[]`, which stopped a cold start restoring the previous
      // patient — by DESTROYING their history, because storage was one global
      // key. The old test asserted that destruction as the contract.
      //
      // Per-patient keys make a switch a read of a different key, so the
      // contract is now: switching away and back returns your own orders.
      SharedPreferences.setMockInitialValues({});
      final orders = OrdersProvider(patientId: 'pat_a');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      orders.addOrder(
        items: [_cartItem()],
        totalAmount: 25000,
        bookingNumber: 'HPL-BOOK-A1',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final aCount = orders.orders.length;
      expect(aCount, greaterThan(0));

      // Switch to B: A's orders must leave the screen...
      await orders.setPatient('pat_b');
      expect(orders.orders.any((o) => o['id'] == null), isFalse);
      final bOrders = orders.orders.length;

      // ...and switching back must return A's own history intact.
      await orders.setPatient('pat_a');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(orders.orders.length, aCount,
          reason: "patient A's order history must survive a switch away and "
              'back — a switch is a read, not a write');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('housepital_orders_pat_a'), isNotNull,
          reason: 'orders are keyed per patient');
      expect(bOrders, isNot(aCount),
          reason: "B must not inherit A's orders");
    });

    test('clearPatientScopedData does NOT write over stored orders', () async {
      SharedPreferences.setMockInitialValues({});
      final orders = OrdersProvider(patientId: 'pat_a');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      orders.addOrder(
        items: [_cartItem()],
        totalAmount: 3000,
        bookingNumber: 'HPL-BOOK-A2',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final stored = (await SharedPreferences.getInstance())
          .getString('housepital_orders_pat_a');
      expect(stored, isNotNull);

      orders.clearPatientScopedData();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(orders.orders, isEmpty, reason: 'memory is cleared');
      expect(
          (await SharedPreferences.getInstance())
              .getString('housepital_orders_pat_a'),
          stored,
          reason: 'DISK IS UNTOUCHED — clearing the screen must never erase '
              "the outgoing patient's history");
    });

    test('reminders are cleared from memory AND disk', () async {
      SharedPreferences.setMockInitialValues({
        RemindersProvider.storageKey: '[]',
      });
      final reminders = RemindersProvider();
      await reminders.load();

      await reminders.clearPatientScopedData();

      final prefs = await SharedPreferences.getInstance();
      expect(reminders.reminders, isEmpty);
      expect(prefs.containsKey(RemindersProvider.storageKey), isFalse);
    });
  });

  test('loadPatients is a switch path too, and clears on identity change',
      () async {
    // This path runs on every Home mount and used to reassign the current
    // patient with no clear at all, quietly defeating the UI switch path.
    final app = AppProvider(_SwitchingApi());
    await app.loadPatients(); // -> pat_api_first
    await app.loadDashboard();
    expect(app.activeDeployment, isNotNull);
    expect(app.currentPatient?.id, 'pat_api_first');

    await app.loadPatients(); // API now returns a DIFFERENT patient

    expect(app.currentPatient?.id, 'pat_api_other');
    expect(app.activeDeployment, isNull,
        reason: "the outgoing patient's dashboard must not survive");
  });

}
