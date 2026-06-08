// test/screens/overflow_smoke_test.dart
//
// Screen-level OVERFLOW smoke tests.
//
// Why this exists: a "BOTTOM OVERFLOWED" stripe shipped on the My Care
// "Today's Vitals" strip even though analyzer was clean and 1408 tests passed.
// The reason it slipped through: the other screen tests pump on a deliberately
// huge surface (1080x4000) "so all sections lay out without overflow" — which
// is exactly why they can never catch an overflow. A 4000px-tall canvas has
// room no real phone has.
//
// This file does the opposite: it pumps each screen at REAL phone sizes and
// fails if Flutter reports ANY RenderFlex overflow. Flutter reports overflow
// via FlutterError.onError during paint, which flutter_test surfaces through
// tester.takeException() — so the assertion is simply "no exception after a
// pump at a phone-sized surface".
//
// Critically, My Care is pumped WITH vitals + active services present, because
// the overflowing strip is gated behind `if (app.latestVitals != null)` — the
// exact path the isolated widget tests never exercised.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/models/my_care_models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/providers/medication_provider.dart';
import 'package:housepital_patient/providers/my_care_provider.dart';
import 'package:housepital_patient/screens/home/home_screen.dart';
import 'package:housepital_patient/screens/my_care/my_care_screen.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/utils/app_localizations.dart';

// Real phone logical sizes (devicePixelRatio pinned to 1.0 so physical ==
// logical). Smallest first — the iPhone SE is where vertical strips overflow.
const Map<String, Size> _phoneSizes = {
  'small  320x568 (SE)': Size(320, 568),
  'std    375x667 (8)': Size(375, 667),
  'large  414x896 (11)': Size(414, 896),
};

// ── Test providers: seed demo data synchronously, neutralise I/O loaders ─────

class _TestAppProvider extends AppProvider {
  _TestAppProvider() : super(ApiService());

  @override
  Patient? get currentPatient => DemoData.patient;
  @override
  List<Patient> get patients => [DemoData.patient];
  @override
  Deployment? get activeDeployment => DemoData.icuDeployment;
  @override
  bool get isDashboardLoading => false;
  // The two getters that gate the overflowing My Care sections:
  @override
  VitalReading? get latestVitals => DemoData.vitalsHistory.last;
  @override
  DailyReport? get todayReport => DemoData.todayReport;

  @override
  Future<void> loadPatients() async {}
  @override
  Future<void> loadDashboard() async {}
}

class _TestMyCareProvider extends MyCareProvider {
  _TestMyCareProvider() : super(ApiService());

  @override
  List<ActiveService> get activeServices => DemoData.activeServices;
  @override
  bool get hasActiveServices => true;
  @override
  HealthManager? get healthManager => DemoData.healthManager;
  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  bool get isStale => false;

  @override
  Future<void> loadMyCareData(String patientId) async {}
}

Widget _homeHost(AppProvider app) => _wrap(
      MultiProvider(
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

Widget _myCareHost(AppProvider app, MyCareProvider myCare) => _wrap(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: app),
          ChangeNotifierProvider<MyCareProvider>.value(value: myCare),
        ],
        child: const MyCareScreen(),
      ),
    );

// disableAnimations:true stops the Home banner auto-scroll Timer.periodic from
// starting, keeping the pump deterministic.
Widget _wrap(Widget home) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: home,
      ),
    );

/// Pumps [app] at [size] and returns the first overflow/layout exception (or
/// null). Mirrors the runAsync+pump pattern used by the other screen tests so
/// the async AppLocalizations delegate and real timers behave.
Future<Object?> _exceptionAt(
    WidgetTester tester, Widget Function() build, Size size) async {
  // Set the SharedPreferences mock BEFORE building, because the providers'
  // constructors call SharedPreferences.getInstance — building eagerly in the
  // caller would run that before the mock exists (order-dependent crash).
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async {
    await tester.pumpWidget(build());
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
  return tester.takeException();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _phoneSizes.forEach((label, size) {
    testWidgets('Home lays out without overflow — $label', (tester) async {
      final ex =
          await _exceptionAt(tester, () => _homeHost(_TestAppProvider()), size);
      expect(ex, isNull,
          reason: 'Home overflowed at $size — a RenderFlex exceeded its box.');
    });

    testWidgets('My Care (with vitals) lays out without overflow — $label',
        (tester) async {
      final ex = await _exceptionAt(tester,
          () => _myCareHost(_TestAppProvider(), _TestMyCareProvider()), size);
      expect(ex, isNull,
          reason: 'My Care overflowed at $size — likely the Today\'s Vitals '
              'strip (fixed-height row vs. taller pill content).');
    });
  });
}
