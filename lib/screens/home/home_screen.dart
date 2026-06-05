import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/constants.dart';
import '../../config/daimaa_theme.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/medication_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../utils/permissions.dart';
import '../../utils/vital_classifier.dart';
import '../../widgets/common_widgets.dart';
import '../main_shell.dart';
import '../services/service_catalog_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _dutyTimer;

  // Banner carousel
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _currentBannerPage = 0;
  // audit M-18: hoisted from `% 3` literal so adding/removing slides in
  // `_buildHeroBanner` automatically updates auto-scroll wrap-around.
  // Defaults to 1 (safe modulo) and is overwritten on the first build.
  int _slideCount = 1;

  // audit batch 4 (Agent L): tracks AnimatedScale press state for cards that
  // implement Apple's 0.98 press feedback (P5 — feedback latency under 100ms).
  final Map<String, double> _pressedScale = {};

  // audit batch 4 (Agent L): guard so we only attempt to start the banner
  // auto-scroll once. We defer the start to didChangeDependencies because that
  // is the first lifecycle hook where MediaQuery is available — required for
  // the reduced-motion (P8) check.
  bool _bannerAutoScrollStarted = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final app = context.read<AppProvider>();
      app.loadPatients().then((_) {
        app.loadDashboard();
        final patientId = app.currentPatient?.id;
        if (patientId != null && mounted) {
          context.read<MedicationProvider>().loadMedications(patientId);
        }
      });
    });
    _startDutyTimer();
    // audit batch 4 (Agent L): banner auto-scroll start moved to
    // didChangeDependencies so MediaQuery.disableAnimations is available.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bannerAutoScrollStarted) {
      _bannerAutoScrollStarted = true;
      // audit batch 4 (Agent L): WCAG 2.3.3 / Apple P8 — honor the user's
      // "Reduce Motion" / "Reduce Animations" OS setting. When disabled,
      // skip the timer entirely so the carousel stays on the slide the user
      // last saw and the dot indicator stops shifting on its own.
      if (!MediaQuery.of(context).disableAnimations) {
        _startBannerAutoScroll();
      }
    }
  }

  void _startDutyTimer() {
    _dutyTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      // Tick to refresh widgets that depend on elapsed duty time.
      if (mounted) setState(() {});
    });
  }

  void _startBannerAutoScroll() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      // audit M-18: derive wrap-around from actual slide count (set by
      // `_buildHeroBanner` on each build) instead of the hardcoded `% 3`.
      final nextPage = (_currentBannerPage + 1) % _slideCount;
      _bannerController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  // audit batch 4 (Agent L): Apple cards spec — 0.98 scale on tap, 100ms.
  // Identified by a string key so multiple tappable cards can share the map.
  void _onCardPressDown(String id) {
    setState(() => _pressedScale[id] = 0.98);
  }

  void _onCardPressUpOrCancel(String id) {
    setState(() => _pressedScale[id] = 1.0);
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
    final role = app.currentUserRole;
    final isPatientSelf = role == UserRole.patientSelf;
    final canBook = canUserPerform(role, UserAction.book) ||
        canUserPerform(role, UserAction.requestBooking);

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
                _buildGreeting(context, app),
                if (app.isDashboardLoading)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: LoadingWidget(),
                  )
                else ...[
                  // Patient-self always sees the big call card up top — that's
                  // the one action available to them.
                  if (isPatientSelf) _buildCallCaregiverCard(context, app),

                  // 1. Your Health Team
                  _sectionLabel('Your Health Team', onSeeAll: () => MainShell.switchToTab(1)),
                  _buildHealthTeamCard(context, l, app),
                  const SizedBox(height: 8),

                  // 2. Current Services
                  if (app.activeDeployment != null) ...[
                    _sectionLabel('Current Services', onSeeAll: () => MainShell.switchToTab(1)),
                    _buildActiveServicesQuickView(context, l, app),
                    const SizedBox(height: 8),
                  ],

                  // 3. Today's Vitals
                  if (app.latestVitals != null) ...[
                    _sectionLabel("Today's Vitals", onSeeAll: () => Navigator.pushNamed(context, '/vitals')),
                    _buildVitalsStrip(app),
                    const SizedBox(height: 8),
                  ],

                  // 3a. Medications snippet (only renders if active meds exist)
                  _buildMedicationsSnippet(context),
                  const SizedBox(height: 8),

                  // 4. Book Services — hidden from view-only roles.
                  if (canBook) ...[
                    _sectionLabel('Book Services', onSeeAll: () => MainShell.switchToTab(2)),
                    _buildQuickActionsGrid(context, l),
                    const SizedBox(height: 8),

                    // 4b. Dai Maa sub-brand entry
                    _buildDaiMaaEntry(context),
                    const SizedBox(height: 8),
                  ],

                  // 5. Today's Report
                  if (app.todayReport != null) ...[
                    _sectionLabel("Today's Report", onSeeAll: () => Navigator.pushNamed(context, '/report-detail', arguments: app.todayReport)),
                    _buildReportSnippet(app),
                    const SizedBox(height: 8),
                  ],

                  // 6. Payments — only show to roles that can actually pay.
                  if (canUserPerform(role, UserAction.pay))
                    _buildPaymentCards(context, app),

                  const SizedBox(height: 12),

                  // Hero banner — DEMOTED to the bottom as a promo surface.
                  _buildHeroBanner(context),

                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PATIENT_SELF — big "Call my caregiver" card.
  // ---------------------------------------------------------------------------
  Widget _buildCallCaregiverCard(BuildContext context, AppProvider app) {
    final patient = app.currentPatient;
    final contact = (patient?.emergencyContacts?.isNotEmpty ?? false)
        ? patient!.emergencyContacts!.first
        : null;
    final caregiverName = contact?.name ?? 'your family caregiver';
    final caregiverPhone = contact?.phone;

    // audit batch 4 (Agent L): Apple cards spec P5 — primary tappable cards
    // confirm touch with a 0.98 scale, 100ms duration. Tracks press state via
    // _pressedScale map keyed by 'call_caregiver'.
    const cardId = 'call_caregiver';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: AnimatedScale(
        scale: _pressedScale[cardId] ?? 1.0,
        duration: const Duration(milliseconds: 100),
        child: Material(
          color: HousepitalColors.orange,
          borderRadius: BorderRadius.circular(16),
          elevation: 1,
          shadowColor: Colors.black12,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: caregiverPhone != null
                ? () => launchUrl(Uri.parse('tel:$caregiverPhone'))
                : null,
            onTapDown: caregiverPhone != null
                ? (_) => _onCardPressDown(cardId)
                : null,
            onTapUp: caregiverPhone != null
                ? (_) => _onCardPressUpOrCancel(cardId)
                : null,
            onTapCancel: caregiverPhone != null
                ? () => _onCardPressUpOrCancel(cardId)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_in_talk,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Call my family caregiver',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          caregiverPhone != null
                              ? 'Tap to call $caregiverName · $caregiverPhone'
                              : 'No family contact saved yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Role badge — pill shown below the greeting that clarifies what this user
  // can do. Hover/long-press shows the tooltip for limited roles.
  // ---------------------------------------------------------------------------
  Widget _buildRoleBadge(String role) {
    String label;
    String? tooltip;
    Color color;
    switch (role) {
      case UserRole.primaryContact:
        label = 'Primary Contact';
        color = HousepitalColors.orange;
        break;
      case UserRole.familyMember:
        label = 'Family Member';
        color = HousepitalColors.info;
        tooltip =
            'You can view & rate. To book or pay, contact your primary contact.';
        break;
      case UserRole.patientSelf:
        label = 'Patient';
        color = HousepitalColors.greyLight;
        tooltip =
            "You're viewing your own care. Tap the big call button to reach your family.";
        break;
      // audit M-5: caretaker badge — view-only with concern raising.
      case UserRole.caretaker:
        label = 'Caretaker view';
        color = HousepitalColors.grey;
        tooltip =
            'Read-only view for hired caretaker. You can raise concerns; booking and payment are restricted to the family.';
        break;
      default:
        return const SizedBox.shrink();
    }

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          if (tooltip != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 12, color: color),
          ],
        ],
      ),
    );

    return tooltip != null ? Tooltip(message: tooltip, child: pill) : pill;
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
                    // audit batch 4 (Agent L): WCAG 2.5.5 / Apple P4 — chip is
                    // visually 14pt text + 20pt icon (~28pt total), short of
                    // the 44pt minimum. ConstrainedBox lifts the hit region to
                    // 44pt without growing the visible chip; align centers it.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
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
            builder: (_, cart, _) => Semantics(
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
        title: 'Hospital-like expertise.\nHome-like care.',
        subtitle: 'Trusted by 5,000+ families in Delhi NCR',
        gradientColors: [const Color(0xFFFF8C00), const Color(0xFFFF6B35)],
        icon: Icons.home_filled,
        imagePath: 'assets/images/branding/hero_care.jpg',
      ),
      _BannerSlide(
        title: '24/7 ICU Setup\nat Home',
        subtitle: 'Critical care nursing & medical equipment',
        gradientColors: [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
        icon: Icons.monitor_heart,
        imagePath: 'assets/images/branding/hero_nurse.jpg',
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
        imagePath: 'assets/images/branding/hero_family.jpg',
      ),
    ];
    // audit M-18: stash the count so the auto-scroll timer wraps on the real
    // slide count rather than a hardcoded `3`.
    _slideCount = slides.length;

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
                child: Semantics(
                  container: true,
                  image: slide.imagePath != null,
                  label:
                      'Promotional banner ${index + 1} of ${slides.length}. ${slide.title.replaceAll('\n', ' ')}. ${slide.subtitle}',
                  child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: slide.imagePath != null
                        ? DecorationImage(
                            image: AssetImage(slide.imagePath!),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.45),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                    gradient: slide.imagePath == null
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: slide.gradientColors,
                          )
                        : null,
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
    final firstName = (app.currentPatient?.name ?? 'there').split(' ').first;
    // Layout B: collapse the greeting to a single line — name + role badge on
    // one Row. The standalone "Here's your care summary" subtitle is dropped
    // to reclaim vertical space at the top of the scroll.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Flexible(
            child: Text(
              'Hi $firstName!',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: HousepitalColors.orangeText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildRoleBadge(app.currentUserRole),
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
    final daysRemaining = deployment.endDate?.difference(DateTime.now()).inDays;

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
  // Quick Actions Grid (2x3)
  // ---------------------------------------------------------------------------
  Widget _buildQuickActionsGrid(BuildContext context, AppLocalizations l) {
    // Dynamic tiles: if the patient is already availing a service (detected
    // from activeDeployment.staffRole), flip "Book X" → "My X" so they're
    // not prompted to re-book a service they're already receiving.
    final activeRole =
        context.read<AppProvider>().activeDeployment?.staffRole?.toLowerCase() ??
            '';

    final browseActions = <_QuickAction>[
      if (!activeRole.contains('nurse') && !activeRole.contains('icu'))
        _QuickAction(
          icon: Icons.medical_services,
          label: 'Book Nurse',
          color: HousepitalColors.serviceNursing,
          onTap: () {
            MainShell.switchToTab(2);
            ServiceCatalogScreen.switchToSubTab(0);
          },
        )
      else
        _QuickAction(
          icon: Icons.medical_services,
          label: 'My Nurse',
          color: HousepitalColors.serviceNursing,
          onTap: () => MainShell.switchToTab(1),
        ),
      if (!activeRole.contains('caretaker') && !activeRole.contains('attendant'))
        _QuickAction(
          icon: Icons.person_pin,
          label: 'Book Caretaker',
          color: HousepitalColors.serviceCaretaker,
          onTap: () {
            MainShell.switchToTab(2);
            ServiceCatalogScreen.switchToSubTab(0);
          },
        )
      else
        _QuickAction(
          icon: Icons.person_pin,
          label: 'My Caretaker',
          color: HousepitalColors.serviceCaretaker,
          onTap: () => MainShell.switchToTab(1),
        ),
      if (!activeRole.contains('physio'))
        _QuickAction(
          icon: Icons.self_improvement,
          label: 'Physiotherapy',
          color: HousepitalColors.servicePhysio,
          onTap: () {
            MainShell.switchToTab(2);
            ServiceCatalogScreen.switchToSubTab(0);
          },
        )
      else
        _QuickAction(
          icon: Icons.self_improvement,
          label: 'My Physio',
          color: HousepitalColors.servicePhysio,
          onTap: () => MainShell.switchToTab(1),
        ),
      _QuickAction(
        icon: Icons.local_shipping,
        label: 'Equipment',
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
    ];

    final utilityActions = <_QuickAction>[
      _QuickAction(
        icon: Icons.receipt_long,
        label: 'My Orders',
        color: HousepitalColors.serviceJapaNanny,
        onTap: () => Navigator.pushNamed(context, '/my-orders'),
      ),
      _QuickAction(
        icon: Icons.menu_book,
        label: 'Care Guides',
        color: HousepitalColors.serviceCarePackage,
        onTap: () => Navigator.pushNamed(context, '/articles'),
      ),
      _QuickAction(
        icon: Icons.emergency,
        label: 'SOS',
        color: HousepitalColors.error,
        onTap: () => Navigator.pushNamed(context, '/sos'),
      ),
    ];

    final allActions = [...browseActions, ...utilityActions];
    // 4 tiles per row gives comfortable thumb-reach on standard phone widths.
    final tileWidth = (MediaQuery.of(context).size.width - 48) / 4;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: HousepitalColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HousepitalColors.divider),
      ),
      child: Wrap(
        spacing: 0,
        runSpacing: 8,
        children: allActions.map((action) {
          final tileId = 'quick_${action.label}';
          return SizedBox(
            width: tileWidth,
            child: Semantics(
              button: true,
              label: action.label,
              child: AnimatedScale(
                scale: _pressedScale[tileId] ?? 1.0,
                duration: const Duration(milliseconds: 100),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: action.onTap,
                    onTapDown: (_) => _onCardPressDown(tileId),
                    onTapUp: (_) => _onCardPressUpOrCancel(tileId),
                    onTapCancel: () => _onCardPressUpOrCancel(tileId),
                    child: Container(
                      // WCAG 2.5.5 — ≥44pt tap target.
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: action.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(action.icon,
                                color: action.color, size: 22),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            action.label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: HousepitalColors.grey,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dai Maa sub-brand entry card
  // ---------------------------------------------------------------------------
  Widget _buildDaiMaaEntry(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/daimaa'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            // audit batch 4 (Agent L): Apple 8pt grid (P1) — snap from off-grid
            // 18 to 16. Visual change is negligible (2pt) but aligns with the
            // rest of the home cards.
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [DaiMaaColors.plum, DaiMaaColors.lavender],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: DaiMaaColors.plum.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mother & Baby Care',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        DaiMaaColors.tagline,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Explore Dai Maa',
                              style: TextStyle(
                                color: DaiMaaColors.plum,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward,
                                color: DaiMaaColors.plum, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.child_friendly,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
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
            // audit batch 4 (Agent L): WCAG 2.5.5 / Apple P4 — guarantee a
            // 44pt minimum tap target. Previous GestureDetector wrapped only
            // 12pt text + 4pt vertical padding (~20pt total). TextButton gives
            // us Material's 48dp default plus a hit region that comfortably
            // clears 44pt without growing the visible "See All" label.
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                foregroundColor: HousepitalColors.orange,
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
              ),
              child: const Text('See All',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500, color: HousepitalColors.orange)),
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
    Color statusColor = HousepitalColors.greyLight;
    IconData statusIcon = Icons.remove_circle_outline;
    String statusLabel = 'No reading';
    if (raw != null) {
      final s = classifyVital(type, raw);
      if (s == 'green') {
        statusColor = HousepitalColors.success;
        statusIcon = Icons.check_circle;
        statusLabel = 'Normal';
      } else if (s == 'yellow') {
        statusColor = HousepitalColors.warning;
        statusIcon = Icons.info_outline;
        statusLabel = 'Borderline';
      } else {
        statusColor = HousepitalColors.error;
        statusIcon = Icons.warning_amber;
        statusLabel = 'Alert';
      }
    }
    return Expanded(
      child: Semantics(
        button: true,
        label: '$label $value, $statusLabel',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, '/vitals'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              // WCAG 2.5.5 — bump vertical padding so the chip clears 44pt.
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              decoration: BoxDecoration(
                color: HousepitalColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HousepitalColors.divider),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    // WCAG 1.4.1 — convey zone with icon + color, not color
                    // alone. The icon is decorative (status is in the
                    // Semantics label above).
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11,
                            color: HousepitalColors.greyLight)),
                  ]),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
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
  // Payment Cards (Overdue + Upcoming with early pay discount)
  // ---------------------------------------------------------------------------
  Widget _buildPaymentCards(BuildContext context, AppProvider app) {
    final amountDue = app.amountDue;
    final dueDate = app.dueDate;
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now());
    final earlyPayDiscount = (amountDue * 0.01).round(); // 1% off
    final earlyPayAmount = amountDue - earlyPayDiscount;

    if (amountDue <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Payments',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),

          // Overdue card (red)
          if (isOverdue)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HousepitalColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HousepitalColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: HousepitalColors.error, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Overdue Payment',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HousepitalColors.error)),
                        // audit batch 4 (Agent L): drop the duplicate ₹ —
                        // DateHelper.formatCurrency already prepends the
                        // symbol, so the previous string rendered as "₹₹3,000".
                        Text('${DateHelper.formatCurrency(amountDue)} was due on ${DateHelper.formatDate(dueDate)}',
                            style: const TextStyle(fontSize: 12, color: HousepitalColors.grey)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => MainShell.switchToTab(3),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HousepitalColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Pay Now', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Upcoming payment card (orange) with early pay discount
          if (!isOverdue)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HousepitalColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HousepitalColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: HousepitalColors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Upcoming Payment',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            if (dueDate != null)
                              Text('Due on ${DateHelper.formatDate(dueDate)}',
                                  style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight)),
                          ],
                        ),
                      ),
                      Text(DateHelper.formatCurrency(amountDue),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: HousepitalColors.orange)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Early pay incentive
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HousepitalColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.savings, color: HousepitalColors.success, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pay early & save ${DateHelper.formatCurrency(earlyPayDiscount)}!',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HousepitalColors.success)),
                              Text('Pay ${DateHelper.formatCurrency(earlyPayAmount)} instead of ${DateHelper.formatCurrency(amountDue)} (1% off)',
                                  style: const TextStyle(fontSize: 11, color: HousepitalColors.grey)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => MainShell.switchToTab(3),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HousepitalColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Pay Early', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  Widget _buildMedicationsSnippet(BuildContext context) {
    final medProv = context.watch<MedicationProvider>();
    final active = medProv.activeMedications;
    if (active.isEmpty) return const SizedBox.shrink();

    // Find next upcoming scheduled medication today
    final now = DateTime.now();
    DateTime? nextTime;
    String? nextName;
    for (final med in active) {
      for (final timeStr in med.timeSlots) {
        final parts = timeStr.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        final candidate =
            DateTime(now.year, now.month, now.day, hour, minute);
        if (candidate.isAfter(now) &&
            (nextTime == null || candidate.isBefore(nextTime))) {
          nextTime = candidate;
          nextName = med.name;
        }
      }
    }

    final subtitle = (nextTime != null && nextName != null)
        ? 'Next: $nextName at ${_formatTime(nextTime)}'
        : 'No more doses scheduled today';

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
          child: Row(
            children: [
              const Icon(Icons.medication,
                  color: HousepitalColors.orange, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${active.length} active medication${active.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: HousepitalColors.greyLight),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: HousepitalColors.greyLight, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final hour12 = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
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
  final String? imagePath;

  _BannerSlide({
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.icon,
    this.ctaText,
    this.onCtaTap,
    this.imagePath,
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

