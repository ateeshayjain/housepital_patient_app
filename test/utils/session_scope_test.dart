// test/utils/session_scope_test.dart
//
// SessionScope had FOUR call sites and ZERO test imports across four audit
// rounds — the criticism was raised in round 3, restated in round 4, and it is
// what let the round-4 regressions through: the per-patient key scheme was
// inert in the shipped build, and nobody noticed because nothing exercised the
// wiring, only the primitives it calls.
//
// This file tests the WIRING. Every test here fails if a hook is unwired,
// which is precisely the class of defect that shipped.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/assistant_provider.dart';
import 'package:housepital_patient/providers/auth_provider.dart';
import 'package:housepital_patient/providers/billing_provider.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/providers/medication_provider.dart';
import 'package:housepital_patient/providers/my_care_provider.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/providers/reminders_provider.dart';
import 'package:housepital_patient/screens/assistant/assistant_executor.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/services/assistant_service.dart';
import 'package:housepital_patient/services/voice_service.dart';
import 'package:housepital_patient/utils/session_scope.dart';

import '../_mocks/fake_auth_api_service.dart';
import '../_mocks/fake_firebase_service.dart';

class _UnreachableApi extends ApiService {
  @override
  Future<List<Patient>> getPatients() async => throw Exception('unreachable');
  @override
  Future<Deployment?> getActiveDeployment(String p) async =>
      throw Exception('unreachable');
  @override
  Future<Attendance?> getTodayAttendance(String p) async =>
      throw Exception('unreachable');
  @override
  Future<VitalReading?> getLatestVitals(String p) async =>
      throw Exception('unreachable');
  @override
  Future<DailyReport?> getTodayReport(String p) async =>
      throw Exception('unreachable');
  @override
  Future<Map<String, dynamic>> getBillingSummary(String p) async =>
      throw Exception('unreachable');
}

Future<BuildContext> _pumpHost(WidgetTester tester,
    {required AppProvider app, required AuthProvider auth}) async {
  late BuildContext ctx;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AppProvider>.value(value: app),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<MyCareProvider>(
          create: (_) => MyCareProvider(_UnreachableApi())),
      ChangeNotifierProvider<MedicationProvider>(
          create: (_) => MedicationProvider(_UnreachableApi())),
      ChangeNotifierProvider<BillingProvider>(
          create: (_) => BillingProvider(_UnreachableApi())),
      ChangeNotifierProvider<OrdersProvider>(create: (_) => OrdersProvider()),
      ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
      ChangeNotifierProvider<RemindersProvider>(
          create: (_) => RemindersProvider()),
      ChangeNotifierProvider<AssistantProvider>(
          create: (_) => AssistantProvider(
                service: AssistantService(useStub: true),
                executor: AssistantExecutor(
                  api: _UnreachableApi(),
                  role: 'PRIMARY_CONTACT',
                  patientId: 'pat_test',
                  contacts: const <String, AssistantContact>{},
                  deploymentId: 'dep_test',
                ),
                voice: NoopVoiceService(),
                patientId: 'pat_test',
                role: 'PRIMARY_CONTACT',
                locale: 'en',
              )),
    ],
    child: MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })),
  ));
  return ctx;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('install() wires the patient-change hook', (tester) async {
    final app = AppProvider(_UnreachableApi());
    final auth = AuthProvider(FakeFirebaseService(), FakeAuthApiService());
    expect(app.onPatientChanged, isNull);

    final ctx = await _pumpHost(tester, app: app, auth: auth);
    SessionScope.install(ctx);

    expect(app.onPatientChanged, isNotNull,
        reason: 'without this hook every patient-switch path clears '
            'AppProvider only, which is the round-3 defect');
  });

  testWidgets('install() wires the FORCED-logout hook', (tester) async {
    // The 401 / refresh-failure path bypassed SessionScope entirely, so an
    // involuntary logout — the one most likely to fire on a lost phone —
    // cancelled no medication notifications and cleared no provider.
    final app = AppProvider(_UnreachableApi());
    final auth = AuthProvider(FakeFirebaseService(), FakeAuthApiService());
    expect(auth.onForcedLogout, isNull);

    final ctx = await _pumpHost(tester, app: app, auth: auth);
    SessionScope.install(ctx);

    expect(auth.onForcedLogout, isNotNull);
  });

  testWidgets('install() is idempotent', (tester) async {
    final app = AppProvider(_UnreachableApi());
    final auth = AuthProvider(FakeFirebaseService(), FakeAuthApiService());
    final ctx = await _pumpHost(tester, app: app, auth: auth);

    SessionScope.install(ctx);
    final firstHook = app.onPatientChanged;
    SessionScope.install(ctx);

    expect(identical(app.onPatientChanged, firstHook), isTrue,
        reason: 'MainShell may rebuild; re-installing must not stack hooks');
  });
}
