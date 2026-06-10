// test/screens/settings/patient_profile_test.dart
//
// Tests PatientProfileScreen's read-only Medical History section — the
// supervisor-recorded deployment-wizard data surfaced to the family:
//   - 'Medical History' header renders
//   - supervisor caption ('Recorded by your supervisor at deployment · synced')
//   - diagnosis text from DemoData.medicalHistory
//   - a condition chip + a dietary-restriction chip
//   - booleans rendered as Yes/No (never raw true/false)
//
// Provider/localization pump pattern copied from
// test/screens/my_care/medications_screen_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/screens/settings/patient_profile_screen.dart';
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

Widget _host() => MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: const [Locale('en')],
      home: ChangeNotifierProvider<AppProvider>.value(
        value: _TestAppProvider(),
        child: const PatientProfileScreen(),
      ),
    );

Future<void> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async {
    await tester.pumpWidget(_host());
    // Let the async AppLocalizations delegate finish loading.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PatientProfileScreen — Medical History (read-only)', () {
    testWidgets('renders header, supervisor caption, diagnosis and chips',
        (tester) async {
      await _pump(tester);

      // Section header.
      expect(find.text('Medical History'), findsOneWidget);

      // Supervisor sync caption.
      expect(
          find.text('Recorded by your supervisor at deployment · synced'),
          findsOneWidget);

      // Diagnosis from DemoData.medicalHistory.
      expect(find.text('Ischemic stroke — right hemiparesis'), findsOneWidget);

      // A condition chip. ('Hypertension' also appears nowhere else on this
      // screen — the editable conditions use the patient's own list, which
      // includes 'Hypertension' too, so assert on 'Stroke' which is unique
      // to the medical-history chips.)
      expect(find.text('Stroke'), findsOneWidget);

      // A dietary restriction chip.
      expect(find.text('Diabetic Diet'), findsOneWidget);
    });

    testWidgets('renders detail rows with Yes/No — never raw booleans',
        (tester) async {
      await _pump(tester);

      // Labels.
      expect(find.text('Diagnosis'), findsOneWidget);
      expect(find.text('Height / Weight'), findsOneWidget);
      expect(find.text('Discharge summary'), findsOneWidget);
      expect(find.text('RT/PEG feeding'), findsOneWidget);
      expect(find.text('Motion status'), findsOneWidget);

      // Combined height/weight value.
      expect(find.text('172 cm · 68 kg'), findsOneWidget);

      // Booleans surface as Yes/No text, never true/false.
      expect(find.text('Yes'), findsWidgets);
      expect(find.text('No'), findsWidgets);
      expect(find.text('true'), findsNothing);
      expect(find.text('false'), findsNothing);

      // Note blocks.
      expect(find.text('No stairs, no heavy lifting'), findsOneWidget);
      expect(find.text('Prefers Hindi; BP check before breakfast'),
          findsOneWidget);
    });
  });
}
