import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
// audit batch 4 (Agent J): Crashlytics + Performance Monitoring wiring.
// Dependencies were added to pubspec.yaml by Agent H in this same batch.
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:provider/provider.dart';

import 'config/firebase_options.dart';
import 'config/theme.dart';
import 'models/models.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/billing_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/reminders_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'services/firebase_service.dart';
import 'utils/app_localizations.dart';

import 'screens/splash_screen.dart';
import 'screens/main_shell.dart';
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
import 'screens/settings/add_patient_screen.dart';
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
import 'providers/assistant_provider.dart';
import 'services/medication_reminder_service.dart';
import 'services/assistant_service.dart';
import 'services/voice_service.dart';
import 'screens/assistant/assistant_executor.dart';
import 'screens/assistant/assistant_local_actions.dart';
import 'screens/assistant/assistant_screen.dart';
import 'providers/blog_provider.dart';
import 'screens/articles/article_list_screen.dart';
import 'screens/articles/article_detail_screen.dart';
import 'screens/care_team/care_team_screen.dart';
import 'screens/calendar/care_calendar_screen.dart';
import 'config/constants.dart';
import 'data/demo_data.dart';
import 'utils/permissions.dart';
import 'utils/notification_router.dart';

void main() async {
  // audit batch 4 (Agent J): wrap the whole app in runZonedGuarded so async
  // errors (futures that never get awaited, timers, etc.) are captured by
  // Crashlytics instead of silently going to the console.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // ── audit batch 4 (Agent J) / batch 5 web fix ────────────────────────
    // Crashlytics + Performance are MOBILE-ONLY Firebase products — there is
    // no web implementation, so touching FirebaseCrashlytics.instance /
    // FirebasePerformance.instance on web throws an assertion that aborts
    // main() before runApp() (symptom: blank white screen on Chrome).
    // The real guard axis is platform (kIsWeb), not build mode (kDebugMode).
    if (!kIsWeb) {
      // Production-only: in debug we want errors loud in the console, not
      // shipped to a remote sink that won't surface them for hours.
      if (!kDebugMode) {
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(true);
        await FirebasePerformance.instance
            .setPerformanceCollectionEnabled(true);
      } else {
        // In debug builds, keep both surfaces off so test runs and hot reloads
        // don't pollute the production project.
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(false);
        await FirebasePerformance.instance
            .setPerformanceCollectionEnabled(false);
      }
    }

    // audit batch 4 (Agent J): friendly fallback when a widget build throws.
    // Default ErrorWidget shows the red error screen which is fine in debug
    // but terrifies users in production. This keeps the app navigable.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // Still log in debug so devs see what failed.
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
      return Material(
        color: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 12),
                Text(
                  "Something went wrong showing this screen.",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  "We've logged the issue. Please go back and try again.",
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    };

    // Initialise local medication reminders (no-op on web).
    if (!kIsWeb) {
      await MedicationReminderService().init();
    }

    final firebaseService = FirebaseService();
    final apiService = ApiService();

    // audit batch 4 (Agent J): construct AuthProvider eagerly so we can wire
    // its `handleUnauthorized` into ApiService.onUnauthorized — the API
    // client doesn't depend on AuthProvider directly (no circular import);
    // it only takes a callback.
    final authProvider = AuthProvider(firebaseService, apiService);
    apiService.onUnauthorized = authProvider.handleUnauthorized;

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider(
            create: (_) => AppProvider(apiService),
          ),
          // audit batch 4 (Agent J): wire BillingProvider into the tree. It
          // was previously orphaned (defined but never provided). BillingScreen
          // still reads off AppProvider today — see TODO in billing_screen.dart
          // to migrate to BillingProvider in a follow-up.
          ChangeNotifierProvider(
            create: (_) => BillingProvider(apiService),
          ),
          ChangeNotifierProvider(
            create: (_) {
              final cartProvider = CartProvider();
              cartProvider.loadFromStorage(); // fire and forget — loads async
              return cartProvider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) => OrdersProvider(),
          ),
          // Care Calendar quick-add reminders (SharedPreferences-persisted).
          ChangeNotifierProvider(
            create: (_) => RemindersProvider()..load(),
          ),
          ChangeNotifierProvider(
            create: (_) => MyCareProvider(apiService),
          ),
          ChangeNotifierProvider(
            create: (_) => MedicationProvider(apiService),
          ),
          // Care Guides — articles/blogs with demo fallback.
          ChangeNotifierProvider(
            create: (_) => BlogProvider(apiService),
          ),
          // AI Assistant — voice+text Hinglish bot. Stub-backed until the
          // backend /assistant endpoint ships; voice no-ops on web.
          ChangeNotifierProvider(
            create: (ctx) {
              final patientId = DemoData.patient.id;
              // Demo mode: the signed-in user is the primary contact.
              const role = UserRole.primaryContact;
              final hm = DemoData.healthManager;
              final contacts = <String, AssistantContact>{
                'health_manager':
                    AssistantContact(name: hm.name, phone: hm.phone),
                'nurse': const AssistantContact(
                    name: 'Care team', phone: AppConstants.supportPhone),
                'sos': const AssistantContact(
                    name: 'Emergency', phone: AppConstants.emergencyPhone),
              };
              // Real Claude-powered assistant when ASSISTANT_API_URL is set at
              // build time (the Firebase Cloud Function URL); otherwise the
              // offline Hinglish keyword stub so the feature still works.
              final assistantUrl = AppConstants.assistantApiUrl;
              return AssistantProvider(
                service: AssistantService(
                  useStub: assistantUrl.isEmpty,
                  assistantUrl: assistantUrl.isEmpty ? null : assistantUrl,
                ),
                executor: AssistantExecutor(
                  api: apiService,
                  role: role,
                  patientId: patientId,
                  contacts: contacts,
                  deploymentId: DemoData.icuDeployment.id,
                  // Demo-first action sink: real local cart adds + local
                  // quote-pending bookings when the backend is unreachable,
                  // so the assistant's actions WORK offline.
                  local: AssistantLocalActions(
                    cart: ctx.read<CartProvider>(),
                    orders: ctx.read<OrdersProvider>(),
                  ),
                ),
                voice: kIsWeb ? NoopVoiceService() : PluginVoiceService(),
                patientId: patientId,
                role: role,
                locale: 'hi',
              );
            },
          ),
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(),
          ),
        ],
        child: const HousepitalApp(),
      ),
    );
  }, (error, stack) {
    // audit batch 4 (Agent J) / batch 5 web fix: uncaught async errors land
    // here. Crashlytics is mobile-only — guard on kIsWeb so the error handler
    // itself doesn't throw on web (which would mask the original error).
    if (!kDebugMode && !kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } else {
      // ignore: avoid_print
      debugPrint('Uncaught zone error: $error\n$stack');
    }
  });
}

