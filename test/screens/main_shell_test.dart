// test/screens/main_shell_test.dart
//
// Widget tests for MainShell's floating-pill bottom navigation (calm pass).
//
// The nav bar is a DETACHED capsule: 16px side margins, ≥8px bottom margin,
// fully rounded GlassSurface (radius 32), ~64px content. It stays in the
// Scaffold's bottomNavigationBar slot so the body's MediaQuery bottom inset
// keeps covering the pill's full footprint — every screen that pads its
// scrollable with `MediaQuery.padding.bottom + N` clears the pill for free.
//
// Provider pattern copied from test/screens/overflow_smoke_test.dart: the
// IndexedStack builds ALL five tabs eagerly, so every global provider must be
// present with demo data seeded synchronously and network loaders neutralised.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/article.dart';
import 'package:housepital_patient/models/medication_models.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/models/my_care_models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/auth_provider.dart';
import 'package:housepital_patient/providers/billing_provider.dart';
import 'package:housepital_patient/providers/blog_provider.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/providers/medication_provider.dart';
import 'package:housepital_patient/providers/my_care_provider.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/providers/reminders_provider.dart';
import 'package:housepital_patient/providers/theme_provider.dart';
import 'package:housepital_patient/screens/home/home_screen.dart';
import 'package:housepital_patient/screens/main_shell.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/utils/app_localizations.dart';
import 'package:housepital_patient/widgets/assistant_fab.dart';
import 'package:housepital_patient/widgets/glass.dart';

import '../_mocks/fake_auth_api_service.dart';
import '../_mocks/fake_firebase_service.dart';

class _TestAppProvider extends AppProvider {
  _TestAppProvider() : super(ApiService());

  @override
  Patient? get currentPatient => DemoData.patient;
  @override
  List<Patient> get patients => [DemoData.patient];
  @override
  Deployment? get activeDeployment => DemoData.icuDeployment;
  @override
  bool get isDashboardLoading => false;
  @override
  VitalReading? get latestVitals => DemoData.vitalsHistory.last;
  @override
  DailyReport? get todayReport => DemoData.todayReport;

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
  bool get isLoading => false;
  @override
  String? get error => null;

  @override
  Future<void> loadMedications(String patientId) async {}
  @override
  Future<void> loadTodaySchedule(String patientId) async {}
}

class _TestBillingProvider extends BillingProvider {
  _TestBillingProvider() : super(ApiService());

  @override
  int get amountDue => DemoData.billingSummary['amount_due'] ?? 24500;
  @override
  DateTime? get dueDate => DateTime.now().add(const Duration(days: 5));
  @override
  bool get isLoading => false;
  @override
  String? get error => null;

  @override
  Future<void> loadBillingSummary(String patientId) async {}
}

class _TestBlogProvider extends BlogProvider {
  _TestBlogProvider() : super(ApiService());

  @override
  List<Article> get articles => DemoData.articles;
  @override
  bool get isLoading => false;
  @override
  String? get error => null;

  @override
  Future<void> loadArticles({String? category}) async {}
}

class _TestOrdersProvider extends OrdersProvider {
  @override
  List<Map<String, dynamic>> get orders => DemoData.orders;
}

