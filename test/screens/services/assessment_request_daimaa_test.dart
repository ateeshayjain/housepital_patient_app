// test/screens/services/assessment_request_daimaa_test.dart
//
// Tests the Dai Maa branch of AssessmentRequestScreen:
//   - japa serviceId  → cream background + plum AppBar + DaiMaaBrandHeader visible
//   - nanny serviceId → same
//   - non-Dai Maa serviceId (nursing) → standard styling, no DaiMaaBrandHeader

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/config/daimaa_theme.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/screens/services/assessment_request_screen.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/utils/app_localizations.dart';

// Subclass that suppresses loadDashboard() side effects during tests.
class _TestAppProvider extends AppProvider {
  _TestAppProvider() : super(ApiService());
}

ServiceItem _service(String id, String name) => ServiceItem(
      id: id,
      name: name,
      category: 'manpower',
      bookingType: 'assessment',
    );

Widget _host(ServiceItem service, AppProvider app, OrdersProvider orders) {
  return MaterialApp(
    localizationsDelegates: const [AppLocalizations.delegate],
    supportedLocales: const [Locale('en')],
    routes: {
      '/booking-history': (_) => const Scaffold(body: Text('Booking history')),
    },
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: app),
        ChangeNotifierProvider<OrdersProvider>.value(value: orders),
      ],
      child: AssessmentRequestScreen(service: service),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TestAppProvider app;
  late OrdersProvider orders;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app = _TestAppProvider();
    orders = OrdersProvider();
    // Let async loaders settle.
    await Future<void>.delayed(Duration.zero);
  });

  Future<void> pumpScreen(WidgetTester tester, ServiceItem service) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(_host(service, app, orders));
      // Allow AppLocalizations async load to complete.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Dai Maa branch — japa
  // ───────────────────────────────────────────────────────────────────────────
  group('AssessmentRequestScreen — Japa (Dai Maa branch)', () {
    final japa = _service('mp-japa-24', 'Japa Maid – 24 Hours');

    testWidgets('background is cream (DaiMaaColors.cream)', (tester) async {
      await pumpScreen(tester, japa);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, DaiMaaColors.cream);
    });

    testWidgets('AppBar uses plum background colour', (tester) async {
      await pumpScreen(tester, japa);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, DaiMaaColors.plum);
      expect(appBar.foregroundColor, Colors.white);
    });

    testWidgets('DaiMaaBrandHeader is rendered with the Japa title', (tester) async {
      await pumpScreen(tester, japa);

      expect(find.byType(DaiMaaBrandHeader), findsOneWidget);
      // The header carries the service-specific title.
      final header = tester.widget<DaiMaaBrandHeader>(find.byType(DaiMaaBrandHeader));
      expect(header.title, 'Japa Maid');
    });

    testWidgets('shows Dai Maa coordinator phone in helper text', (tester) async {
      await pumpScreen(tester, japa);

      // Helper text at bottom of form mentions the coordinator's phone number.
      expect(
        find.textContaining(DaiMaaColors.phoneDisplay),
        findsWidgets,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Dai Maa branch — nanny
  // ───────────────────────────────────────────────────────────────────────────
  group('AssessmentRequestScreen — Nanny (Dai Maa branch)', () {
    final nanny = _service('mp-nanny-12', 'Nanny – 12 Hours');

    testWidgets('background is cream', (tester) async {
      await pumpScreen(tester, nanny);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, DaiMaaColors.cream);
    });

    testWidgets('AppBar uses plum background colour', (tester) async {
      await pumpScreen(tester, nanny);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, DaiMaaColors.plum);
    });

    testWidgets('DaiMaaBrandHeader is rendered with the Nanny title', (tester) async {
      await pumpScreen(tester, nanny);

      expect(find.byType(DaiMaaBrandHeader), findsOneWidget);
      final header = tester.widget<DaiMaaBrandHeader>(find.byType(DaiMaaBrandHeader));
      expect(header.title, 'Nanny');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Non-Dai Maa branch — nursing service falls back to Housepital styling
  // ───────────────────────────────────────────────────────────────────────────
  group('AssessmentRequestScreen — Nursing (standard Housepital branch)', () {
    final nursing = _service('mp-nurse-basic-12', 'Nurse (Basic) – 12 Hours');

    testWidgets('does NOT render the DaiMaaBrandHeader', (tester) async {
      await pumpScreen(tester, nursing);

      expect(find.byType(DaiMaaBrandHeader), findsNothing);
    });

    testWidgets('Scaffold background is NOT cream (uses theme default)',
        (tester) async {
      await pumpScreen(tester, nursing);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      // For non-Dai Maa, the screen passes `null` so MaterialApp's theme
      // background applies. The explicit cream colour must NOT be set.
      expect(scaffold.backgroundColor, isNot(DaiMaaColors.cream));
    });

    testWidgets('AppBar is NOT plum (no explicit override)', (tester) async {
      await pumpScreen(tester, nursing);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNot(DaiMaaColors.plum));
    });

    testWidgets('helper text does NOT mention the Dai Maa coordinator phone',
        (tester) async {
      await pumpScreen(tester, nursing);

      expect(find.textContaining(DaiMaaColors.phoneDisplay), findsNothing);
    });
  });
}
