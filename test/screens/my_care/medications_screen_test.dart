// test/screens/my_care/medications_screen_test.dart
//
// Widget tests for the Medications screen quick actions:
//  • weekly adherence header card (pct · doses line + day dots)
//  • single-tap "Log dose" pill → "Logged ✓" done state + header tick
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
import 'package:housepital_patient/widgets/care_pulse_ring.dart';

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
      // Stub route so the adherence-header tap → Care Calendar navigation is
      // observable without pulling in the real calendar screen's providers.
      routes: {
        '/care-calendar': (_) =>
            const Scaffold(body: Text('care-calendar-stub')),
      },
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

/// Expected header values: past 6 days seeded (adherencePercentFor), TODAY is
/// live provider state — [todayTaken] doses logged via the quick action.
({int weekTaken, int weekTotal, int pct}) _expectedHeader({int todayTaken = 0}) {
  final perDay = dosesPerDay();
  final weekTotal = perDay * 7;
  final today = dateOnly(DateTime.now());
  var weekTaken = todayTaken.clamp(0, perDay);
  for (var i = 1; i <= 6; i++) {
    weekTaken +=
        (perDay * adherencePercentFor(today.subtract(Duration(days: i))) / 100)
            .round();
  }
  return (
    weekTaken: weekTaken,
    weekTotal: weekTotal,
    pct: (weekTaken * 100 / weekTotal).round(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'shows deterministic weekly adherence header with % ring and dose count',
      (tester) async {
    await _pump(tester, _TestMedicationProvider());

    final h = _expectedHeader();
    expect(find.text("This week's adherence"), findsOneWidget);
    // The percentage now lives INSIDE the 56px progress ring…
    expect(find.text('${h.pct}%'), findsOneWidget);
    // …with a determinate CarePulseRing (the signature ring) at pct/100.
    final ring = tester.widgetList<CarePulseRing>(find.byType(CarePulseRing));
    expect(
        ring.where((r) => (r.value - h.pct / 100).abs() < 0.001), isNotEmpty);
    // Dose count is its own line now.
    expect(find.text('${h.weekTaken} of ${h.weekTotal} doses'), findsOneWidget);
  });

  // ── Single-tap dose logging (owner request) ────────────────────────────

  testWidgets('every scheduled med card shows a Log dose pill',
      (tester) async {
    await _pump(tester, _TestMedicationProvider());

    // All 5 demo meds are active with time slots.
    expect(find.text('Log dose'), findsNWidgets(5));
    expect(find.text('Logged ✓'), findsNothing);
  });

  testWidgets(
      'tapping Log dose logs the dose, morphs to Logged ✓ and ticks the '
      'adherence header', (tester) async {
    final medProv = _TestMedicationProvider();
    await _pump(tester, medProv);

    final before = _expectedHeader();
    expect(find.text('${before.weekTaken} of ${before.weekTotal} doses'),
        findsOneWidget);

    // First card is Amlodipine (single 08:00 slot) — one tap, no dialog,
    // no navigation.
    await tester.tap(find.text('Log dose').first);
    await tester.pumpAndSettle();

    expect(medProv.dosesMarkedTakenToday, 1);
    expect(medProv.isSlotLoggedToday('med_amlodipine', '08:00'), isTrue);
    // Single-slot med → pill morphs to the done state.
    expect(find.text('Logged ✓'), findsOneWidget);
    expect(find.text('Log dose'), findsNWidgets(4));
    // Still on the medications screen (no navigation happened).
    expect(find.text("This week's adherence"), findsOneWidget);
    // Adherence header dose line ticks (today's component is provider state).
    final after = _expectedHeader(todayTaken: 1);
    expect(find.text('${after.weekTaken} of ${after.weekTotal} doses'),
        findsOneWidget);
  });

  testWidgets(
      'multi-slot med shows logged count and keeps the pill until all '
      'slots are logged', (tester) async {
    final medProv = _TestMedicationProvider();
    await _pump(tester, medProv);

    // Metformin has 08:00 + 21:00 slots.
    medProv.logNextDoseToday('med_metformin');
    await tester.pumpAndSettle();
    expect(find.text('1/2 logged today'), findsOneWidget);
    expect(find.text('Log dose'), findsNWidgets(5)); // pill stays

    medProv.logNextDoseToday('med_metformin');
    await tester.pumpAndSettle();
    expect(find.text('Logged ✓'), findsOneWidget);
    expect(find.text('Log dose'), findsNWidgets(4));
  });

  testWidgets('Log dose pill exposes a per-med button semantics label',
      (tester) async {
    await _pump(tester, _TestMedicationProvider());
    final handle = tester.ensureSemantics();
    await tester.pump();

    // The per-med label merges into the card's tap-target node alongside the
    // card's own text, so match as a pattern rather than the exact string.
    expect(find.bySemanticsLabel(RegExp('Log dose for Amlodipine')),
        findsOneWidget);
    handle.dispose();
  });

  testWidgets('tapping the adherence header opens the Care Calendar',
      (tester) async {
    await _pump(tester, _TestMedicationProvider());

    await tester.tap(find.text("This week's adherence"));
    await tester.pumpAndSettle();

    expect(find.text('care-calendar-stub'), findsOneWidget);
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
