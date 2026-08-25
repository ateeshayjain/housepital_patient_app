// test/screens/overflow_smoke_test.dart
//
// Screen-level OVERFLOW smoke tests.
//
// Why this exists: a "BOTTOM OVERFLOWED" stripe shipped on the My Care
// "Today's Vitals" strip even though analyzer was clean and 1408 tests passed.
// The reason it slipped through: the other screen tests pump on a deliberately
// huge surface (1080x4000) "so all sections lay out without overflow" — which
// is exactly why they can never catch an overflow. A 4000px-tall canvas has
// room no real phone has.
//
// This file does the opposite: it pumps each screen at REAL phone sizes and
// fails if Flutter reports ANY RenderFlex overflow. Flutter reports overflow
// via FlutterError.onError during paint, which flutter_test surfaces through
// tester.takeException() — so the assertion is simply "no exception after a
// pump at a phone-sized surface".
//
// Critically, screens are pumped WITH demo data present (vitals, active
// services, orders, medications, …), because the overflowing layouts are
// gated behind populated state — the exact path the isolated widget tests
// never exercised.
//
// NOTE on the Ahem test font: widget tests render with "Ahem", whose every
// glyph is a full em-square — much wider/taller than the real Archivo font
// (bundled TTF asset, not loaded by the test binding). So this suite
// over-reports vs. real devices but doubles as a worst-case large-text guard.
// Every fix applied here is correct on real devices AND helps large Dynamic
// Type — never a distortion just to satisfy Ahem.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'package:housepital_patient/screens/services/data/catalog_seeds.dart';
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

// Real phone logical sizes (devicePixelRatio pinned to 1.0 so physical ==
// logical). Smallest first — the iPhone SE is where vertical strips overflow.
const Map<String, Size> _phoneSizes = {
  'small  320x568 (SE)': Size(320, 568),
  'std    375x667 (8)': Size(375, 667),
  'large  414x896 (11)': Size(414, 896),
  // WCAG 1.4.4 requires text to scale to 200% without loss of content or
  // function. main.dart used to clamp at 1.4x under a comment CITING 1.4.4 —
  // it failed the rule it invoked, and a user at iOS AX5 had their setting
  // silently discarded on an app they may be using because they cannot read
  // small text.
  //
  // Raising the clamp is only defensible with evidence, so this pass exists:
  // every screen in the sweep, at the standard phone size, with text at 2.0x.
  // If this row goes red, the clamp is wrong or the screen is.
  'std @2.0x text 375x667': Size(375, 667),
};

/// Text scale applied by [_wrap] for the current pass.
///
/// A file-level variable rather than a parameter because [_wrap] is called
/// from thirty-odd host builders; threading a scale through every one of them
/// would be a larger and more error-prone edit than this. Set by
/// [_exceptionAt] before each pump and restored after.
double _textScale = 1.0;

// ── Test providers: seed demo data synchronously, neutralise I/O loaders ─────

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
  // The two getters that gate the overflowing My Care sections:
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
  // Service-detail path (service_detail_screen):
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

/// OrdersProvider that seeds the demo orders synchronously (the real one loads
/// from SharedPreferences asynchronously, leaving an empty list during a pump).
class _TestOrdersProvider extends OrdersProvider {
  @override
  List<Map<String, dynamic>> get orders => DemoData.orders;
}

// AssistantProvider built with the stub service so no network / Firebase.
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

// A demo ServiceItem in the equipment category (instant booking).
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

// A demo ServiceItem that requires an assessment (manpower).
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

// A demo ServiceItem booked on a schedule (diagnostics, instant).
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

/// Generic host wiring every global provider a screen might read, so any of
/// the const/no-arg screens can be dropped in as [child].
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

// disableAnimations:true keeps animated screens deterministic under pump.
// (The Home banner auto-scroll timer this originally guarded against has been
// removed — the banner is manual swipe + dots only.)
Widget _wrap(Widget home) => MediaQuery(
      data: MediaQueryData(
        disableAnimations: true,
        textScaler: TextScaler.linear(_textScale),
      ),
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: home,
      ),
    );

