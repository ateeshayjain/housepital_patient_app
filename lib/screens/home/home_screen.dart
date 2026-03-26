import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../services/payment_reminder_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../utils/vital_classifier.dart';
import '../../widgets/common_widgets.dart';
import '../main_shell.dart';
import '../services/service_catalog_screen.dart';
import '../support/raise_concern_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _dutyTimer;
  Duration _onDutySince = Duration.zero;
  List<PaymentReminder> _paymentReminders = [];

  // Banner carousel
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _currentBannerPage = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<AppProvider>().loadPatients().then((_) {
        context.read<AppProvider>().loadDashboard();
      });
    });
    _startDutyTimer();
    _loadPaymentReminders();
    _startBannerAutoScroll();
  }

  Future<void> _loadPaymentReminders() async {
    final service = PaymentReminderService(apiService: ApiService());
    final reminders = await service.getUpcomingReminders();
    if (mounted) {
      setState(() => _paymentReminders = reminders);
    }
  }

  void _startDutyTimer() {
    _dutyTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final attendance = context.read<AppProvider>().todayAttendance;
      if (attendance?.checkInTime != null && mounted) {
        setState(() {
          _onDutySince = DateTime.now().difference(attendance!.checkInTime!);
        });
      }
    });
  }

  void _startBannerAutoScroll() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      final nextPage = (_currentBannerPage + 1) % 3;
      _bannerController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _dutyTimer?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final app = context.watch<AppProvider>();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: HousepitalColors.orange,
          onRefresh: () => app.loadDashboard(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, l, app),
                _buildHeroBanner(context),
                _buildGreeting(context, app),
                if (app.isDashboardLoading)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: LoadingWidget(),
                  )
                else ...[
                  // 1. Your Health Team
                  _sectionLabel('Your Health Team', onSeeAll: () => MainShell.switchToTab(1)),
                  _buildHealthTeamCard(context, l, app),

                  // 2. Current Services
                  if (app.activeDeployment != null) ...[
                    _sectionLabel('Current Services', onSeeAll: () => MainShell.switchToTab(1)),
                    _buildActiveServicesQuickView(context, l, app),
                  ],

                  // 3. Today's Vitals
                  if (app.latestVitals != null) ...[
                    _sectionLabel("Today's Vitals", onSeeAll: () => Navigator.pushNamed(context, '/vitals')),
                    _buildVitalsStrip(app),
                  ],

                  // 4. Book Services
                  _sectionLabel('Book Services', onSeeAll: () => MainShell.switchToTab(2)),
                  _buildQuickActionsGrid(context, l),

                  // 5. Today's Report
                  if (app.todayReport != null) ...[
                    _sectionLabel("Today's Report", onSeeAll: () => Navigator.pushNamed(context, '/report-detail', arguments: app.todayReport)),
                    _buildReportSnippet(app),
                  ],

                  // 6. Upcoming Payments
                  _sectionLabel('Upcoming Payments', onSeeAll: () => MainShell.switchToTab(3)),
                  _buildPaymentBanner(context, l, app),

                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, AppLocalizations l, AppProvider app) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HOUSEPITAL',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: HousepitalColors.orange,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                if (app.currentPatient != null && app.patients.length > 1)
                  Semantics(
                    label: 'Switch patient. Current: ${app.currentPatient!.name}',
                    button: true,
                    child: InkWell(
                      onTap: () => _showPatientSwitcher(context, app),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.t('dashboard_care',
                                  {'name': app.currentPatient!.name}),
                              style: const TextStyle(
                                fontSize: 14,
                                color: HousepitalColors.grey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down,
                                color: HousepitalColors.grey, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Semantics(
            label: 'Search',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.pushNamed(context, '/search'),
            ),
          ),
          Consumer<CartProvider>(
            builder: (_, cart, __) => Semantics(
              label: 'Cart${cart.itemCount > 0 ? ", ${cart.itemCount} items" : ""}',
              button: true,
              child: IconButton(
                icon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text('${cart.itemCount}',
                      style: const TextStyle(fontSize: 11)),
                  backgroundColor: HousepitalColors.orange,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                onPressed: () => Navigator.pushNamed(context, '/cart'),
              ),
            ),
          ),
          Semantics(
            label: 'Notifications',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero Banner Carousel
  // ---------------------------------------------------------------------------
  Widget _buildHeroBanner(BuildContext context) {
    final slides = [
      _BannerSlide(
        title: 'Hospital-like Expertise,\nHome-like Care',
        subtitle: 'Trusted by 5,000+ families in Delhi NCR',
        gradientColors: [const Color(0xFFFF8C00), const Color(0xFFFF6B35)],
        icon: Icons.home_filled,
      ),
      _BannerSlide(
        title: '24/7 ICU Setup\nat Home',
        subtitle: 'Critical care nursing & medical equipment',
        gradientColors: [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
        icon: Icons.monitor_heart,
      ),
      _BannerSlide(
        title: 'Free Health\nAssessment',
        subtitle: 'Book now — no obligations',
        gradientColors: [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
        icon: Icons.health_and_safety,
        ctaText: 'Book Now',
        onCtaTap: () {
          MainShell.switchToTab(2);
          ServiceCatalogScreen.switchToSubTab(0);
        },
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (index) {
              setState(() => _currentBannerPage = index);
            },
            itemCount: slides.length,
            itemBuilder: (context, index) {
              final slide = slides[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: slide.gradientColors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: slide.gradientColors.first.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                slide.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                slide.subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              if (slide.ctaText != null) ...[
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: slide.onCtaTap,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      slide.ctaText!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: slide.gradientColors.first,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          slide.icon,
                          size: 56,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentBannerPage == index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentBannerPage == index
                    ? HousepitalColors.orange
                    : HousepitalColors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Personal Greeting
  // ---------------------------------------------------------------------------
  Widget _buildGreeting(BuildContext context, AppProvider app) {
    final patientName = app.currentPatient?.name ?? 'there';
    final firstName = patientName.split(' ').first;
    final hasActiveService = app.activeDeployment != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi $firstName!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: HousepitalColors.orangeText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hasActiveService
                ? "Here's your care summary"
                : 'Welcome back',
            style: const TextStyle(
              fontSize: 14,
              color: HousepitalColors.greyLight,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Health Team Card
  // ---------------------------------------------------------------------------
  Widget _buildHealthTeamCard(
      BuildContext context, AppLocalizations l, AppProvider app) {
    final deployment = app.activeDeployment;
    final patient = app.currentPatient;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: HousepitalColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.groups, color: HousepitalColors.orange, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Your Health Team',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: HousepitalColors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (deployment != null) ...[
                _TeamMemberRow(
                  role: 'Health Manager',
                  name: 'Housepital Care Team',
                  icon: Icons.support_agent,
                  color: HousepitalColors.orange,
                  phone: AppConstants.supportPhone,
                ),
                const SizedBox(height: 6),
                _TeamMemberRow(
                  role: deployment.staffRole ?? 'Staff',
                  name: deployment.staffName ?? 'Assigned',
                  icon: Icons.medical_services,
                  color: HousepitalColors.serviceNursing,
                  phone: AppConstants.supportPhone,
                ),
                if (patient?.doctorName != null &&
                    patient!.doctorName!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _TeamMemberRow(
                    role: 'Doctor',
                    name: patient.doctorName!,
                    icon: Icons.medical_information,
                    color: HousepitalColors.servicePhysio,
                    phone: patient.doctorPhone,
                  ),
                ],
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: HousepitalColors.greyLight, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your care team will appear here once services are active',
                          style: TextStyle(
                            fontSize: 13,
                            color: HousepitalColors.greyLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Active Services Quick View
  // ---------------------------------------------------------------------------
  Widget _buildActiveServicesQuickView(
      BuildContext context, AppLocalizations l, AppProvider app) {
    final deployment = app.activeDeployment;
    if (deployment == null) return const SizedBox.shrink();

    final attendance = app.todayAttendance;
    final status = attendance?.status ?? 'waiting';
    final statusColor = AttendanceHelper.getStatusColor(status);
    final daysRemaining = deployment.endDate != null
        ? deployment.endDate!.difference(DateTime.now()).inDays
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: GestureDetector(
        onTap: () => MainShell.switchToTab(1),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HousepitalColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HousepitalColors.divider),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HousepitalColors.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medical_services, color: HousepitalColors.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deployment.staffRole ?? 'Care Service',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      deployment.staffName ?? 'Assigned',
                      style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight),
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status == 'checked_in' ? 'On Duty' : 'Waiting',
                style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500),
              ),
              if (daysRemaining != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${daysRemaining}d left',
                  style: const TextStyle(fontSize: 11, color: HousepitalColors.greyLight),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: HousepitalColors.greyLight, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Vitals with color-coded status dots
  // ---------------------------------------------------------------------------
  Widget _buildVitalsHighlights(
      BuildContext context, AppLocalizations l, AppProvider app) {
    final vitals = app.latestVitals;

    Color _vitalStatusColor(String type, double? value) {
      if (value == null) return HousepitalColors.greyLight;
      final zone = classifyVital(type, value);
      switch (zone) {
        case 'green':
          return HousepitalColors.vitalNormal;
        case 'yellow':
          return HousepitalColors.vitalBorderline;
        case 'red':
          return HousepitalColors.vitalAlert;
        default:
          return HousepitalColors.greyLight;
      }
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        SectionHeader(
          title: l.t('todays_vitals'),
          actionText: l.t('see_all'),
          onAction: () => Navigator.pushNamed(context, '/vitals'),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 72,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _VitalPill(
                label: 'BP',
                value: vitals?.systolic != null
                    ? '${vitals!.systolic!.toInt()}/${vitals.diastolic?.toInt() ?? ""}'
                    : '--',
                unit: 'mmHg',
                color: _vitalStatusColor('bp_systolic', vitals?.systolic),
                onTap: () => Navigator.pushNamed(context, '/vitals', arguments: 'bp'),
              ),
              _VitalPill(
                label: 'SpO2',
                value: vitals?.spo2?.toInt().toString() ?? '--',
                unit: '%',
                color: _vitalStatusColor('spo2', vitals?.spo2),
                onTap: () => Navigator.pushNamed(context, '/vitals', arguments: 'spo2'),
              ),
              _VitalPill(
                label: 'Pulse',
                value: vitals?.pulse?.toInt().toString() ?? '--',
                unit: 'bpm',
                color: _vitalStatusColor('pulse', vitals?.pulse),
                onTap: () => Navigator.pushNamed(context, '/vitals', arguments: 'pulse'),
              ),
              _VitalPill(
                label: 'Temp',
                value: vitals?.temperature?.toStringAsFixed(1) ?? '--',
                unit: '\u00B0F',
                color: _vitalStatusColor('temperature', vitals?.temperature),
                onTap: () => Navigator.pushNamed(context, '/vitals', arguments: 'temperature'),
              ),
              _VitalPill(
                label: 'Sugar',
                value: vitals?.sugar?.toInt().toString() ?? '--',
                unit: 'mg/dl',
                color: _vitalStatusColor('sugar', vitals?.sugar),
                onTap: () => Navigator.pushNamed(context, '/vitals', arguments: 'sugar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Quick Actions Grid (2x3)
  // ---------------------------------------------------------------------------
  Widget _buildQuickActionsGrid(BuildContext context, AppLocalizations l) {
    final actions = [
      _QuickAction(
        icon: Icons.medical_services,
        label: 'Book Nurse',
        color: HousepitalColors.serviceNursing,
        onTap: () {
          MainShell.switchToTab(2);
          ServiceCatalogScreen.switchToSubTab(0);
        },
      ),
      _QuickAction(
        icon: Icons.local_shipping,
        label: 'Book Equipment',
        color: HousepitalColors.serviceEquipment,
        onTap: () {
          MainShell.switchToTab(2);
          ServiceCatalogScreen.switchToSubTab(1);
        },
      ),
      _QuickAction(
        icon: Icons.science,
        label: 'Lab Tests',
        color: HousepitalColors.servicePhysio,
        onTap: () {
          MainShell.switchToTab(2);
          ServiceCatalogScreen.switchToSubTab(5);
        },
      ),
      _QuickAction(
        icon: Icons.medical_information,
        label: 'Doctor Visit',
        color: HousepitalColors.serviceCarePackage,
        onTap: () {
          MainShell.switchToTab(2);
          ServiceCatalogScreen.switchToSubTab(2);
        },
      ),
      _QuickAction(
        icon: Icons.receipt_long,
        label: 'My Orders',
        color: HousepitalColors.serviceJapaNanny,
        onTap: () => Navigator.pushNamed(context, '/booking-history'),
      ),
      _QuickAction(
        icon: Icons.emergency,
        label: 'SOS',
        color: HousepitalColors.error,
        onTap: () => Navigator.pushNamed(context, '/sos'),
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: HousepitalColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HousepitalColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((action) {
          return Expanded(
            child: GestureDetector(
              onTap: action.onTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(action.icon, color: action.color, size: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: HousepitalColors.grey,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section Label with "See All"
  // ---------------------------------------------------------------------------
  Widget _sectionLabel(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: HousepitalColors.black)),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('See All',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500, color: HousepitalColors.orange)),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Vitals Strip (compact)
  // ---------------------------------------------------------------------------
  Widget _buildVitalsStrip(AppProvider app) {
    final v = app.latestVitals!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _miniVitalChip('BP', '${v.systolic?.toInt() ?? "--"}/${v.diastolic?.toInt() ?? "--"}', v.systolic, 'bp_systolic'),
          _miniVitalChip('SpO2', '${v.spo2?.toInt() ?? "--"}%', v.spo2, 'spo2'),
          _miniVitalChip('Pulse', '${v.pulse?.toInt() ?? "--"}', v.pulse, 'pulse'),
          _miniVitalChip('Temp', '${v.temperature ?? "--"}°F', v.temperature, 'temperature'),
          _miniVitalChip('Sugar', '${v.sugar?.toInt() ?? "--"}', v.sugar, 'sugar'),
        ],
      ),
    );
  }

  Widget _miniVitalChip(String label, String value, double? raw, String type) {
    Color dot = HousepitalColors.greyLight;
    if (raw != null) {
      final s = classifyVital(type, raw);
      dot = s == 'green' ? HousepitalColors.success : s == 'yellow' ? HousepitalColors.warning : HousepitalColors.error;
    }
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/vitals'),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: HousepitalColors.white,
            borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HousepitalColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: HousepitalColors.greyLight)),
            ]),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Report Snippet
  // ---------------------------------------------------------------------------
  Widget _buildReportSnippet(AppProvider app) {
    final r = app.todayReport!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HousepitalColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HousepitalColors.divider),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40, height: 40,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: r.totalTasks > 0 ? r.completedTasks / r.totalTasks : 0,
                  backgroundColor: HousepitalColors.greyLighter,
                  color: HousepitalColors.success,
                  strokeWidth: 3,
                ),
                Text('${r.completedTasks}/${r.totalTasks}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.completedTasks} of ${r.totalTasks} tasks done', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (r.staffNotes != null)
                    Text(r.staffNotes!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: HousepitalColors.greyLight)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: HousepitalColors.greyLight, size: 18),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Medications Snippet
  // ---------------------------------------------------------------------------
  Widget _buildMedicationsSnippet(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/medications'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: HousepitalColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HousepitalColors.divider),
          ),
          child: const Row(
            children: [
              Icon(Icons.medication, color: HousepitalColors.orange, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('5 active medications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('Next: Pantoprazole at 7:00 AM', style: TextStyle(fontSize: 11, color: HousepitalColors.greyLight)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: HousepitalColors.greyLight, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Daily Report Section (legacy — kept for reference)
  // ---------------------------------------------------------------------------
  Widget _buildDailyReportSection(
      BuildContext context, AppLocalizations l, AppProvider app) {
    final report = app.todayReport;

    return Column(
      children: [
        const SizedBox(height: 8),
        SectionHeader(
          title: l.t('todays_report'),
          actionText: l.t('details'),
          onAction: () {
            if (report != null) {
              Navigator.pushNamed(context, '/report-detail',
                  arguments: report.id);
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: HousepitalCard(
            onTap: () {
              if (report != null) {
                Navigator.pushNamed(context, '/report-detail',
                    arguments: report.id);
              }
            },
            child: report != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Semantics(
                            label:
                                '${report.completedTasks} of ${report.totalTasks} tasks completed',
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: CustomPaint(
                                painter: _ProgressRingPainter(
                                  progress: report.totalTasks > 0
                                      ? report.completedTasks /
                                          report.totalTasks
                                      : 0,
                                  color: HousepitalColors.orange,
                                  backgroundColor: HousepitalColors.greyLighter,
                                  strokeWidth: 8,
                                ),
                                child: Center(
                                  child: Text(
                                    '${report.completedTasks}/${report.totalTasks}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: HousepitalColors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.t('completion', {
                                    'percent': report.completionPercent
                                        .toInt()
                                        .toString(),
                                    'done':
                                        report.completedTasks.toString(),
                                    'total':
                                        report.totalTasks.toString(),
                                  }),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: HousepitalColors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tasks completed today',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: HousepitalColors.greyLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      ...report.sections.map((section) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  section.status == 'done'
                                      ? Icons.check_circle
                                      : section.status == 'partial'
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: section.status == 'done'
                                      ? HousepitalColors.success
                                      : section.status == 'partial'
                                          ? HousepitalColors.warning
                                          : HousepitalColors.greyLight,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    section.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: HousepitalColors.black,
                                    ),
                                  ),
                                ),
                                Text(
                                  _sectionTaskCount(section),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: HousepitalColors.greyLight,
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Semantics(
                          label: 'View full daily report',
                          button: true,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pushNamed(
                                context, '/report-detail',
                                arguments: report.id),
                            child: const Text('View Full Report'),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l.t('no_data'),
                        style: const TextStyle(
                            color: HousepitalColors.greyLight),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  String _sectionTaskCount(dynamic section) {
    final tasks = section.tasks;
    final done = tasks.where((t) => t.completed).length;
    return '$done/${tasks.length}';
  }

  // ---------------------------------------------------------------------------
  // Payment Reminders
  // ---------------------------------------------------------------------------
  Widget _buildPaymentBanner(
      BuildContext context, AppLocalizations l, AppProvider app) {
    final reminders = _paymentReminders;
    final urgentReminders =
        reminders.where((r) => r.shouldShowReminder).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (urgentReminders.isNotEmpty)
            ...urgentReminders.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: r.urgencyColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: r.urgencyColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.notifications_active,
                                color: r.urgencyColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                r.urgencyLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: r.urgencyColor,
                                ),
                              ),
                            ),
                            if (!r.autoPayEnabled)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Auto-pay OFF',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: HousepitalColors.greyLight)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          r.serviceName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateHelper.formatCurrency(r.amount.toInt()),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: HousepitalColors.orangeText,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                      context, '/payment-methods'),
                                  child: const Text('Set up Auto-pay',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: HousepitalColors.greyLight)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pushNamed(
                                      context, '/billing'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    backgroundColor: r.urgencyColor,
                                  ),
                                  child: const Text('Pay Now',
                                      style: TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
          if (reminders.length > urgentReminders.length) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _showAllReminders(context, reminders),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule,
                        color: HousepitalColors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${reminders.length - urgentReminders.length} more upcoming payment${reminders.length - urgentReminders.length > 1 ? "s" : ""}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 18, color: HousepitalColors.greyLight),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAllReminders(
      BuildContext context, List<PaymentReminder> reminders) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: HousepitalColors.orange),
                  SizedBox(width: 10),
                  Text('Upcoming Payments',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: reminders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final r = reminders[i];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 40,
                          decoration: BoxDecoration(
                            color: r.urgencyColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.serviceName,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(r.urgencyLabel,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: r.urgencyColor,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              DateHelper.formatCurrency(r.amount.toInt()),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: HousepitalColors.orangeText),
                            ),
                            Text(r.billingCycle,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: HousepitalColors.greyLight)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/payment-methods');
                  },
                  icon: const Icon(Icons.credit_card, size: 18),
                  label: const Text('Set up Auto-pay for All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HousepitalColors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Patient Switcher
  // ---------------------------------------------------------------------------
  void _showPatientSwitcher(BuildContext context, AppProvider app) {
    if (app.patients.length <= 1) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Switch Patient',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          ...app.patients.map((patient) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: HousepitalColors.orangeLight,
                  child: Text(
                    patient.name[0].toUpperCase(),
                    style:
                        const TextStyle(color: HousepitalColors.orange),
                  ),
                ),
                title: Text(patient.name),
                trailing: patient.id == app.currentPatient?.id
                    ? const Icon(Icons.check,
                        color: HousepitalColors.orange)
                    : null,
                onTap: () {
                  app.switchPatient(patient);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// =============================================================================
// Banner Slide data
// =============================================================================
class _BannerSlide {
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final IconData icon;
  final String? ctaText;
  final VoidCallback? onCtaTap;

  _BannerSlide({
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.icon,
    this.ctaText,
    this.onCtaTap,
  });
}

// =============================================================================
// Quick Action data
// =============================================================================
class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// =============================================================================
// Team Member Row
// =============================================================================
class _TeamMemberRow extends StatelessWidget {
  final String role;
  final String name;
  final IconData icon;
  final Color color;
  final String? phone;

  const _TeamMemberRow({
    required this.role,
    required this.name,
    required this.icon,
    required this.color,
    this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.black,
                ),
              ),
              Text(
                role,
                style: const TextStyle(
                  fontSize: 12,
                  color: HousepitalColors.greyLight,
                ),
              ),
            ],
          ),
        ),
        if (phone != null && phone!.isNotEmpty) ...[
          Semantics(
            label: 'Call $role',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.phone, size: 20),
              color: HousepitalColors.success,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () => launchUrl(Uri.parse('tel:$phone')),
            ),
          ),
          Semantics(
            label: 'WhatsApp $role',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.chat, size: 20),
              color: const Color(0xFF25D366),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () => launchUrl(
                Uri.parse('https://wa.me/91$phone'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Active Service Card
// =============================================================================
class _ActiveServiceCard extends StatelessWidget {
  final String serviceName;
  final String staffName;
  final int? daysRemaining;
  final bool isCheckedIn;
  final VoidCallback onTap;

  const _ActiveServiceCard({
    required this.serviceName,
    required this.staffName,
    this.daysRemaining,
    required this.isCheckedIn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: HousepitalColors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        serviceName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HousepitalColors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isCheckedIn
                            ? HousepitalColors.success
                            : HousepitalColors.greyLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  staffName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: HousepitalColors.greyLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (daysRemaining != null)
                  Text(
                    '$daysRemaining days remaining',
                    style: const TextStyle(
                      fontSize: 12,
                      color: HousepitalColors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Vital Pill
// =============================================================================
class _VitalPill extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final VoidCallback? onTap;

  const _VitalPill({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value $unit',
      button: onTap != null,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Material(
          color: HousepitalColors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 0,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HousepitalColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: HousepitalColors.greyLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: HousepitalColors.black,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            unit,
                            style: const TextStyle(
                              fontSize: 12,
                              color: HousepitalColors.greyLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 16, color: HousepitalColors.greyLight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Progress Ring Painter
// =============================================================================
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
