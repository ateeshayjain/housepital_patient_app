// test/screens/reports/vitals_screen_test.dart
//
// Widget tests for the manual vitals entry flow (owner request: "Add option
// to add vitals here" on Today's Vitals):
//  • The Add reading FAB opens the entry sheet pre-selected to the active tab.
//  • Entering 120/80 on the BP tab and saving shows the "Reading saved"
//    SnackBar and the chart screen's 'Latest reading' hero shows 120/80.
//  • Invalid input (out-of-range systolic) keeps the Save button disabled.
//
// Provider + pump pattern copied from test/screens/my_care_screen_test.dart
// (runAsync so the async AppLocalizations delegate resolves).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/config/theme.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/screens/reports/vitals_screen.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/utils/app_localizations.dart';

/// Vitals POST succeeds silently — keeps the widget test offline-safe
/// (the real client would open an HTTP connection / retry timer).
class _FakeApi extends ApiService {
  @override
  Future<void> submitVitalReading(
      String patientId, VitalReading reading) async {}
}

Widget _host(AppProvider app, {String? initialVital}) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: VitalsScreen(initialVital: initialVital),
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, AppProvider app,
    {String? initialVital}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async {
    await tester.pumpWidget(_host(app, initialVital: initialVital));
    // Async AppLocalizations delegate resolves during this delay…
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  });
  await tester.pump();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Must precede AppProvider construction (its ctor reads SharedPreferences).
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'BP tab: Add reading FAB opens the sheet, 120/80 saves, SnackBar and '
      'Latest reading hero update', (tester) async {
    final app = AppProvider(_FakeApi());
    await _pump(tester, app, initialVital: 'bp');

    // Entry point: extended FAB with the Add reading label.
    expect(find.text('Add reading'), findsOneWidget);
    await _openSheet(tester);

    // Sheet pre-selected to BP: both BP fields visible.
    expect(find.text('Systolic (mmHg)'), findsOneWidget);
    expect(find.text('Diastolic (mmHg)'), findsOneWidget);

    // Save is disabled until input is valid.
    final saveButton = find.widgetWithText(ElevatedButton, 'Save reading');
    expect(tester.widget<ElevatedButton>(saveButton).enabled, isFalse);

    await tester.enterText(find.byType(TextFormField).at(0), '120');
    await tester.enterText(find.byType(TextFormField).at(1), '80');
    await tester.pump();

    expect(tester.widget<ElevatedButton>(saveButton).enabled, isTrue);
    // Live status from vital_classifier: 120 systolic is green/Normal.
    expect(find.text('Normal'), findsOneWidget);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Confirmation SnackBar.
    expect(find.text('Reading saved'), findsOneWidget);

    // Provider state: history grew, latest updated.
    expect(app.vitalsHistory, hasLength(1));
    expect(app.latestVitals?.systolic, 120);
    expect(app.latestVitals?.diastolic, 80);

    // Chart screen reflects the new point immediately: the 'Latest reading'
    // hero shows the manual entry (newest by recordedAt).
    expect(find.text('120/80'), findsOneWidget);

    // Let the SnackBar's auto-dismiss timer expire (no pending timers).
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('period chips use a neutral selected state (C5 — not orange)',
      (tester) async {
    final app = AppProvider(_FakeApi());
    await _pump(tester, app);

    ChoiceChip chipFor(String label) =>
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

    // 7 Days is the default selection: neutral grey fill, dark w700 label —
    // these are VIEW filters, so no orange anywhere in the selected state.
    expect(chipFor('7 Days').selected, isTrue);
    expect(chipFor('7 Days').selectedColor, HousepitalColors.greyLighter);
    expect(chipFor('7 Days').checkmarkColor, HousepitalColors.black);
    expect(chipFor('7 Days').labelStyle?.color, HousepitalColors.black);
    expect(chipFor('7 Days').labelStyle?.fontWeight, FontWeight.w700);

    // Selection moves with the same neutral treatment.
    await tester.tap(find.text('30 Days'));
    await tester.pump();
    expect(chipFor('7 Days').selected, isFalse);
    expect(chipFor('30 Days').selected, isTrue);
    expect(chipFor('30 Days').selectedColor, HousepitalColors.greyLighter);
  });

  testWidgets('invalid input blocks save (out-of-range systolic)',
      (tester) async {
    final app = AppProvider(_FakeApi());
    await _pump(tester, app, initialVital: 'bp');
    await _openSheet(tester);

    final saveButton = find.widgetWithText(ElevatedButton, 'Save reading');

    // 261 mmHg systolic is above the 60–260 entry bound.
    await tester.enterText(find.byType(TextFormField).at(0), '261');
    await tester.enterText(find.byType(TextFormField).at(1), '80');
    await tester.pump();

    expect(tester.widget<ElevatedButton>(saveButton).enabled, isFalse);
    expect(find.text('Enter 60–260'), findsOneWidget);
    expect(app.vitalsHistory, isEmpty);

    // Correcting the value re-enables Save.
    await tester.enterText(find.byType(TextFormField).at(0), '130');
    await tester.pump();
    expect(tester.widget<ElevatedButton>(saveButton).enabled, isTrue);
  });

  testWidgets('dangerous entry shows its warning state in the sheet',
      (tester) async {
    final app = AppProvider(_FakeApi());
    await _pump(tester, app, initialVital: 'bp');
    await _openSheet(tester);

    // 190/110 — red per vital_classifier (bp_systolic >= 140).
    await tester.enterText(find.byType(TextFormField).at(0), '190');
    await tester.enterText(find.byType(TextFormField).at(1), '110');
    await tester.pump();

    expect(find.text('Needs attention'), findsOneWidget);
  });

  testWidgets('sheet pre-selects the currently active vital tab (Sugar)',
      (tester) async {
    final app = AppProvider(_FakeApi());
    await _pump(tester, app, initialVital: 'sugar');
    await _openSheet(tester);

    expect(find.text('Blood Sugar (mg/dL)'), findsOneWidget);
    expect(find.text('Systolic (mmHg)'), findsNothing);

    // Single-field vital: one value saves a sugar reading.
    await tester.enterText(find.byType(TextFormField), '145');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save reading'));
    await tester.pumpAndSettle();

    expect(app.vitalsHistory.single.sugar, 145);
    expect(app.latestVitals?.sugar, 145);

    await tester.pump(const Duration(seconds: 5));
  });
}
