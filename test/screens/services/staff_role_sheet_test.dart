// test/screens/services/staff_role_sheet_test.dart
//
// Widget tests for the need-based selection bottom sheet opened from
// StaffRoleCard (Manpower tab). Verifies:
//  - Basic (level-0) tasks come pre-checked and the recommendation starts
//    at Basic.
//  - Checking an advanced task flips the recommendation (and CTA label)
//    to Advanced.
//  - Unchecking it drops the recommendation back to Basic.
//
// Provider pattern copied from test/screens/care_team/care_team_screen_test.dart:
// subclass the real AppProvider and neutralise the async loaders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/screens/services/cards/staff_role_card.dart';
import 'package:housepital_patient/screens/services/data/staff_roles_seed.dart';
import 'package:housepital_patient/services/api_service.dart';

class _TestAppProvider extends AppProvider {
  _TestAppProvider() : super(ApiService());

  @override
  Future<void> loadPatients() async {}
  @override
  Future<void> loadDashboard() async {}
}

final _caretakerRole =
    staffRoles.firstWhere((r) => r.title == 'Caretaker');

// NOTE: no prices on manpower services in UI assertions — the sheet must
// never surface a price for caretaker/nurse/japa/nanny.
final _services = <ServiceItem>[
  ServiceItem(
    id: 'mp-caretaker-basic-12',
    name: 'Caretaker (Basic) – 12 Hours',
    category: 'manpower',
    bookingType: 'scheduled',
  ),
];

Widget _host() => ChangeNotifierProvider<AppProvider>.value(
      value: _TestAppProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: StaffRoleCard(
            role: _caretakerRole,
            services: _services,
            onNavigate: (_, _) {},
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    // Provider constructors hit SharedPreferences.getInstance.
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> openSheet(WidgetTester tester) async {
    // Tall surface so the sheet's checklist sections are materialised.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.tap(find.byType(StaffRoleCard));
    await tester.pumpAndSettle();
  }

  Future<void> tapTask(WidgetTester tester, String task) async {
    await tester.ensureVisible(find.text(task));
    await tester.pumpAndSettle();
    await tester.tap(find.text(task));
    await tester.pumpAndSettle();
  }

  group('Staff role sheet — need-based selection', () {
    testWidgets('basic tasks pre-checked and Recommended: Basic visible',
        (tester) async {
      await openSheet(tester);

      // Checklist heading is shown (old static scope heading is gone).
      expect(find.text('Select what you need'), findsOneWidget);
      expect(find.text('Scope of Service'), findsNothing);

      // All 11 concrete Basic caretaker tasks come pre-checked; the 4
      // Advanced adds are unchecked.
      expect(find.byIcon(Icons.check_box), findsNWidgets(11));
      expect(find.byIcon(Icons.check_box_outline_blank), findsNWidgets(4));

      // Meta entries ("All Basic services") are not rendered as tasks.
      expect(find.text('All Basic services'), findsNothing);

      // Section headers per level.
      expect(find.text('Basic care'), findsOneWidget);
      expect(find.text('Advanced care adds'), findsOneWidget);

      // Recommendation starts at Basic, CTA mirrors it.
      expect(find.text('Recommended: Basic Caretaker'), findsOneWidget);
      expect(find.text('Continue — Basic Caretaker'), findsOneWidget);
      expect(find.text('Request Assessment'), findsNothing);
    });

    testWidgets('checking an advanced task flips recommendation to Advanced',
        (tester) async {
      await openSheet(tester);

      await tapTask(tester, 'Insulin administration');

      expect(find.text('Recommended: Advanced Caretaker'), findsOneWidget);
      expect(find.text('Continue — Advanced Caretaker'), findsOneWidget);
      expect(find.text('Recommended: Basic Caretaker'), findsNothing);

      // One-line reason for the upgrade.
      expect(
        find.text('Includes 1 advanced-care task you selected'),
        findsOneWidget,
      );

      // A second advanced task updates the count.
      await tapTask(tester, 'Sugar monitoring');
      expect(
        find.text('Includes 2 advanced-care tasks you selected'),
        findsOneWidget,
      );
    });

    testWidgets('unchecking all advanced tasks drops back to Basic',
        (tester) async {
      await openSheet(tester);

      await tapTask(tester, 'Insulin administration');
      expect(find.text('Recommended: Advanced Caretaker'), findsOneWidget);

      // Uncheck the same task — recommendation reverts.
      await tapTask(tester, 'Insulin administration');
      expect(find.text('Recommended: Basic Caretaker'), findsOneWidget);
      expect(find.text('Continue — Basic Caretaker'), findsOneWidget);
      expect(find.text('Recommended: Advanced Caretaker'), findsNothing);
    });

    testWidgets('sheet shows no prices for manpower', (tester) async {
      await openSheet(tester);
      expect(find.textContaining('₹'), findsNothing);
    });
  });
}