Widget _host() => MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: _TestAppProvider()),
        ChangeNotifierProvider<MyCareProvider>.value(
            value: _TestMyCareProvider()),
        ChangeNotifierProvider<MedicationProvider>.value(
            value: _TestMedicationProvider()),
        ChangeNotifierProvider<BillingProvider>.value(
            value: _TestBillingProvider()),
        ChangeNotifierProvider<BlogProvider>.value(value: _TestBlogProvider()),
        ChangeNotifierProvider<OrdersProvider>.value(
            value: _TestOrdersProvider()),
        ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
        // RemindersProvider is needed by the care calendar route pushed from
        // the My Care app bar.
        ChangeNotifierProvider<RemindersProvider>(
            create: (_) => RemindersProvider()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<AuthProvider>.value(
            value: AuthProvider(FakeFirebaseService(), FakeAuthApiService())),
      ],
      child: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: const [Locale('en')],
          home: const MainShell(),
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, Size size) async {
  // Must precede provider construction (ctors read SharedPreferences).
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // runAsync so the async AppLocalizations delegate resolves.
  await tester.runAsync(() async {
    await tester.pumpWidget(_host());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bottom nav is a FLOATING glass pill, inset from every edge',
      (tester) async {
    const size = Size(390, 844);
    await _pump(tester, size);

    // Owner (field round 8): back to the detached liquid-glass pill, matching
    // the reference app they use daily. This reverses field round 5's fixed
    // edge-to-edge orange bar.
    final barRect = tester.getRect(find.byType(BottomNavigationBar));
    expect(barRect.left, greaterThan(0.0),
        reason: 'Pill floats — it must not touch the left edge.');
    expect(barRect.right, lessThan(size.width),
        reason: 'Pill floats — it must not touch the right edge.');
    expect(barRect.bottom, lessThan(size.height),
        reason: 'Pill floats above the bottom edge.');

    // Glass, not a solid fill: the material comes from GlassSurface and the
    // bar itself is transparent.
    expect(
      find.ancestor(
        of: find.byType(BottomNavigationBar),
        matching: find.byType(GlassSurface),
      ),
      findsOneWidget,
      reason: 'The pill is a GlassSurface, not a painted colour.',
    );
    final navBar = tester
        .widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(navBar.backgroundColor, Colors.transparent);
  });

  testWidgets('body extends under the pill, and the pill still reserves inset',
      (tester) async {
    // The round-5 objection to the pill was that it covered content. That is
    // answered structurally: the pill sits in the Scaffold's
    // bottomNavigationBar slot, so the body's MediaQuery bottom inset still
    // covers the pill's full footprint (pill + margins) and every screen that
    // pads by `MediaQuery.padding.bottom + N` clears it for free.
    await _pump(tester, const Size(390, 844));

    final homeContext = tester.element(find.byType(HomeScreen));
    final barRect = tester.getRect(find.byType(BottomNavigationBar));
    expect(MediaQuery.of(homeContext).padding.bottom,
        greaterThanOrEqualTo(barRect.height),
        reason: 'Content must be able to clear the pill without knowing it '
            'exists.');
  });

  testWidgets(
      'body still receives the bar footprint as its bottom MediaQuery inset',
      (tester) async {
    await _pump(tester, const Size(390, 844));

    // Screens pad scrollables with MediaQuery.padding.bottom + N — with the
    // bar in the bottomNavigationBar slot the Scaffold reports the slot
    // height so nothing important hides under the fixed bar.
    final homeContext = tester.element(find.byType(HomeScreen));
    expect(MediaQuery.of(homeContext).padding.bottom,
        greaterThanOrEqualTo(56.0));
  });

  testWidgets('five tabs, no Calendar tab; tapping an item switches tabs',
      (tester) async {
    await _pump(tester, const Size(390, 844));

    final bar = tester
        .widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(bar.items, hasLength(5));

    Finder barLabel(String text) => find.descendant(
        of: find.byType(BottomNavigationBar), matching: find.text(text));
    for (final label in ['Home', 'My Care', 'Services', 'Billing', 'More']) {
      expect(barLabel(label), findsOneWidget);
    }
    // Owner: the calendar moved to the My Care app bar — it is not a tab.
    expect(barLabel('Calendar'), findsNothing);

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack).first).index,
        0);
    await tester.tap(barLabel('My Care'));
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack).first).index,
        1);
    // Billing is index 3 — home_screen's 'Pay Now' and upcoming-payment card
    // call switchToTab(3) and must land here.
    await tester.tap(barLabel('Billing'));
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack).first).index,
        3);
  });

  testWidgets('assistant FAB floats above the bar without colliding',
      (tester) async {
    await _pump(tester, const Size(390, 844));

    final fabRect = tester.getRect(find.byType(AssistantFab));
    final barRect = tester.getRect(find.byType(BottomNavigationBar));
    expect(fabRect.overlaps(barRect), isFalse,
        reason: 'Assistant FAB must not collide with the pill.');
    expect(fabRect.bottom, lessThanOrEqualTo(barRect.top));
  });

  testWidgets('shell lays out without overflow at 320x568 with five tabs',
      (tester) async {
    await _pump(tester, const Size(320, 568));
    expect(tester.takeException(), isNull,
        reason: 'Floating five-tab pill must not overflow at SE width.');
  });
}
