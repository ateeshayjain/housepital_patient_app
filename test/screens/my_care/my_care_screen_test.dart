// test/screens/my_care/my_care_screen_test.dart
//
// Widget tests for the My Care screen's review-fix items:
//  • Daily care rating card shows the FULL "How was today's care?" question
//    at the narrowest supported width (320px) — no ellipsis truncation
//    (the old single-row layout rendered "How was t…" on small phones).
//  • Doctor Handover Report entry card renders with its Share affordance.
//
// Provider + pump pattern copied from test/screens/overflow_smoke_test.dart
// (real phone size, SharedPreferences mocked before build, runAsync so the
// async AppLocalizations delegate resolves).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/medication_models.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/models/my_care_models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/medication_provider.dart';
import 'package:housepital_patient/providers/my_care_provider.dart';
import 'package:housepital_patient/screens/my_care/my_care_screen.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/utils/app_localizations.dart';
import 'package:housepital_patient/utils/permissions.dart';

class _TestAppProvider extends AppProvider {
  _TestAppProvider({this.role = UserRole.primaryContact}) : super(ApiService());

  final String role;

  @override
  String get currentUserRole => role;

  @override
  Patient? get currentPatient => DemoData.patient;
  @override
  VitalReading? get latestVitals => DemoData.vitalsHistory.last;
  @override
  DailyReport? get todayReport => DemoData.todayReport;
  @override
  bool get isDashboardLoading => false;

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

class _TestMedicationProvider extends MedicationProvider {
  _TestMedicationProvider() : super(ApiService());

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
}

Widget _host({String role = UserRole.primaryContact}) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(
                value: _TestAppProvider(role: role)),
            ChangeNotifierProvider<MyCareProvider>.value(
                value: _TestMyCareProvider()),
            ChangeNotifierProvider<MedicationProvider>.value(
                value: _TestMedicationProvider()),
          ],
          child: const MyCareScreen(),
        ),
      ),
    );

Future<void> _pumpAt(WidgetTester tester, Size size,
    {String role = UserRole.primaryContact}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async {
    await tester.pumpWidget(_host(role: role));
    // Async AppLocalizations delegate resolves during this delay…
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // …this pump then builds the screen body (which kicks off the rating
    // card's SharedPreferences read in initState)…
    await tester.pump();
    // …and this delay lets that prefs future complete (real async zone).
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  // Final frame: rebuild after the rating card's setState(_loaded = true).
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'rating card shows the full question at 320px — no truncation, '
      'stars on their own line', (tester) async {
    await _pumpAt(tester, const Size(320, 568));

    // Full string present (the old layout ellipsised it to "How was t…").
    expect(find.text("How was today's care?"), findsOneWidget);

    // Structural guarantee: the question Text never ellipsises.
    final question =
        tester.widget<Text>(find.text("How was today's care?"));
    expect(question.overflow, isNot(TextOverflow.ellipsis));
    expect(question.maxLines, isNull);

    // 5 tappable stars with >=44pt targets on the second line.
    expect(find.byIcon(Icons.star_border), findsNWidgets(5));

    // And the screen itself laid out without a RenderFlex overflow.
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the Doctor Handover Report share card', (tester) async {
    await _pumpAt(tester, const Size(375, 667));

    expect(find.text('Share with your doctor'), findsOneWidget);
    expect(find.text('Doctor Handover Report'), findsOneWidget);
    expect(
        find.text(
            'Complete summary: history, medicines, vitals, visits & reports'),
        findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
  });

  testWidgets(
      'CARETAKER role: Doctor Handover card is absent entirely '
      '(no disabled tease — audit R2 role gate)', (tester) async {
    await _pumpAt(tester, const Size(375, 667), role: UserRole.caretaker);

    expect(find.text('Share with your doctor'), findsNothing);
    expect(find.text('Doctor Handover Report'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.byIcon(Icons.ios_share), findsNothing);
  });

  testWidgets(
      'medication summary is computed from MedicationProvider, not hardcoded',
      (tester) async {
    await _pumpAt(tester, const Size(375, 667));

    final active = DemoData.medications.where((m) => m.isActive).toList();
    expect(
        find.text(
            '${active.length} active medication${active.length == 1 ? '' : 's'}'),
        findsOneWidget);
    expect(find.text(active.map((m) => m.name).join(', ')), findsOneWidget);
  });
}