class HousepitalApp extends StatefulWidget {
  const HousepitalApp({super.key});

  /// Global navigator key for notification routing from cold-start.
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<HousepitalApp> createState() => _HousepitalAppState();
}

class _HousepitalAppState extends State<HousepitalApp> {
  /// Friendly fallback when a route is invoked with missing or wrong-shaped
  /// arguments. Better than crashing with a TypeError on `as X`.
  MaterialPageRoute _argErrorRoute() {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Navigation Error')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Missing or invalid navigation data. Please go back and try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

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
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Housepital',
      navigatorKey: HousepitalApp.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: HousepitalTheme.lightTheme,
      darkTheme: HousepitalTheme.darkTheme,
      themeMode: themeProvider.mode,
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
      // NOTE: Auth gate disabled for demo mode. Enable before production release.
      // home: Consumer<AuthProvider>(...),
      home: const SplashScreen(),
      // Clamp system text scaling so layouts don't break at extreme accessibility
      // settings, but still honour user preference up to 1.4x (WCAG 1.4.4).
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.4,
            ),
          ),
          child: child!,
        );
      },
      onGenerateRoute: (settings) {
        try {
        switch (settings.name) {
          case '/home':
            return MaterialPageRoute(
                builder: (_) => MainShell(key: MainShell.shellKey));
          case '/assistant':
            return MaterialPageRoute(
                builder: (_) => const AssistantScreen());
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
            final args = settings.arguments;
            final reportId = args is String
                ? args
                : args is DailyReport
                    ? (args).id
                    : '';
            return MaterialPageRoute(
                builder: (_) =>
                    DailyReportScreen(reportId: reportId));
          case '/staff-profile':
            final raw = settings.arguments;
            if (raw is! String) return _argErrorRoute();
            return MaterialPageRoute(
                builder: (_) => StaffProfileScreen(staffId: raw));
          case '/service-booking':
            final raw = settings.arguments;
            if (raw is! ServiceItem) return _argErrorRoute();
            return MaterialPageRoute(
                builder: (_) => ServiceBookingScreen(service: raw));
          case '/equipment-detail':
            final raw = settings.arguments;
            if (raw is! ServiceItem) return _argErrorRoute();
            return MaterialPageRoute(
                builder: (_) => EquipmentDetailScreen(service: raw));
          case '/assessment-request':
            final raw = settings.arguments;
            if (raw is! ServiceItem) return _argErrorRoute();
            return MaterialPageRoute(
                builder: (_) => AssessmentRequestScreen(service: raw));
          case '/invoice-detail':
            final args = settings.arguments;
            final invoiceId = args is Invoice ? args.id : (args as String?) ?? '';
            return MaterialPageRoute(
                builder: (_) => InvoiceDetailScreen(invoiceId: invoiceId));
          case '/transactions':
            return MaterialPageRoute(
                builder: (_) => const TransactionLogScreen());
          case '/payment':
            final raw = settings.arguments;
            if (raw is! Map<String, dynamic>) return _argErrorRoute();
            final amount = raw['amount'];
            final description = raw['description'];
            if (amount is! int || description is! String) {
              return _argErrorRoute();
            }
            return MaterialPageRoute(
                builder: (_) => PaymentScreen(
                      amount: amount,
                      description: description,
                      invoiceId: raw['invoice_id'] as String?,
                    ));
          case '/family-members':
            return MaterialPageRoute(
                builder: (_) => const FamilyMembersScreen());
          case '/add-patient':
            return MaterialPageRoute(
                builder: (_) => const AddPatientScreen());
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
            final raw = settings.arguments;
            if (raw is! CarePackage) return _argErrorRoute();
            return MaterialPageRoute(
                builder: (_) => PackageDetailScreen(package: raw));
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
            final raw = settings.arguments;
            if (raw is! Map<String, dynamic>) return _argErrorRoute();
            final totalAmount = raw['totalAmount'];
            if (totalAmount is! int) return _argErrorRoute();
            return MaterialPageRoute(
                builder: (_) => BookingConfirmationScreen(
                      cartItems: raw['cartItems'] as List<CartItem>?,
                      totalAmount: totalAmount,
                      serviceName: raw['serviceName'] as String?,
                      scheduledDate: raw['scheduledDate'] as DateTime?,
                      scheduledSlot: raw['scheduledSlot'] as String?,
                      // audit M-2: propagate booking number from cart.
                      bookingNumber: raw['bookingNumber'] as String?,
                      // Quote-first orders (manpower / price-on-request):
                      // render "Quote pending" instead of any ₹ figure.
                      quotePending: raw['quotePending'] as bool? ?? false,
                    ));
          case '/booking-history':
          case '/my-orders':
            // /booking-history kept as an alias for legacy in-app links.
            final tab = settings.arguments as int? ?? 0;
            return MaterialPageRoute(
                builder: (_) => MyOrdersScreen(initialTab: tab));
          case '/video-consultation':
            final raw = settings.arguments;
            if (raw is! Map<String, dynamic>) return _argErrorRoute();
            final doctorName = raw['doctorName'];
            if (doctorName is! String) return _argErrorRoute();
            return MaterialPageRoute(
                builder: (_) => VideoConsultationScreen(
                      doctorName: doctorName,
                      doctorPhotoUrl: raw['doctorPhotoUrl'] as String?,
                      roomId: raw['roomId'] as String?,
                      token: raw['token'] as String?,
                    ));
          case '/chat':
            final raw = settings.arguments;
            if (raw is! Map<String, dynamic>) return _argErrorRoute();
            final patientId = raw['patientId'];
            final coordinatorName = raw['coordinatorName'];
            if (patientId is! String || coordinatorName is! String) {
              return _argErrorRoute();
            }
            return MaterialPageRoute(
                builder: (_) => ChatScreen(
                      patientId: patientId,
                      coordinatorName: coordinatorName,
                      coordinatorPhotoUrl: raw['coordinatorPhotoUrl'] as String?,
                    ));
          case '/staff-otp':
            final raw = settings.arguments;
            if (raw is! Map<String, dynamic>) return _argErrorRoute();
            final deploymentId = raw['deploymentId'];
            final staffName = raw['staffName'];
            final staffRole = raw['staffRole'];
            if (deploymentId is! String ||
                staffName is! String ||
                staffRole is! String) {
              return _argErrorRoute();
            }
            return MaterialPageRoute(
                builder: (_) => StaffOtpVerificationScreen(
                      deploymentId: deploymentId,
                      staffName: staffName,
                      staffRole: staffRole,
                      staffPhotoUrl: raw['staffPhotoUrl'] as String?,
                    ));
          case '/order-tracking':
            final raw = settings.arguments;
            if (raw is! Map<String, dynamic>) return _argErrorRoute();
            final bookingId = raw['bookingId'];
            if (bookingId is! String) return _argErrorRoute();
            return MaterialPageRoute(
                builder: (_) => OrderTrackingScreen(
                      bookingId: bookingId,
                      // Quote-first orders show a "Quote pending" banner
                      // instead of any amount.
                      quotePending: raw['quotePending'] as bool? ?? false,
                      orderType: (raw['orderType'] as String?) ?? 'booking',
                    ));
          case '/rental-agreement':
            final raw = settings.arguments;
            if (raw is! Map<String, dynamic>) return _argErrorRoute();
            final itemName = raw['itemName'];
            final monthlyRate = raw['monthlyRate'];
            if (itemName is! String || monthlyRate is! int) {
              return _argErrorRoute();
            }
            return MaterialPageRoute(
                builder: (_) => RentalAgreementScreen(
                      itemName: itemName,
                      monthlyRate: monthlyRate,
                      durationMonths: (raw['durationMonths'] as int?) ?? 1,
                    ));
          case '/return-equipment':
            final raw = settings.arguments;
            if (raw is! Map<String, dynamic>) return _argErrorRoute();
            final orderId = raw['orderId'];
            final itemName = raw['itemName'];
            final rentalStartDate = raw['rentalStartDate'];
            final monthlyRate = raw['monthlyRate'];
            if (orderId is! String ||
                itemName is! String ||
                rentalStartDate is! DateTime ||
                monthlyRate is! int) {
              return _argErrorRoute();
            }
            return MaterialPageRoute(
                builder: (_) => ReturnScreen(
                      orderId: orderId,
                      itemName: itemName,
                      rentalStartDate: rentalStartDate,
                      monthlyRate: monthlyRate,
                    ));
          case '/emi-options':
            final raw = settings.arguments;
            if (raw is! Map<String, dynamic>) return _argErrorRoute();
            final totalAmount = raw['totalAmount'];
            final itemName = raw['itemName'];
            if (totalAmount is! int || itemName is! String) {
              return _argErrorRoute();
            }
            return MaterialPageRoute(
                builder: (_) => EmiScreen(
                      totalAmount: totalAmount,
                      itemName: itemName,
                    ));
          case '/staff-replacement':
            final raw = settings.arguments;
            if (raw is! Map<String, dynamic>) return _argErrorRoute();
            final deploymentId = raw['deploymentId'];
            final staffName = raw['staffName'];
            final staffRole = raw['staffRole'];
            if (deploymentId is! String ||
                staffName is! String ||
                staffRole is! String) {
              return _argErrorRoute();
            }
            return MaterialPageRoute(
                builder: (_) => StaffReplacementScreen(
                      deploymentId: deploymentId,
                      staffName: staffName,
                      staffRole: staffRole,
                      staffPhoto: raw['staffPhoto'] as String?,
                      assignedSince: raw['assignedSince'] as DateTime?,
                    ));
          case '/care-calendar':
            return MaterialPageRoute(
                builder: (_) => const CareCalendarScreen());
          case '/care-team':
            return MaterialPageRoute(
                builder: (_) => const CareTeamScreen());
          case '/referrals':
            return MaterialPageRoute(
                builder: (_) => const ReferralScreen());
          case '/articles':
            return MaterialPageRoute(
                builder: (_) => const ArticleListScreen());
          case '/article':
            final id = settings.arguments;
            if (id is! String) {
              throw ArgumentError('Route /article requires a String id');
            }
            return MaterialPageRoute(
                builder: (_) => ArticleDetailScreen(articleId: id));
          default:
            return MaterialPageRoute(
                builder: (_) => MainShell(key: MainShell.shellKey));
        }
        } catch (e) {
          debugPrint('Route error for ${settings.name}: $e');
          return MaterialPageRoute(
            builder: (ctx) => Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Navigation error: ${settings.name}',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('$e', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