/// Pumps [build] at [size] and returns the first overflow/layout exception (or
/// null). Mirrors the runAsync+pump pattern used by the other screen tests so
/// the async AppLocalizations delegate and real timers behave.
Future<Object?> _exceptionAt(
    WidgetTester tester, Widget Function() build, Size size,
    {double textScale = 1.0}) async {
  _textScale = textScale;
  addTearDown(() => _textScale = 1.0);
  // Set the SharedPreferences mock BEFORE building, because the providers'
  // constructors call SharedPreferences.getInstance — building eagerly in the
  // caller would run that before the mock exists (order-dependent crash).
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  Object? ex;
  await tester.runAsync(() async {
    await tester.pumpWidget(build());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    ex = tester.takeException();
    // Tear the tree down INSIDE runAsync so dispose() runs (cancelling any
    // periodic timer a screen started in initState, e.g. the VideoConsultation
    // call-duration ticker). Then drain any remaining one-shot timers (e.g. the
    // 2s auto-connect Future.delayed) — once the tree is gone they fire as
    // no-ops because `mounted` is false, so nothing reschedules. This keeps
    // flutter_test's "Timer still pending" invariant happy without masking a
    // real layout overflow (already captured above).
    await tester.pumpWidget(const SizedBox.shrink());
    await Future<void>.delayed(const Duration(seconds: 3));
  });
  await tester.pump();
  return ex;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _phoneSizes.forEach((label, size) {
    // The label carries the scale for the 200% pass; everything else is 1.0.
    final scale = label.contains('@2.0x') ? 2.0 : 1.0;
    // ── Original two (Home + My Care) ─────────────────────────────────────
    testWidgets('Home lays out without overflow — $label', (tester) async {
      final ex =
          await _exceptionAt(tester, () => _homeHost(_TestAppProvider()), size,
              textScale: scale);
      expect(ex, isNull,
          reason: 'Home overflowed at $size — a RenderFlex exceeded its box.');
    });

    testWidgets('My Care (with vitals) lays out without overflow — $label',
        (tester) async {
      final ex = await _exceptionAt(tester,
          () => _myCareHost(_TestAppProvider(), _TestMyCareProvider()), size);
      expect(ex, isNull,
          reason: 'My Care overflowed at $size — likely the Today\'s Vitals '
              'strip (fixed-height row vs. taller pill content).');
    });

    // ── Const / no-arg screens ────────────────────────────────────────────
    void noArg(String name, Widget Function() screen) {
      testWidgets('$name lays out without overflow — $label', (tester) async {
        final ex = await _exceptionAt(tester, () => _appHost(screen()), size,
          textScale: scale);
        expect(ex, isNull, reason: '$name overflowed at $size.');
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
    testWidgets('AssistantScreen lays out without overflow — $label',
        (tester) async {
      final ex = await _exceptionAt(
        tester,
        () => _wrap(
          ChangeNotifierProvider<AssistantProvider>.value(
            value: _assistantProvider(),
            child: const AssistantScreen(),
          ),
        ),
        size,
      );
      expect(ex, isNull, reason: 'AssistantScreen overflowed at $size.');
    });

    testWidgets('OnboardingScreen lays out without overflow — $label',
        (tester) async {
      final ex = await _exceptionAt(
        tester,
        () => _wrap(
          ChangeNotifierProvider<AuthProvider>.value(
            value: _authProvider(),
            child: const OnboardingScreen(),
          ),
        ),
        size,
      );
      expect(ex, isNull, reason: 'OnboardingScreen overflowed at $size.');
    });

    testWidgets('OtpScreen lays out without overflow — $label', (tester) async {
      final ex = await _exceptionAt(
        tester,
        () => _wrap(
          ChangeNotifierProvider<AuthProvider>.value(
            value: _authProvider(),
            child: const OtpScreen(),
          ),
        ),
        size,
      );
      expect(ex, isNull, reason: 'OtpScreen overflowed at $size.');
    });

    // ── Arg-taking screens ────────────────────────────────────────────────
    void argScreen(String name, Widget Function() screen) {
      testWidgets('$name lays out without overflow — $label', (tester) async {
        final ex = await _exceptionAt(tester, () => _appHost(screen()), size,
          textScale: scale);
        expect(ex, isNull, reason: '$name overflowed at $size.');
      });
    }

    argScreen('ServiceDetailScreen',
        () => ServiceDetailScreen(service: DemoData.activeServices[0]));
    argScreen('PackageDetailScreen',
        () => PackageDetailScreen(package: carePackages[0]));
    argScreen('ServiceBookingScreen',
        () => ServiceBookingScreen(service: _bookingService()));
    // Consultation detail with the rich preparationNotes formatting (plan
    // rows, chips, bulleted credentials, 'Trained at' institution chips) must
    // not overflow at the narrow 320px width under Ahem.
    argScreen(
        'ServiceBookingScreen (con-diet rich notes)',
        () => ServiceBookingScreen(
            service:
                consultationServices.firstWhere((s) => s.id == 'con-diet')));
    argScreen(
        'ServiceBookingScreen (con-psychiatrist rich notes)',
        () => ServiceBookingScreen(
            service: consultationServices
                .firstWhere((s) => s.id == 'con-psychiatrist')));
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
    // NOTE: StaffOtpVerificationScreen is intentionally NOT covered here.
    // Its initState() calls FirebaseFirestore.instance (via _storeOtp /
    // _listenForVerification), which throws "No Firebase App" in a widget test
    // — there is no device-correct UI fix for that, and initialising real
    // Firebase from a test is out of scope. Layout overflow on this screen
    // cannot be exercised without a Firebase mock the harness doesn't provide.
    argScreen(
        'VideoConsultationScreen',
        () => const VideoConsultationScreen(
              doctorName: 'Dr. Anjali Sharma',
            ));
  });
}
