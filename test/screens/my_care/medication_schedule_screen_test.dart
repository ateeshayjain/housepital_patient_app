// test/screens/my_care/medication_schedule_screen_test.dart
//
// Widget tests for Today's Schedule single-tap dose logging:
//  • pending dose row shows the "Log dose" tonal pill
//  • staff-given row shows "Given <time> / by <staff>" and NO pill
//  • tapping the pill logs the dose via MedicationProvider and the row
//    flips to its given state (no navigation, no dialog)
//
// Provider pattern copied from medications_screen_test.dart; the REAL
// MedicationProvider is used (with the MockApiService stub) so the tap
// exercises the actual logDoseToday → _todayLogs → _buildSchedule pathway.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/medication_models.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/medication_provider.dart';
import 'package:housepital_patient/screens/my_care/medication_schedule_screen.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/utils/app_localizations.dart';

import '../../providers/mock_api_service.dart';

class _TestAppProvider extends AppProvider {
  _TestAppProvider() : super(ApiService());

  @override
  Patient? get currentPatient => DemoData.patient;
  @override
  Future<void> loadPatients() async {}
  @override
  Future<void> loadDashboard() async {}
}

MedicationFull _med({
  String id = 'm1',
  String name = 'Metformin',
  List<String> timeSlots = const ['08:00', '20:00'],
}) =>
    MedicationFull(
      id: id,
      patientId: 'pat_demo_rajesh',
      name: name,
      dosage: '500 mg',
      form: 'tablet',
      frequency: 'twice_daily',
      timeSlots: timeSlots,
      isActive: true,
    );

Widget _host(MedicationProvider medProv) => MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: const [Locale('en')],
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: _TestAppProvider()),
          ChangeNotifierProvider<MedicationProvider>.value(value: medProv),
        ],
        child: const MedicationScheduleScreen(),
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
    // Let the async AppLocalizations delegate + the initState microtask
    // (loadTodaySchedule) finish.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  // The async load's notifyListeners lands across pump boundaries — pump
  // until the schedule list is on screen (settle also runs the 200ms
  // AnimatedSwitcher to completion).
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiService mock;
  late MedicationProvider medProv;

  setUp(() {
    mock = MockApiService();
    medProv = MedicationProvider(mock);
  });

  testWidgets(
      'pending dose row shows the Log dose pill; staff-given row shows '
      'Given + staff name and no pill', (tester) async {
    final today = DateTime.now();
    mock.medicationsResult = [_med()];
    mock.medicationLogsResult = [
      MedicationLog(
        id: 'log1',
        medicationId: 'm1',
        staffName: 'Nurse Asha',
        scheduledTime: DateTime(today.year, today.month, today.day, 8, 0),
        actualTime: DateTime(today.year, today.month, today.day, 8, 5),
        status: 'administered',
      ),
    ];

    await _pump(tester, medProv);

    // 08:00 was administered by staff; only the 20:00 row is pending.
    expect(find.text('Log dose'), findsOneWidget);
    expect(find.text('by Nurse Asha'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Given ')), findsOneWidget);
  });

  testWidgets(
      'tapping Log dose logs the dose and the row flips to Given — '
      'no navigation, no dialog', (tester) async {
    mock.medicationsResult = [_med()];
    mock.medicationLogsResult = [];

    await _pump(tester, medProv);
    expect(find.text('Log dose'), findsNWidgets(2));

    await tester.tap(find.text('Log dose').first);
    await tester.pumpAndSettle();

    // Provider recorded the 08:00 dose (earliest slot renders first).
    expect(medProv.todayLogs, hasLength(1));
    expect(medProv.todayLogs.single.wasGiven, isTrue);
    expect(medProv.isDoseTakenToday('m1', '08:00'), isTrue);
    // Row flipped: one pill left, one Given row; still on this screen.
    expect(find.text('Log dose'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Given ')), findsOneWidget);
    expect(find.byType(MedicationScheduleScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Log dose pill exposes a per-med button semantics label',
      (tester) async {
    mock.medicationsResult = [_med(timeSlots: ['08:00'])];
    mock.medicationLogsResult = [];

    await _pump(tester, medProv);
    final handle = tester.ensureSemantics();
    await tester.pump();

    // Matched as a pattern: the label may merge with neighbouring row
    // semantics depending on ancestor merge boundaries.
    expect(find.bySemanticsLabel(RegExp('Log dose for Metformin')),
        findsOneWidget);
    handle.dispose();
  });
}
