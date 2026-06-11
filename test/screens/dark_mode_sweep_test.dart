// test/screens/dark_mode_sweep_test.dart
//
// Dark-mode SWEEP across the full overflow-smoke screen list.
//
// test/widgets/dark_mode_test.dart proves the HcPalette resolver flips and a
// couple of shared widgets adapt — but nothing pumped every SCREEN under the
// dark theme. A dark-mode-only crash (null token, brightness-dependent layout,
// hardcoded light asset) would ship invisibly. This file pumps each screen
// from test/screens/overflow_smoke_test.dart ONCE at 375x667 wrapped in
// HousepitalTheme.darkTheme and asserts no exception (crash or RenderFlex
// overflow) was thrown.
//
// Host setup (test providers, demo data seeding, runAsync pump, timer
// draining) is copied from overflow_smoke_test.dart — its helpers are private
// to that file, so they are duplicated here verbatim apart from the dark
// theme. Runtime is kept sane: ONE size, dark only (light x3 sizes is the
// overflow suite's job).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/config/theme.dart';
import 'package:housepital_patient/data/care_packages.dart';
import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/article.dart';
import 'package:housepital_patient/models/medication_models.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/models/my_care_models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/assistant_provider.dart';
import 'package:housepital_patient/providers/auth_provider.dart';
import 'package:housepital_patient/providers/billing_provider.dart';
import 'package:housepital_patient/providers/blog_provider.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/providers/medication_provider.dart';
import 'package:housepital_patient/providers/my_care_provider.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/providers/theme_provider.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/services/assistant_service.dart';
import 'package:housepital_patient/services/voice_service.dart';
import 'package:housepital_patient/screens/assistant/assistant_executor.dart';
import 'package:housepital_patient/screens/assistant/assistant_screen.dart';
import 'package:housepital_patient/screens/auth/onboarding_screen.dart';
import 'package:housepital_patient/screens/auth/otp_screen.dart';
import 'package:housepital_patient/screens/billing/billing_screen.dart';
import 'package:housepital_patient/screens/billing/invoice_detail_screen.dart';
import 'package:housepital_patient/screens/billing/payment_methods_screen.dart';
import 'package:housepital_patient/screens/billing/transaction_log_screen.dart';
import 'package:housepital_patient/screens/cart/cart_screen.dart';
import 'package:housepital_patient/screens/consultation/video_consultation_screen.dart';
import 'package:housepital_patient/screens/documents/document_repository_screen.dart';
import 'package:housepital_patient/screens/home/home_screen.dart';
import 'package:housepital_patient/screens/my_care/attendance_history_screen.dart';
import 'package:housepital_patient/screens/my_care/medication_schedule_screen.dart';
import 'package:housepital_patient/screens/my_care/medications_screen.dart';
import 'package:housepital_patient/screens/my_care/my_care_screen.dart';
import 'package:housepital_patient/screens/my_care/report_history_screen.dart';
import 'package:housepital_patient/screens/my_care/service_detail_screen.dart';
import 'package:housepital_patient/screens/notifications/notifications_screen.dart';
import 'package:housepital_patient/screens/packages/package_detail_screen.dart';
import 'package:housepital_patient/screens/reports/daily_report_screen.dart';
import 'package:housepital_patient/screens/reports/vitals_screen.dart';
import 'package:housepital_patient/screens/search/universal_search_screen.dart';
import 'package:housepital_patient/screens/services/assessment_request_screen.dart';
import 'package:housepital_patient/screens/services/equipment_detail_screen.dart';
import 'package:housepital_patient/screens/services/my_orders_screen.dart';
import 'package:housepital_patient/screens/services/service_booking_screen.dart';
import 'package:housepital_patient/screens/services/service_catalog_screen.dart';
import 'package:housepital_patient/screens/settings/about_screen.dart';
import 'package:housepital_patient/screens/settings/add_patient_screen.dart';
import 'package:housepital_patient/screens/settings/family_members_screen.dart';
import 'package:housepital_patient/screens/settings/help_faq_screen.dart';
import 'package:housepital_patient/screens/settings/notification_preferences_screen.dart';
import 'package:housepital_patient/screens/settings/patient_profile_screen.dart';
import 'package:housepital_patient/screens/settings/settings_screen.dart';
import 'package:housepital_patient/screens/sos/sos_screen.dart';
import 'package:housepital_patient/screens/support/raise_concern_screen.dart';
import 'package:housepital_patient/screens/support/staff_profile_screen.dart';
import 'package:housepital_patient/utils/app_localizations.dart';
import 'package:housepital_patient/utils/permissions.dart';

import '../_mocks/fake_auth_api_service.dart';
import '../_mocks/fake_firebase_service.dart';

// One representative phone size — the std 375x667 (iPhone 8). The overflow
// suite already sweeps 320/375/414 in light mode; this suite's job is the
// dark-mode-only failure class, so one size keeps runtime sane.
const Size _size = Size(375, 667);

