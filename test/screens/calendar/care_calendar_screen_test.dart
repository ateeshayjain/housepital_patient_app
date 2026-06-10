// test/screens/calendar/care_calendar_screen_test.dart
//
// Widget tests for the Care Calendar screen. Provider pattern copied from
// test/screens/overflow_smoke_test.dart: seed demo data synchronously and
// neutralise the network loaders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/care_event.dart';
import 'package:housepital_patient/models/medication_models.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/medication_provider.dart';
import 'package:housepital_patient/screens/calendar/care_calendar_screen.dart';
import 'package:housepital_patient/services/api_service.dart';

class _TestAppProvider extends AppProvider {
  _TestAppProvider() : super(ApiService());

  @override
  Patient? get currentPatient => DemoData.patient;
  @override
  List<Patient> get patients => [DemoData.patient];
  @override
  Future<void> loadPatients() async {}
  @override
  Future<void> loadDashboard() async {}
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
  @override
  Future<void> loadTodaySchedule(String patientId) async {}
}

Widget _host() => MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: _TestAppProvider()),
        ChangeNotifierProvider<MedicationProvider>.value(
            value: _TestMedicationProvider()),
      ],
      child: const MaterialApp(home: CareCalendarScreen()),
    );

Future<void> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  // Tall surface so the full month grid + detail sections are hit-testable
  // without scrolling.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_host());
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = dateOnly(DateTime.now());

  testWidgets('Month view renders grid, legend and today sections',
      (tester) async {
    await _pump(tester);

    // App bar + month title.
    expect(find.text('Care Calendar'), findsOneWidget);
    expect(find.text(DateFormat('MMMM yyyy').format(today)), findsOneWidget);

    // Weekday header letters (M/T/W/T/F/S/S — duplicates expected).
    expect(find.text('M'), findsWidgets);
    expect(find.text('W'), findsWidgets);

    // Today's cell exists in the grid.
    expect(
      find.byKey(
          ValueKey('cal-day-${today.year}-${today.month}-${today.day}')),
      findsOneWidget,
    );

    // Legend line + category chips.
    expect(find.textContaining('A dot marks a day with events'),
        findsOneWidget);
    for (final chip in ['Meds', 'Staff', 'Visit', 'Test', 'Renewal']) {
      expect(find.text(chip), findsOneWidget);
    }

    // Today's detail: staff attendance + interactive dose list.
    expect(find.text('Staff attendance'), findsOneWidget);
    expect(find.textContaining('staff present'), findsWidgets);
    expect(find.text("Today's doses"), findsOneWidget);
    expect(find.text('Mark taken'), findsWidgets);
  });

  testWidgets('Tapping the future day with the doctor visit shows Follow-up',
      (tester) async {
    await _pump(tester);

    final target = DateTime(today.year, today.month, today.day + 3);
    // If +3 days rolls into next month, page the grid forward first.
    if (target.month != today.month) {
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(
        ValueKey('cal-day-${target.year}-${target.month}-${target.day}')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Follow-up'), findsWidgets);
    expect(find.textContaining('Dr. Ananya Sharma'), findsWidgets);
    expect(find.text('Upcoming'), findsWidgets);
    expect(find.text('Visits, tests & renewals'), findsOneWidget);
  });

  testWidgets('Mark taken flips a dose to Taken via MedicationProvider',
      (tester) async {
    await _pump(tester);

    expect(find.text('Taken'), findsNothing);
    await tester.tap(find.text('Mark taken').first);
    await tester.pumpAndSettle();

    expect(find.text('Taken'), findsOneWidget);
    expect(find.textContaining('1/'), findsWidgets); // "1/6 taken" summary
  });

  testWidgets('Day/Week/Month segmented switching does not throw',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Week view shows the legend + a 7-day strip with today's cell.
    expect(find.textContaining('A dot marks a day with events'),
        findsOneWidget);
    expect(
      find.byKey(
          ValueKey('cal-day-${today.year}-${today.month}-${today.day}')),
      findsOneWidget,
    );

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Day view: detail only, with the date title.
    expect(find.text(DateFormat('EEEE, d MMMM').format(today)),
        findsOneWidget);
    expect(find.textContaining('A dot marks a day with events'),
        findsNothing);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(DateFormat('MMMM yyyy').format(today)), findsOneWidget);

    // 'Today' + chevrons keep working after view switches.
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(DateFormat('MMMM yyyy').format(today)), findsOneWidget);
  });
}
