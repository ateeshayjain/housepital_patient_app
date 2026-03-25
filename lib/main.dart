import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'config/firebase_options.dart';
import 'config/theme.dart';
import 'models/models.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'services/api_service.dart';
import 'services/firebase_service.dart';
import 'utils/app_localizations.dart';

import 'screens/main_shell.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/reports/daily_report_screen.dart';
import 'screens/reports/vitals_screen.dart';
import 'screens/services/service_booking_screen.dart';
import 'screens/services/equipment_detail_screen.dart';
import 'screens/services/assessment_request_screen.dart';
import 'screens/billing/billing_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/packages/package_detail_screen.dart';
import 'screens/support/raise_concern_screen.dart';
import 'screens/support/staff_profile_screen.dart';
import 'screens/sos/sos_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/patient_profile_screen.dart';
import 'screens/settings/family_members_screen.dart';
import 'screens/settings/notification_preferences_screen.dart';
import 'screens/settings/help_faq_screen.dart';
import 'screens/settings/about_screen.dart';
import 'screens/billing/invoice_detail_screen.dart';
import 'screens/billing/transaction_log_screen.dart';
import 'screens/billing/payment_methods_screen.dart';
import 'screens/billing/payment_screen.dart';
import 'screens/documents/document_repository_screen.dart';
import 'screens/search/universal_search_screen.dart';
import 'screens/my_care/service_detail_screen.dart';
import 'screens/my_care/medications_screen.dart';
import 'screens/my_care/medication_schedule_screen.dart';
import 'screens/my_care/add_edit_medication_screen.dart';
import 'screens/my_care/report_history_screen.dart';
import 'screens/my_care/attendance_history_screen.dart';
import 'screens/my_care/staff_otp_verification_screen.dart';
import 'screens/services/booking_confirmation_screen.dart';
import 'screens/services/my_orders_screen.dart';
import 'screens/consultation/video_consultation_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/orders/order_tracking_screen.dart';
import 'screens/rental/rental_agreement_screen.dart';
import 'screens/rental/return_screen.dart';
import 'screens/billing/emi_screen.dart';
import 'screens/support/staff_replacement_screen.dart';
import 'screens/settings/referral_screen.dart';
import 'models/my_care_models.dart';
import 'models/medication_models.dart';
import 'providers/my_care_provider.dart';
import 'providers/medication_provider.dart';
import 'services/medication_reminder_service.dart';
import 'utils/notification_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialise local medication reminders (no-op on web).
  if (!kIsWeb) {
    await MedicationReminderService().init();
  }

  final firebaseService = FirebaseService();
  final apiService = ApiService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(firebaseService, apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => AppProvider(apiService),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final cartProvider = CartProvider();
            cartProvider.loadFromStorage(); // fire and forget — loads async
            return cartProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => MyCareProvider(apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => MedicationProvider(apiService),
        ),
      ],
      child: const HousepitalApp(),
    ),
  );
}

class HousepitalApp extends StatefulWidget {
  const HousepitalApp({super.key});

  /// Global navigator key for notification routing from cold-start.
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<HousepitalApp> createState() => _HousepitalAppState();
}