// ── Test providers: seed demo data synchronously, neutralise I/O loaders ─────
// (Copied from overflow_smoke_test.dart.)

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
  ServiceDetail? get selectedServiceDetail => DemoData.icuServiceDetail;
  @override
  bool get isDetailLoading => false;
  @override
  String? get detailError => null;

  @override
  Future<void> loadMyCareData(String patientId) async {}
  @override
  Future<void> loadServiceDetail(String deploymentId) async {}
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

AssistantProvider _assistantProvider() {
  final executor = AssistantExecutor(
    api: ApiService(),
    role: UserRole.primaryContact,
    patientId: 'pat_demo_rajesh',
    contacts: const {
      'health_manager':
          AssistantContact(name: 'Sunita Devi', phone: '9876500000'),
    },
  );
  return AssistantProvider(
    service: AssistantService(useStub: true),
    executor: executor,
    voice: NoopVoiceService(),
    patientId: 'pat_demo_rajesh',
    role: UserRole.primaryContact,
    locale: 'en',
  );
}

AuthProvider _authProvider() => AuthProvider(
      FakeFirebaseService(),
      FakeAuthApiService(),
    );

ServiceItem _equipmentService() => ServiceItem(
      id: 'equip-oxygen-concentrator',
      name: 'Oxygen Concentrator (5L)',
      category: 'equipment',
      bookingType: 'instant',
      description:
          'Medical-grade 5-litre oxygen concentrator for home use, '
          'delivered and installed by a trained technician.',
      basePriceMin: 3500,
      basePriceMax: 5500,
      durationMinutes: 60,
      iconName: 'medical_services',
    );

ServiceItem _assessmentService() => ServiceItem(
      id: 'visit-physio-assessment',
      name: 'Physiotherapy Assessment',
      category: 'manpower',
      bookingType: 'assessment',
      description:
          'A qualified physiotherapist visits to assess mobility and '
          'recommend a home rehab plan.',
      durationMinutes: 45,
    );

ServiceItem _bookingService() => ServiceItem(
      id: 'diag-blood-test',
      name: 'Complete Blood Count (CBC)',
      category: 'diagnostics',
      bookingType: 'instant',
      description: 'Home sample collection for a complete blood count.',
      basePriceMin: 400,
      basePriceMax: 600,
      durationMinutes: 15,
    );

// ── Hosts ────────────────────────────────────────────────────────────────────

Widget _homeHost(AppProvider app) => _wrap(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: app),
          ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ChangeNotifierProvider<MedicationProvider>(
            create: (_) => MedicationProvider(ApiService()),
          ),
        ],
        child: const HomeScreen(),
      ),
    );

Widget _myCareHost(AppProvider app, MyCareProvider myCare) => _wrap(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: app),
          ChangeNotifierProvider<MyCareProvider>.value(value: myCare),
        ],
        child: const MyCareScreen(),
      ),
    );

Widget _appHost(Widget child) => _wrap(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: _TestAppProvider()),
          ChangeNotifierProvider<MyCareProvider>.value(
              value: _TestMyCareProvider()),
          ChangeNotifierProvider<MedicationProvider>.value(
              value: _TestMedicationProvider()),
          ChangeNotifierProvider<BillingProvider>.value(
              value: _TestBillingProvider()),
          ChangeNotifierProvider<BlogProvider>.value(
              value: _TestBlogProvider()),
          ChangeNotifierProvider<OrdersProvider>.value(
              value: _TestOrdersProvider()),
          ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<AuthProvider>.value(value: _authProvider()),
        ],
        child: child,
      ),
    );

/// Identical to overflow_smoke_test's _wrap except the MaterialApp is forced
/// onto the app's REAL dark theme (`theme:` is what MaterialApp uses when no
/// darkTheme/themeMode pair is given — same approach as dark_mode_test.dart).
Widget _wrap(Widget home) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: HousepitalTheme.darkTheme,
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: home,
      ),
    );

