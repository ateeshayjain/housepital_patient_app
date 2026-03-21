import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

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
import 'models/my_care_models.dart';
import 'models/medication_models.dart';
import 'providers/my_care_provider.dart';
import 'providers/medication_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase — uncomment after adding google-services.json / GoogleService-Info.plist
  // await Firebase.initializeApp();

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
          create: (_) => CartProvider(),
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

class HousepitalApp extends StatelessWidget {
  const HousepitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return MaterialApp(
      title: 'Housepital',
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
      // TODO: Restore auth gate after Firebase is configured
      // home: Consumer<AuthProvider>(
      //   builder: (context, auth, _) {
      //     switch (auth.state) {
      //       case AuthState.authenticated:
      //         return const MainShell();
      //       case AuthState.onboarding:
      //         return const OnboardingScreen();
      //       case AuthState.otpSent:
      //         return const OtpScreen();
      //       default:
      //         return const LoginScreen();
      //     }
      //   },
      // ),
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
          default:
            return MaterialPageRoute(
                builder: (_) => MainShell(key: MainShell.shellKey));
        }
      },
    );
  }
}
