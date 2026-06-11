// test/screens/care_team/care_team_screen_test.dart
//
// Widget tests for the Care Team Hub screen: every role renders (Health
// Manager, Supervisor, Doctor, on-duty staff) plus the visually distinct
// Ambulance emergency row with the 24x7 emergency number.
//
// Provider pattern copied from test/screens/overflow_smoke_test.dart:
// subclass the real providers, return demo data synchronously, neutralise
// the async loaders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/config/constants.dart';
import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/models/my_care_models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/my_care_provider.dart';
import 'package:housepital_patient/screens/care_team/care_team_screen.dart';
import 'package:housepital_patient/services/api_service.dart';

class _TestAppProvider extends AppProvider {
  _TestAppProvider() : super(ApiService());

  @override
  Patient? get currentPatient => DemoData.patient;
  @override
  Deployment? get activeDeployment => DemoData.icuDeployment;

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
  Future<void> loadMyCareData(String patientId) async {}
}

Widget _host() => MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: _TestAppProvider()),
        ChangeNotifierProvider<MyCareProvider>.value(
            value: _TestMyCareProvider()),
      ],
      child: const MaterialApp(home: CareTeamScreen()),
    );

void main() {
  setUp(() {
    // Provider constructors hit SharedPreferences.getInstance.
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pump(WidgetTester tester) async {
    // Tall surface so the whole list (incl. the trailing Ambulance card)
    // is materialised — ListView only builds visible children.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host());
    await tester.pump();
  }

  testWidgets('renders Health Manager row', (tester) async {
    await pump(tester);
    expect(find.text('Vikram Mehta'), findsOneWidget);
    expect(find.text('Health Manager'), findsOneWidget);
  });

  testWidgets('renders Supervisor row', (tester) async {
    await pump(tester);
    expect(find.text('Rohit Verma'), findsOneWidget);
    expect(find.text('Operations Supervisor'), findsOneWidget);
  });

  testWidgets('renders Doctor row', (tester) async {
    await pump(tester);
    expect(find.text('Dr. Ananya Sharma'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);
  });

  testWidgets('renders on-duty staff rows from active services',
      (tester) async {
    await pump(tester);
    // ICU service's deployment matches the global active deployment, so the
    // actual person (Sunita Devi, Critical Care Nurse) is surfaced.
    expect(find.text('Sunita Devi'), findsOneWidget);
    expect(find.text('Critical Care Nurse'), findsOneWidget);
    // The other staffed services fall back to the service name.
    expect(find.text('Caretaker (Basic) 12 Hours'), findsOneWidget);
    expect(find.text('Physiotherapy (Advanced)'), findsOneWidget);
  });

  testWidgets('renders Ambulance emergency row with number and CALL button',
      (tester) async {
    await pump(tester);
    expect(find.text('Ambulance — 24x7 Emergency'), findsOneWidget);
    expect(find.text(AppConstants.emergencyPhone), findsOneWidget);
    expect(find.text('CALL'), findsOneWidget);
  });

  testWidgets('renders read-only Past staff section after the Ambulance card',
      (tester) async {
    await pump(tester);
    expect(find.text('Past staff'), findsOneWidget);
    // All three past staff entries from DemoData.pastStaff.
    expect(find.text('Roopchand'), findsOneWidget);
    expect(find.text('Health Attendant · Jan – Apr 2026'), findsOneWidget);
    expect(find.text('Post-stroke care'), findsOneWidget);
    expect(find.text('Meena Kumari'), findsOneWidget);
    expect(find.text('Arjun Yadav'), findsOneWidget);
    // History icon tile per past staff row.
    expect(find.byIcon(Icons.history), findsNWidgets(3));
  });

  testWidgets('every member row has call and chat buttons; ambulance has none',
      (tester) async {
    await pump(tester);
    // 6 member rows (HM, Supervisor, Doctor, 3 staffed services) each get a
    // phone IconButton; the Ambulance card has one phone icon inside its
    // big CALL ElevatedButton.
    expect(find.byIcon(Icons.phone), findsNWidgets(7));
    expect(find.byIcon(Icons.chat_bubble_outline), findsNWidgets(6));
    // Ambulance card never gets a chat affordance.
    expect(find.byIcon(Icons.emergency), findsOneWidget);
  });
}