/// Pumps [build] at 375x667 and returns the first exception (or null).
/// Same runAsync + teardown-inside-runAsync pattern as the overflow suite.
Future<Object?> _exceptionAt(
    WidgetTester tester, Widget Function() build) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  Object? ex;
  await tester.runAsync(() async {
    await tester.pumpWidget(build());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    ex = tester.takeException();
    // Tear down inside runAsync so dispose() cancels periodic timers, then
    // drain remaining one-shot timers (see overflow_smoke_test.dart).
    await tester.pumpWidget(const SizedBox.shrink());
    await Future<void>.delayed(const Duration(seconds: 3));
  });
  await tester.pump();
  return ex;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home renders in DARK mode without crash/overflow',
      (tester) async {
    final ex = await _exceptionAt(tester, () => _homeHost(_TestAppProvider()));
    expect(ex, isNull, reason: 'Home threw under darkTheme at $_size.');
  });

  testWidgets('My Care (with vitals) renders in DARK mode without crash',
      (tester) async {
    final ex = await _exceptionAt(
        tester, () => _myCareHost(_TestAppProvider(), _TestMyCareProvider()));
    expect(ex, isNull, reason: 'My Care threw under darkTheme at $_size.');
  });

  // ── Const / no-arg screens ──────────────────────────────────────────────
  void noArg(String name, Widget Function() screen) {
    testWidgets('$name renders in DARK mode without crash/overflow',
        (tester) async {
      final ex = await _exceptionAt(tester, () => _appHost(screen()));
      expect(ex, isNull, reason: '$name threw under darkTheme at $_size.');
    });
  }

  noArg('BillingScreen', () => const BillingScreen());
  noArg('TransactionLogScreen', () => const TransactionLogScreen());
  noArg('CartScreen', () => const CartScreen());
  noArg('MyOrdersScreen', () => const MyOrdersScreen(initialTab: 0));
  noArg('SettingsScreen', () => const SettingsScreen());
  noArg('PatientProfileScreen', () => const PatientProfileScreen());
  noArg('FamilyMembersScreen', () => const FamilyMembersScreen());
  noArg('AddPatientScreen', () => const AddPatientScreen());
  noArg('NotificationPreferencesScreen',
      () => const NotificationPreferencesScreen());
  noArg('HelpFaqScreen', () => const HelpFaqScreen());
  noArg('AboutScreen', () => const AboutScreen());
  noArg('SOSScreen', () => const SOSScreen());
  noArg('NotificationsScreen', () => const NotificationsScreen());
  noArg('DocumentRepositoryScreen', () => const DocumentRepositoryScreen());
  noArg('UniversalSearchScreen', () => const UniversalSearchScreen());
  noArg('MedicationsScreen', () => const MedicationsScreen());
  noArg('MedicationScheduleScreen', () => const MedicationScheduleScreen());
  noArg('RaiseConcernScreen', () => const RaiseConcernScreen());
  noArg('PaymentMethodsScreen', () => const PaymentMethodsScreen());
  noArg('ServiceCatalogScreen', () => const ServiceCatalogScreen());

  // AssistantScreen + Auth screens need their own providers.
  testWidgets('AssistantScreen renders in DARK mode without crash',
      (tester) async {
    final ex = await _exceptionAt(
      tester,
      () => _wrap(
        ChangeNotifierProvider<AssistantProvider>.value(
          value: _assistantProvider(),
          child: const AssistantScreen(),
        ),
      ),
    );
    expect(ex, isNull,
        reason: 'AssistantScreen threw under darkTheme at $_size.');
  });

  testWidgets('OnboardingScreen renders in DARK mode without crash',
      (tester) async {
    final ex = await _exceptionAt(
      tester,
      () => _wrap(
        ChangeNotifierProvider<AuthProvider>.value(
          value: _authProvider(),
          child: const OnboardingScreen(),
        ),
      ),
    );
    expect(ex, isNull,
        reason: 'OnboardingScreen threw under darkTheme at $_size.');
  });

  testWidgets('OtpScreen renders in DARK mode without crash', (tester) async {
    final ex = await _exceptionAt(
      tester,
      () => _wrap(
        ChangeNotifierProvider<AuthProvider>.value(
          value: _authProvider(),
          child: const OtpScreen(),
        ),
      ),
    );
    expect(ex, isNull, reason: 'OtpScreen threw under darkTheme at $_size.');
  });

  // ── Arg-taking screens ──────────────────────────────────────────────────
  void argScreen(String name, Widget Function() screen) {
    testWidgets('$name renders in DARK mode without crash/overflow',
        (tester) async {
      final ex = await _exceptionAt(tester, () => _appHost(screen()));
      expect(ex, isNull, reason: '$name threw under darkTheme at $_size.');
    });
  }

  argScreen('ServiceDetailScreen',
      () => ServiceDetailScreen(service: DemoData.activeServices[0]));
  argScreen('PackageDetailScreen',
      () => PackageDetailScreen(package: carePackages[0]));
  argScreen('ServiceBookingScreen',
      () => ServiceBookingScreen(service: _bookingService()));
  argScreen('EquipmentDetailScreen',
      () => EquipmentDetailScreen(service: _equipmentService()));
  argScreen('AssessmentRequestScreen',
      () => AssessmentRequestScreen(service: _assessmentService()));
  argScreen('VitalsScreen', () => const VitalsScreen(initialVital: null));
  argScreen('DailyReportScreen',
      () => DailyReportScreen(reportId: DemoData.todayReport.id));
  argScreen('StaffProfileScreen',
      () => const StaffProfileScreen(staffId: 'staff_sunita'));
  argScreen('InvoiceDetailScreen',
      () => const InvoiceDetailScreen(invoiceId: 'inv_001'));
  argScreen('ReportHistoryScreen',
      () => const ReportHistoryScreen(deploymentId: 'dep_icu_001'));
  argScreen('AttendanceHistoryScreen',
      () => const AttendanceHistoryScreen(deploymentId: 'dep_icu_001'));
  // StaffOtpVerificationScreen intentionally NOT covered — its initState hits
  // FirebaseFirestore.instance with no try/catch (same exclusion + rationale
  // as overflow_smoke_test.dart).
  argScreen(
      'VideoConsultationScreen',
      () => const VideoConsultationScreen(
            doctorName: 'Dr. Anjali Sharma',
          ));
}
