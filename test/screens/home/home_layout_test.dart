// test/screens/home/home_layout_test.dart
//
// Layout-order characterization tests for the Home screen (Layout B).
//
// Goal: pin the vertical ordering of the major Home sections.
//   - The "Your Health Team" card must render ABOVE the hero banner.
//   - With an active deployment the team card shows the Health Manager row
//     and the on-duty staff row.
//
// Harness: HomeScreen reads AppProvider, CartProvider and MedicationProvider
// and uses AppLocalizations. We inject a test AppProvider that seeds a demo
// deployment + patient directly and overrides the network-touching loaders so
// the widget under test renders deterministically without any I/O.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/providers/medication_provider.dart';
import 'package:housepital_patient/screens/home/home_screen.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/utils/app_localizations.dart';
import 'package:housepital_patient/utils/permissions.dart';

// ── Test AppProvider ────────────────────────────────────────────────────────
// Seeds a demo patient + active deployment synchronously and neutralises the
// async loaders so HomeScreen's initState microtask performs no network I/O.
class _TestAppProvider extends AppProvider {
  _TestAppProvider() : super(ApiService());

  final Patient _patient = DemoData.patient;
  final Deployment _deployment = DemoData.icuDeployment;

  @override
  Patient? get currentPatient => _patient;

  @override
  List<Patient> get patients => [_patient];

  @override
  Deployment? get activeDeployment => _deployment;

  @override
  bool get isDashboardLoading => false;

  @override
  Future<void> loadPatients() async {}

  @override
  Future<void> loadDashboard() async {}
}

Widget _host(AppProvider app) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: app),
        ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
        ChangeNotifierProvider<MedicationProvider>(
          create: (_) => MedicationProvider(ApiService()),
        ),
      ],
      child: const HomeScreen(),
    ),
  );
}

Future<void> _pumpHome(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final app = _TestAppProvider();
  // Use a generously sized surface so all sections lay out without overflow.
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async {
    await tester.pumpWidget(_host(app));
    // Let the async AppLocalizations delegate finish loading.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Health Team card renders above the hero banner',
      (tester) async {
    await _pumpHome(tester);

    // "Your Health Team" appears twice (section label + card header). The
    // section label is rendered first in the column, so .first marks the top
    // of the team section.
    final teamY = tester.getTopLeft(find.text('Your Health Team').first).dy;

    // Hero banner first-slide copy. The carousel lazily builds, so the first
    // slide ("Hospital-like expertise. / Home-like care.") is the reliable
    // marker for the hero's vertical position.
    final heroFinder = find.textContaining('Home-like care');
    expect(heroFinder, findsWidgets);
    final heroY = tester.getTopLeft(heroFinder.first).dy;

    expect(teamY, lessThan(heroY),
        reason: 'Layout B: team must be above hero');
  });

  testWidgets('Health Team card shows manager + on-duty staff', (tester) async {
    await _pumpHome(tester);

    // Rendered twice: section label + card header.
    expect(find.text('Your Health Team'), findsWidgets);
    expect(find.text('Health Manager'), findsOneWidget); // role label
    expect(find.textContaining('Nurse'), findsWidgets); // on-duty staff role
  });

  // ── Book Services grid ────────────────────────────────────────────────────

  testWidgets('Book Services grid renders contextual + utility tiles',
      (tester) async {
    // _TestAppProvider seeds icuDeployment (staffRole: 'Critical Care Nurse'),
    // so the dynamic grid shows "My Nurse" (not "Book Nurse"), and adds
    // Care Guides. Static tiles (Equipment, Lab Tests, Doctor Visit, My Orders,
    // SOS) are always visible.
    await _pumpHome(tester);

    expect(find.text('My Nurse'), findsOneWidget); // contextual: nurse active
    expect(find.text('Book Nurse'), findsNothing); // replaced by My Nurse
    expect(find.text('Equipment'), findsOneWidget);
    expect(find.text('Lab Tests'), findsOneWidget);
    expect(find.text('Doctor Visit'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('My Orders'), findsOneWidget);
    expect(find.text('Care Guides'), findsOneWidget); // added in dynamic grid
  });

  testWidgets('Book Services section is hidden for view-only roles',
      (tester) async {
    // PATIENT_SELF role cannot book — Book Services should be hidden.
    SharedPreferences.setMockInitialValues({});
    final appPatientSelf = _TestAppProviderPatientSelf();
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await tester.pumpWidget(_host(appPatientSelf));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // PATIENT_SELF sees the call-caregiver card, NOT the services grid.
    expect(find.text('Book Nurse'), findsNothing);
  });
}

// ── Additional test providers ───────────────────────────────────────────────

/// Provider simulating a PATIENT_SELF role — cannot book services.
class _TestAppProviderPatientSelf extends AppProvider {
  _TestAppProviderPatientSelf() : super(ApiService());

  @override
  Patient? get currentPatient => DemoData.patient;
  @override
  List<Patient> get patients => [DemoData.patient];
  @override
  Deployment? get activeDeployment => DemoData.icuDeployment;
  @override
  bool get isDashboardLoading => false;
  @override
  String get currentUserRole => UserRole.patientSelf;
  @override
  Future<void> loadPatients() async {}
  @override
  Future<void> loadDashboard() async {}
}
