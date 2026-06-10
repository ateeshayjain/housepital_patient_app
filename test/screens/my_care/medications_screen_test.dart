// test/screens/my_care/medications_screen_test.dart
//
// Widget tests for the Medications screen quick actions:
//  • weekly adherence header card (pct · doses line + day dots)
//  • low-stock "Request refill" button → session "Refill requested ✓" state
//
// Provider pattern copied from test/screens/overflow_smoke_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/care_event.dart';
import 'package:housepital_patient/models/medication_models.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/providers/medication_provider.dart';
import 'package:housepital_patient/screens/my_care/medications_screen.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/utils/app_localizations.dart';

class _TestAppProvider extends AppProvider {
  _TestAppProvider() : super(ApiService());

  @override
  Patient? get currentPatient => DemoData.patient;
  @override
  Future<void> loadPatients() async {}
  @override
  Future<void> loadDashboard() async {}
}

class _TestMedicationProvider extends MedicationProvider {
  _TestMedicationProvider() : super(ApiService());

  int refillCalls = 0;

  @override
  List<MedicationFull> get medications => DemoData.medications;
  @override
  List<MedicationFull> get activeMedications =>
      DemoData.medications.where((m) => m.isActive).toList();
  @override
  bool get isLoading => false;
  @override
  String? get error => null;

  @override
  Future<void> loadMedications(String patientId) async {}

  /// Skip the (demo-tolerant) concerns API call; just record + flip state.
  @override
  Future<bool> requestRefill(String patientId, MedicationFull med) async {
    refillCalls++;
    return super.requestRefill(patientId, med);
  }
}

Widget _host(MedicationProvider medProv) => MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: const [Locale('en')],
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: _TestAppProvider()),
          ChangeNotifierProvider<MedicationProvider>.value(value: medProv),
          ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
        ],
        child: const MedicationsScreen(),
      ),
    );

Future<void> _pump(WidgetTester tester, MedicationProvider medProv) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async {
    await tester.pumpWidget(_host(medProv));
    // Let the async AppLocalizations delegate finish loading.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows deterministic weekly adherence header card',
      (tester) async {
    await _pump(tester, _TestMedicationProvider());

    final pct = weeklyAdherencePercent();
    final weekTotal = dosesPerDay() * 7;
    final weekTaken = (weekTotal * pct / 100).round();
    expect(find.text("This week's adherence"), findsOneWidget);
    expect(
        find.text('$pct% · $weekTaken of $weekTotal doses'), findsOneWidget);
  });

  testWidgets(
      'low-stock med shows Request refill; tap flips to Refill requested ✓',
      (tester) async {
    final medProv = _TestMedicationProvider();
    await _pump(tester, medProv);

    // Demo data: Insulin Glargine (3 units left) is the low-stock med.
    expect(find.textContaining('refill soon'), findsOneWidget);
    expect(find.text('Request refill'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Request refill'));
      // The handler awaits the lazy catalog lookup + provider call.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // No catalog match for "Insulin Glargine" → concern path, not cart.
    expect(medProv.refillCalls, 1);
    expect(find.text('Refill requested ✓'), findsOneWidget);
    expect(find.text('Request refill'), findsNothing);
    expect(find.text('Refill request sent to your Health Manager'),
        findsOneWidget);
  });
}