class _HousepitalAppState extends State<HousepitalApp> {
  @override
  void initState() {
    super.initState();
    // Setup FCM after first frame so the navigator is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupFCM();
      _setupMedicationReminderTapHandler();
    });
  }

  void _setupMedicationReminderTapHandler() {
    if (kIsWeb) return;
    MedicationReminderService().onNotificationAction =
        (medicationId, action) {
      final ctx = HousepitalApp.navigatorKey.currentContext;
      if (ctx == null) return;

      if (action == 'taken') {
        // Navigate to the medication schedule so the user can confirm
        Navigator.pushNamed(ctx, '/medication-schedule');
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          const SnackBar(
            content: Text('Medication marked — confirm on the schedule'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // Plain tap — open the schedule screen
        Navigator.pushNamed(ctx, '/medication-schedule');
      }
    };
  }

  void _setupFCM() {
    final authProvider = context.read<AuthProvider>();
    final firebaseService = authProvider.firebaseService;
    final apiService = authProvider.apiService;

    firebaseService.setupFCM(
      apiService: apiService,
      navigatorKey: HousepitalApp.navigatorKey,
      onForegroundMessage: (message) {
        final ctx = HousepitalApp.navigatorKey.currentContext;
        if (ctx == null) return;
        NotificationRouter.showForegroundSnackBar(
          ctx,
          message.notification?.title,
          message.notification?.body,
          message.data,
        );
      },
      onMessageOpenedApp: (message) {
        final ctx = HousepitalApp.navigatorKey.currentContext;
        if (ctx == null) return;
        NotificationRouter.handleNotification(ctx, message.data);
      },
    );

    // Handle cold-start pending notification
    final pending = firebaseService.consumePendingNotification();
    if (pending != null) {
      final ctx = HousepitalApp.navigatorKey.currentContext;
      if (ctx != null) {
        NotificationRouter.handleNotification(ctx, pending);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return MaterialApp(
      title: 'Housepital',
      navigatorKey: HousepitalApp.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: HousepitalTheme.lightTheme,
      locale: appProvider.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // TODO: Restore auth gate before production
      // home: Consumer<AuthProvider>(...),
      home: MainShell(key: MainShell.shellKey),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/otp':
            return MaterialPageRoute(builder: (_) => const OtpScreen());
          case '/onboarding':
            return MaterialPageRoute(
                builder: (_) => const OnboardingScreen());
          case '/sos':
            return MaterialPageRoute(builder: (_) => const SOSScreen());
          case '/notifications':
            return MaterialPageRoute(
                builder: (_) => const NotificationsScreen());
          case '/settings':
            return MaterialPageRoute(
                builder: (_) => const SettingsScreen());
          case '/patient-profile':
            return MaterialPageRoute(
                builder: (_) => const PatientProfileScreen());
          case '/billing':
            return MaterialPageRoute(
                builder: (_) => const BillingScreen());
          case '/raise-concern':
            return MaterialPageRoute(
                builder: (_) => const RaiseConcernScreen());
          case '/vitals':
            final vitalType = settings.arguments as String?;
            return MaterialPageRoute(
                builder: (_) =>
                    VitalsScreen(initialVital: vitalType));
          case '/report-detail':
            final reportId = settings.arguments as String;
            return MaterialPageRoute(
                builder: (_) =>
                    DailyReportScreen(reportId: reportId));
          case '/staff-profile':
            final staffId = settings.arguments as String;
            return MaterialPageRoute(
                builder: (_) =>
                    StaffProfileScreen(staffId: staffId));
          case '/service-booking':
            final service = settings.arguments as ServiceItem;
            return MaterialPageRoute(
                builder: (_) =>
                    ServiceBookingScreen(service: service));
          case '/equipment-detail':
            final service = settings.arguments as ServiceItem;
            return MaterialPageRoute(
                builder: (_) =>
                    EquipmentDetailScreen(service: service));
          case '/assessment-request':
            final service = settings.arguments as ServiceItem;
            return MaterialPageRoute(
                builder: (_) =>
                    AssessmentRequestScreen(service: service));
          case '/invoice-detail':
            final args = settings.arguments;
            final invoiceId = args is Invoice ? args.id : (args as String?) ?? '';
            return MaterialPageRoute(
                builder: (_) => InvoiceDetailScreen(invoiceId: invoiceId));
          case '/transactions':
            return MaterialPageRoute(
                builder: (_) => const TransactionLogScreen());
          case '/payment':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
                builder: (_) => PaymentScreen(
                      amount: args['amount'] as int,
                      description: args['description'] as String,
                      invoiceId: args['invoice_id'] as String?,
                    ));
          case '/family-members':
            return MaterialPageRoute(
                builder: (_) => const FamilyMembersScreen());
          case '/notification-preferences':
            return MaterialPageRoute(
                builder: (_) => const NotificationPreferencesScreen());
          case '/help-faq':
            return MaterialPageRoute(
                builder: (_) => const HelpFaqScreen());
          case '/about':
            return MaterialPageRoute(
                builder: (_) => const AboutScreen());
          case '/cart':
            return MaterialPageRoute(
                builder: (_) => const CartScreen());
          case '/payment-methods':
            return MaterialPageRoute(
                builder: (_) => const PaymentMethodsScreen());
          case '/package-detail':
            final package = settings.arguments as CarePackage;
            return MaterialPageRoute(
                builder: (_) =>
                    PackageDetailScreen(package: package));
          case '/search':
            return MaterialPageRoute(
                builder: (_) => const UniversalSearchScreen());
          case '/documents':
            return MaterialPageRoute(
                builder: (_) => const DocumentRepositoryScreen());
          case '/services':
            return MaterialPageRoute(
                builder: (_) => const Scaffold());
          case '/service-detail':
            final service = settings.arguments as ActiveService;
            return MaterialPageRoute(
                builder: (_) =>
                    ServiceDetailScreen(service: service));
          case '/medications':
            return MaterialPageRoute(
                builder: (_) => const MedicationsScreen());
          case '/medication-schedule':
            return MaterialPageRoute(
                builder: (_) => const MedicationScheduleScreen());
          case '/add-medication':
            final medication = settings.arguments as MedicationFull?;
            return MaterialPageRoute(
                builder: (_) =>
                    AddEditMedicationScreen(medication: medication));
          case '/report-history':
            final deploymentId = settings.arguments as String;
            return MaterialPageRoute(
                builder: (_) =>
                    ReportHistoryScreen(deploymentId: deploymentId));
          case '/attendance-history':
            final deploymentId = settings.arguments as String;
            return MaterialPageRoute(
                builder: (_) =>
                    AttendanceHistoryScreen(deploymentId: deploymentId));
          case '/booking-confirmation':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
                builder: (_) => BookingConfirmationScreen(
                      serviceName: args['serviceName'] as String,
                      scheduledDate: args['scheduledDate'] as DateTime,
                      scheduledSlot: args['scheduledSlot'] as String,
                      totalAmount: args['totalAmount'] as int,
                    ));
          case '/booking-history':
            final tab = settings.arguments as int? ?? 0;
            return MaterialPageRoute(
                builder: (_) => MyOrdersScreen(initialTab: tab));
          case '/video-consultation':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
                builder: (_) => VideoConsultationScreen(
                      doctorName: args['doctorName'] as String,
                      doctorPhotoUrl: args['doctorPhotoUrl'] as String?,
                      roomId: args['roomId'] as String?,
                      token: args['token'] as String?,
                    ));
          case '/chat':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
                builder: (_) => ChatScreen(
                      patientId: args['patientId'] as String,
                      coordinatorName: args['coordinatorName'] as String,
                      coordinatorPhotoUrl:
                          args['coordinatorPhotoUrl'] as String?,
                    ));
          case '/staff-otp':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
                builder: (_) => StaffOtpVerificationScreen(
                      deploymentId: args['deploymentId'] as String,
                      staffName: args['staffName'] as String,
                      staffRole: args['staffRole'] as String,
                      staffPhotoUrl: args['staffPhotoUrl'] as String?,
                    ));
          case '/order-tracking':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
                builder: (_) => OrderTrackingScreen(
                      bookingId: args['bookingId'] as String,
                      orderType: (args['orderType'] as String?) ?? 'booking',
                    ));
          case '/rental-agreement':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
                builder: (_) => RentalAgreementScreen(
                      itemName: args['itemName'] as String,
                      monthlyRate: args['monthlyRate'] as int,
                      durationMonths: (args['durationMonths'] as int?) ?? 1,
                    ));
          case '/return-equipment':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
                builder: (_) => ReturnScreen(
                      orderId: args['orderId'] as String,
                      itemName: args['itemName'] as String,
                      rentalStartDate: args['rentalStartDate'] as DateTime,
                      monthlyRate: args['monthlyRate'] as int,
                    ));
          case '/emi-options':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
                builder: (_) => EmiScreen(
                      totalAmount: args['totalAmount'] as int,
                      itemName: args['itemName'] as String,
                    ));
          case '/staff-replacement':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
                builder: (_) => StaffReplacementScreen(
                      deploymentId: args['deploymentId'] as String,
                      staffName: args['staffName'] as String,
                      staffRole: args['staffRole'] as String,
                      staffPhoto: args['staffPhoto'] as String?,
                      assignedSince: args['assignedSince'] as DateTime?,
                    ));
          case '/referrals':
            return MaterialPageRoute(
                builder: (_) => const ReferralScreen());
          default:
            return MaterialPageRoute(
                builder: (_) => MainShell(key: MainShell.shellKey));
        }
      },
    );
  }
}
