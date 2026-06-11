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

import 'package:housepital_patient/config/theme.dart';
import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/care_event.dart';
import 'package:housepital_patient/models/medication_models.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/medication_provider.dart';
import 'package:housepital_patient/providers/reminders_provider.dart';
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

Widget _host({RemindersProvider? reminders}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppProvider>.value(value: _TestAppProvider()),
    ChangeNotifierProvider<MedicationProvider>.value(
      value: _TestMedicationProvider(),
    ),
    ChangeNotifierProvider<RemindersProvider>.value(
      value: reminders ?? (RemindersProvider()..load()),
    ),
  ],
  child: const MaterialApp(home: CareCalendarScreen()),
);

Future<void> _pump(WidgetTester tester, {RemindersProvider? reminders}) async {
  if (reminders == null) SharedPreferences.setMockInitialValues({});
  // Tall surface so the full month grid + detail sections are hit-testable
  // without scrolling.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_host(reminders: reminders));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = dateOnly(DateTime.now());

  testWidgets('Month view renders grid, legend and today sections', (
    tester,
  ) async {
    await _pump(tester);

    // App bar + month title.
    expect(find.text('Care Calendar'), findsOneWidget);
    expect(find.text(DateFormat('MMMM yyyy').format(today)), findsOneWidget);

    // Weekday header letters (M/T/W/T/F/S/S — duplicates expected).
    expect(find.text('M'), findsWidgets);
    expect(find.text('W'), findsWidgets);

    // Today's cell exists in the grid.
    expect(
      find.byKey(ValueKey('cal-day-${today.year}-${today.month}-${today.day}')),
      findsOneWidget,
    );

    // Legend line + category chips.
    expect(
      find.textContaining('A dot marks a day with events'),
      findsOneWidget,
    );
    for (final chip in [
      'Meds',
      'Staff',
      'Visit',
      'Test',
      'Renewal',
      'Reminder',
    ]) {
      expect(find.text(chip), findsOneWidget);
    }

    // Today's detail: staff attendance + interactive dose list.
    expect(find.text('Staff attendance'), findsOneWidget);
    expect(find.textContaining('confirmed present'), findsWidgets);
    expect(find.text('Mark present'), findsWidgets); // per-staff action
    expect(find.text("Today's doses"), findsOneWidget);
    expect(find.text('Mark taken'), findsWidgets);
    // Doses are grouped by time of day (demo meds span 07:00–22:00 slots)
    // via the shared DayPartHeader motif.
    expect(find.text('Morning · Subah'), findsOneWidget);
    expect(find.text('Evening · Raat'), findsOneWidget);
  });

  testWidgets('Tapping the future day with the doctor visit shows Follow-up', (
    tester,
  ) async {
    await _pump(tester);

    final target = DateTime(today.year, today.month, today.day + 3);
    // If +3 days rolls into next month, page the grid forward first.
    if (target.month != today.month) {
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
    }

    await tester.tap(
      find.byKey(
        ValueKey('cal-day-${target.year}-${target.month}-${target.day}'),
      ),
    );
    await tester.pumpAndSettle();

    // The legend teaching sentence disappears after the first day-tap
    // (the category chips stay).
    expect(find.textContaining('A dot marks a day with events'), findsNothing);
    expect(find.text('Meds'), findsOneWidget);

    expect(find.textContaining('Follow-up'), findsWidgets);
    expect(find.textContaining('Dr. Ananya Sharma'), findsWidgets);
    expect(find.text('Upcoming'), findsWidgets);
    expect(find.text('Visits, tests & renewals'), findsOneWidget);

    // The "N doses scheduled" card is tappable: expands to the full
    // scheduled-dose breakdown (no dead-end summaries).
    expect(find.textContaining('Amlodipine'), findsNothing);
    await tester.tap(find.textContaining('doses scheduled'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Amlodipine'), findsWidgets);
    expect(find.text('Morning · Subah'), findsOneWidget);
  });

  testWidgets('Mark taken flips a dose to Taken via MedicationProvider', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Taken'), findsNothing);
    await tester.tap(find.text('Mark taken').first);
    await tester.pumpAndSettle();

    expect(find.text('Taken'), findsOneWidget);
    expect(find.textContaining('1/'), findsWidgets); // "1/6 taken" summary
  });

  testWidgets('Day/Week/Month/Year segmented switching does not throw', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Week view = 7 vertical day cards (reference layout) + legend; the old
    // month grid cells are gone.
    final monday = today.subtract(Duration(days: today.weekday - 1));
    for (var i = 0; i < 7; i++) {
      final d = DateTime(monday.year, monday.month, monday.day + i);
      expect(
        find.byKey(ValueKey('week-card-${d.year}-${d.month}-${d.day}')),
        findsOneWidget,
      );
    }
    expect(
      find.textContaining('A dot marks a day with events'),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('cal-day-${today.year}-${today.month}-${today.day}')),
      findsNothing,
    );

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Day view: detail only, with the date title.
    expect(find.text(DateFormat('EEEE, d MMMM').format(today)), findsOneWidget);
    expect(find.textContaining('A dot marks a day with events'), findsNothing);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(DateFormat('MMMM yyyy').format(today)), findsOneWidget);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('${today.year}'), findsOneWidget);

    // C5 calm pass: the selected thumb is a NEUTRAL grey wash (primary-text
    // token at 8%), never orange — view switching is not an action.
    final thumb = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('Year'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(
      (thumb.decoration as BoxDecoration?)?.color,
      HousepitalColors.black.withValues(alpha: 0.08),
      reason: 'Segmented thumb must be the neutral grey token, not orange.',
    );

    // 'Today' + chevrons keep working after view switches.
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(DateFormat('MMMM yyyy').format(today)), findsOneWidget);
  });

  testWidgets(
    'Week view: 7 day cards with previews, +N more, and card → Day view',
    (tester) async {
      // Seed 3 reminders on today so today's card overflows its 4 preview
      // lines (meds + staff + 3 reminders = 5 events).
      SharedPreferences.setMockInitialValues({});
      final reminders = RemindersProvider();
      await reminders.load();
      await reminders.add(title: 'Rem A', date: today, time: '09:00');
      await reminders.add(title: 'Rem B', date: today, time: '10:00');
      await reminders.add(title: 'Rem C', date: today, time: '11:00');
      await _pump(tester, reminders: reminders);

      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();

      // Preview lines on today's card: seeded events first, then reminders.
      expect(find.text('Medicine adherence'), findsWidgets);
      expect(find.text('Rem A'), findsOneWidget);
      expect(find.text('Rem B'), findsOneWidget);
      // 5th event collapses into the overflow line.
      expect(find.text('Rem C'), findsNothing);
      expect(find.text('+1 more'), findsOneWidget);

      // Tapping a day card opens Day view for that date.
      await tester.tap(
        find.byKey(
          ValueKey('week-card-${today.year}-${today.month}-${today.day}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Today's doses"), findsOneWidget);
      expect(find.text('Reminders & to-dos'), findsOneWidget);
      expect(find.text('Rem C'), findsOneWidget); // full list in detail
      expect(find.text('+1 more'), findsNothing);
    },
  );

  testWidgets('Year view: 12 mini-months, year stepping, tap lands on Month', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();

    expect(find.text('${today.year}'), findsOneWidget);
    for (var m = 1; m <= 12; m++) {
      expect(find.byKey(ValueKey('year-month-$m')), findsOneWidget);
    }
    expect(find.text('January'), findsOneWidget);
    expect(find.text('December'), findsOneWidget);

    // Chevrons step whole years; Today returns to the current year.
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('${today.year + 1}'), findsOneWidget);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('${today.year}'), findsOneWidget);

    // Tapping a mini-month switches to Month view of that month.
    await tester.tap(find.text('March'));
    await tester.pumpAndSettle();
    expect(
      find.text(DateFormat('MMMM yyyy').format(DateTime(today.year, 3))),
      findsOneWidget,
    );
    // Month grid is back (weekday header letters).
    expect(find.text('W'), findsWidgets);
  });

  testWidgets('Week and Year views lay out at 320px without overflow', (
    tester,
  ) async {
    // Ahem worst-case at the narrowest supported width: any RenderFlex
    // overflow in the day cards / mini-months throws and fails the test.
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick-add reminder: sheet → day detail + dot, then delete', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    await tester.tap(find.byTooltip('Add reminder'));
    await tester.pumpAndSettle();
    expect(find.text('Add reminder'), findsOneWidget);

    // Save is disabled until a title is entered.
    final saveButton = find.widgetWithText(ElevatedButton, 'Save reminder');
    expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Buy batteries');
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Lands in the selected day's detail with its own section.
    expect(find.text('Reminders & to-dos'), findsOneWidget);
    expect(find.text('Buy batteries'), findsOneWidget);

    // Today's grid cell now announces the reminder dot category.
    final cell = tester.getSemantics(
      find.byKey(ValueKey('cal-day-${today.year}-${today.month}-${today.day}')),
    );
    expect(cell.label, contains('reminder'));

    // Trailing delete removes it again (scroll the card into view first —
    // the reminders section sits below the dose list on the tall page).
    await tester.ensureVisible(find.byTooltip('Delete reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete reminder'));
    await tester.pumpAndSettle();
    expect(find.text('Buy batteries'), findsNothing);
    expect(find.text('Reminders & to-dos'), findsNothing);

    semantics.dispose();
  });
}
