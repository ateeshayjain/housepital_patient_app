import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../config/daimaa_theme.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../../providers/cart_provider.dart';
import '../../models/my_care_models.dart';
import '../../providers/medication_provider.dart';
import '../../providers/my_care_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../utils/permissions.dart';
import '../../widgets/care_pulse_ring.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass.dart';
import '../main_shell.dart';
import '../services/service_catalog_screen.dart';

// WhatsApp brand green — a third-party brand color with no Housepital token.
// Allowlisted in scripts/check_design_consistency.sh; named here so the one
// sanctioned literal isn't re-typed ad hoc.
const Color _whatsAppGreen = Color(0xFF25D366);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _dutyTimer;

  // Banner carousel — manual swipe + dots ONLY. The timer-driven auto-advance
  // was removed (audit round 2): self-moving UI fights the calm-clinical tone,
  // and the banner is already demoted to a promo surface at the page bottom.
  final PageController _bannerController = PageController();
  int _currentBannerPage = 0;

  // audit batch 4 (Agent L): tracks AnimatedScale press state for NON-card
  // tappables (hero call card, quick-action tiles) that implement Apple's
  // 0.98 press feedback. Section cards use HousepitalCard, which carries its
  // own 0.97/120ms press scale.
  final Map<String, double> _pressedScale = {};

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
  }

  void _startDutyTimer() {
    _dutyTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      // Tick to refresh widgets that depend on elapsed duty time.
      if (mounted) setState(() {});
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
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final app = context.watch<AppProvider>();
    final role = app.currentUserRole;
    final isPatientSelf = role == UserRole.patientSelf;
    final canBook =
        canUserPerform(role, UserAction.book) ||
        canUserPerform(role, UserAction.requestBooking);

    return Scaffold(
      // bottom:false + nav-height scroll padding: content glides under the
      // glass nav bar (Liquid Glass) instead of stopping at an opaque edge.
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: HousepitalColors.orange,
          onRefresh: () => app.loadDashboard(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
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
                  // Inter-SECTION rhythm (audit round 2): the old 4px SizedBox
                  // shims were too tight. Every section card is now a
                  // HousepitalCard whose themed Card margin contributes 8px
                  // above and below, so the explicit shims are GONE rather
                  // than doubled — each section boundary gets a consistent
                  // ≥8px gap without inflating the compact top stack.

                  // Patient-self always sees the big call card up top — that's
                  // the one action available to them.
                  if (isPatientSelf) _buildCallCaregiverCard(context, app),

                  // 1. Your Health Team
                  _sectionLabel(
                    'Your Health Team',
                    onSeeAll: () => Navigator.pushNamed(context, '/care-team'),
                  ),
                  _buildHealthTeamCard(context, l, app),

                  // 2. Current Services
                  if (app.activeDeployment != null) ...[
                    _sectionLabel(
                      'Current Services',
                      onSeeAll: () => MainShell.switchToTab(1),
                    ),
                    _buildActiveServicesQuickView(context, l, app),
                  ],

                  // Vitals intentionally NOT shown on Home — they live on the
                  // My Care tab (single source of truth). Home stays a lean
                  // glance: team, services, meds, actions.

                  // 3a. Medications snippet (only renders if active meds exist)
                  _buildMedicationsSnippet(context),

                  // 4. Book Services — hidden from view-only roles.
                  if (canBook) ...[
                    _sectionLabel(
                      'Book Services',
                      onSeeAll: () => MainShell.switchToTab(2),
                    ),
                    _buildQuickActionsGrid(context, l),

                    // 4b. Dai Maa sub-brand entry
                    _buildDaiMaaEntry(context),
                  ],

                  // 4c. Care Guides entry — available to ALL roles (reading
                  // health education isn't a "booking" action).
                  _buildCareGuidesEntry(context),

                  // 4d. Care Calendar entry — schedule/adherence/visits at a
                  // glance, available to all roles (read-only surface).
                  _buildCareCalendarEntry(context),

                  // 5. Today's Report
                  if (app.todayReport != null) ...[
                    _sectionLabel(
                      "Today's Report",
                      onSeeAll: () => Navigator.pushNamed(
                        context,
                        '/report-detail',
                        arguments: app.todayReport,
                      ),
                    ),
                    _buildReportSnippet(context, app),
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
                    // Dark ink on orange — white on orange fails AA (~2.3:1).
                    child: const Icon(
                      Icons.phone_in_talk,
                      color: HousepitalColors.onOrange,
                      size: 32,
                    ),
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
                            color: HousepitalColors.onOrange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          caregiverPhone != null
                              ? 'Tap to call $caregiverName · $caregiverPhone'
                              : 'No family contact saved yet',
                          style: const TextStyle(
                            fontSize: 13,
                            color: HousepitalColors.onOrange,
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
  Widget _buildRoleBadge(BuildContext context, String role) {
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
        color = context.hc.info;
        tooltip =
            'You can view & rate. To book or pay, contact your primary contact.';
        break;
      case UserRole.patientSelf:
        label = 'Patient';
        color = context.hc.greyLight;
        tooltip =
            "You're viewing your own care. Tap the big call button to reach your family.";
        break;
      // audit M-5: caretaker badge — view-only with concern raising.
      case UserRole.caretaker:
        label = 'Caretaker view';
        color = context.hc.grey;
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
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
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
  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l,
    AppProvider app,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Official brand logo (orange/grey on light, orange/white on
                // dark — per brand guidelines the figurative mark stays orange).
                Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/images/housepital_logo_dark.png'
                      : 'assets/images/housepital_logo.png',
                  height: 26,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  semanticLabel: 'Housepital',
                ),
                const SizedBox(height: 2),
                if (app.currentPatient != null && app.patients.length > 1)
                  Semantics(
                    label:
                        'Switch patient. Current: ${app.currentPatient!.name}',
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
                                l.t('dashboard_care', {
                                  'name': app.currentPatient!.name,
                                }),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.hc.grey,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down,
                                color: context.hc.grey,
                                size: 20,
                              ),
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
              label:
                  'Cart${cart.itemCount > 0 ? ", ${cart.itemCount} items" : ""}',
              button: true,
              child: IconButton(
                icon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text(
                    '${cart.itemCount}',
                    style: const TextStyle(fontSize: 11),
                  ),
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
          // SOS — emergency action lives in the persistent header so it's
          // always one tap away (never buried in a scrollable grid). Rendered
          // as a distinct red pill (not a fourth identical icon) so the
          // emergency affordance reads instantly; red is reserved for SOS.
          Semantics(
            label: 'SOS — emergency help',
            button: true,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () {
                HapticFeedback.heavyImpact();
                Navigator.pushNamed(context, '/sos');
              },
              // 44pt minimum hit target around the compact visual pill.
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: ShapeDecoration(
                      color: context.hc.error,
                      shape: const StadiumBorder(),
                    ),
                    // Icon + label are decorative for assistive tech — the
                    // explicit Semantics label above announces the action.
                    child: const ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emergency, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
        gradientColors: const [
          HeroGradient.orangeStart,
          HeroGradient.orangeEnd,
        ],
        icon: Icons.home_filled,
        imagePath: 'assets/images/branding/hero_care.jpg',
      ),
      _BannerSlide(
        title: '24/7 ICU Setup\nat Home',
        subtitle: 'Critical care nursing & medical equipment',
        gradientColors: [context.hc.info, HeroGradient.blueEnd],
        icon: Icons.monitor_heart,
        imagePath: 'assets/images/branding/hero_nurse.jpg',
      ),
      _BannerSlide(
        title: 'Free Health\nAssessment',
        subtitle: 'Book now — no obligations',
        gradientColors: [context.hc.success, HeroGradient.greenEnd],
        icon: Icons.health_and_safety,
        ctaText: 'Book Now',
        onCtaTap: () {
          MainShell.switchToTab(2);
          ServiceCatalogScreen.switchToSubTab(0);
        },
        imagePath: 'assets/images/branding/hero_family.jpg',
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
                          color: slide.gradientColors.first.withValues(
                            alpha: 0.3,
                          ),
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
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
                    : context.hc.divider,
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
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Row(
        children: [
          Flexible(
            child: Text(
              'Hi $firstName!',
              overflow: TextOverflow.ellipsis,
              // C3 calm pass: the greeting IS Home's display title — same
              // confident 28/w800 large-title voice as the other root tabs.
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                // Greeting reads as primary text — the accent color is
                // reserved for actionable elements.
                color: context.hc.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildRoleBadge(context, app.currentUserRole),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Health Team Card
  // ---------------------------------------------------------------------------
  Widget _buildHealthTeamCard(
    BuildContext context,
    AppLocalizations l,
    AppProvider app,
  ) {
    final deployment = app.activeDeployment;
    final patient = app.currentPatient;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HousepitalCard(
        // Header removed — the "Your Health Team" section label above the
        // card already names it (other sections follow the same pattern).
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (deployment != null) ...[
              // FIRST option: the team GROUP CHAT — one tap reaches every
              // member (manager, nurse, doctor) so queries resolve in one
              // place. Whole row taps into the group thread.
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/chat',
                  arguments: {
                    'patientId': app.currentPatient?.id ?? 'pat_demo_rajesh',
                    'coordinatorName': 'Care Team',
                  },
                ),
                child: Row(
                  children: [
                    const AppIconTile(
                      icon: Icons.groups,
                      color: HousepitalColors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Care Team Group Chat',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.hc.black,
                            ),
                          ),
                          Text(
                            'All queries in one place',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.hc.greyLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Care Team pattern (care_team_screen._MemberRow):
                    // filled-orange square call + outlined square chat.
                    Semantics(
                      label: 'Call Housepital care team',
                      button: true,
                      child: IconButton(
                        onPressed: () => launchUrl(
                          Uri.parse('tel:${AppConstants.supportPhone}'),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: HousepitalColors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.phone,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Semantics(
                      label: 'Open care team group chat',
                      button: true,
                      child: IconButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/chat',
                          arguments: {
                            'patientId':
                                app.currentPatient?.id ?? 'pat_demo_rajesh',
                            'coordinatorName': 'Care Team',
                          },
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: context.hc.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: context.hc.divider),
                          ),
                        ),
                        icon: Icon(
                          Icons.chat_bubble_outline,
                          size: 20,
                          color: context.hc.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Calm pass: per-role tile colors retired — every team tile
              // shares the one orange accent.
              _TeamMemberRow(
                role: deployment.staffRole ?? 'Staff',
                name: deployment.staffName ?? 'Assigned',
                icon: Icons.medical_services,
                phone: AppConstants.supportPhone,
              ),
              if (patient?.doctorName != null &&
                  patient!.doctorName!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _TeamMemberRow(
                  role: 'Doctor',
                  name: patient.doctorName!,
                  icon: Icons.medical_information,
                  phone: patient.doctorPhone,
                ),
              ],
            ] else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.hc.greyLight,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your care team will appear here once services are active',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.hc.greyLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Active Services Quick View
  // ---------------------------------------------------------------------------
  Widget _buildActiveServicesQuickView(
    BuildContext context,
    AppLocalizations l,
    AppProvider app,
  ) {
    final deployment = app.activeDeployment;
    if (deployment == null) return const SizedBox.shrink();

    final attendance = app.todayAttendance;
    final status = attendance?.status ?? 'waiting';
    final statusColor = AttendanceHelper.getStatusColor(status);
    final daysRemaining = deployment.endDate?.difference(DateTime.now()).inDays;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HousepitalCard(
        // Tapping the current service opens THAT service's detail page
        // (was: a jarring jump to the My Care tab). Falls back to the tab
        // only if the service list hasn't loaded yet.
        onTap: () {
          final services = context.read<MyCareProvider>().activeServices;
          ActiveService? match;
          for (final s in services) {
            if (s.deploymentIds.contains(deployment.id)) {
              match = s;
              break;
            }
          }
          match ??= services.isNotEmpty ? services.first : null;
          if (match != null) {
            Navigator.pushNamed(context, '/service-detail', arguments: match);
          } else {
            MainShell.switchToTab(1);
          }
        },
        child: Row(
          children: [
            // Calm pass: tile is the standard orange accent — "is the staff
            // on duty?" is carried by the semantic status dot on the right,
            // not by tinting the identity icon green.
            const AppIconTile(
              icon: Icons.medical_services,
              color: HousepitalColors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lead with the SERVICE (what the tap opens), not the
                  // staff role — 'Critical Care Nurse' here while the
                  // detail said 'ICU Setup at Home' read as a mismatch.
                  Builder(
                    builder: (context) {
                      final services = context
                          .watch<MyCareProvider>()
                          .activeServices;
                      String title = deployment.staffRole ?? 'Care Service';
                      for (final s in services) {
                        if (s.deploymentIds.contains(deployment.id)) {
                          title = s.name;
                          break;
                        }
                      }
                      return Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                  Text(
                    '${deployment.staffName ?? 'Assigned'} · ${deployment.staffRole ?? 'Staff'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.hc.greyLight),
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
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (daysRemaining != null) ...[
              const SizedBox(width: 8),
              Text(
                '${daysRemaining}d left',
                style: TextStyle(fontSize: 11, color: context.hc.greyLight),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: context.hc.greyLight, size: 18),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Care Guides entry — slim full-width row (kept out of Book Services)
  // ---------------------------------------------------------------------------
  Widget _buildCareGuidesEntry(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        button: true,
        label: 'Care Guides — health tips and education',
        child: HousepitalCard(
          padding: const EdgeInsets.all(12),
          onTap: () => Navigator.pushNamed(context, '/articles'),
          child: Row(
            children: [
              const AppIconTile(
                icon: Icons.menu_book,
                color: HousepitalColors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Care Guides',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Health tips & education for your family',
                      style: TextStyle(fontSize: 12, color: context.hc.grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.hc.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Care Calendar entry — slim full-width row (mirrors Care Guides entry)
  // ---------------------------------------------------------------------------
  Widget _buildCareCalendarEntry(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        button: true,
        label: 'Care Calendar — schedule, adherence and visits',
        child: HousepitalCard(
          padding: const EdgeInsets.all(12),
          onTap: () => Navigator.pushNamed(context, '/care-calendar'),
          child: Row(
            children: [
              const AppIconTile(
                icon: Icons.calendar_month,
                color: HousepitalColors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Care Calendar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Schedule, adherence & visits',
                      style: TextStyle(fontSize: 12, color: context.hc.grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.hc.grey),
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
        context
            .read<AppProvider>()
            .activeDeployment
            ?.staffRole
            ?.toLowerCase() ??
        '';

    final browseActions = <_QuickAction>[
      if (!activeRole.contains('nurse') && !activeRole.contains('icu'))
        _QuickAction(
          icon: Icons.medical_services,
          label: 'Book Nurse',
          onTap: () {
            MainShell.switchToTab(2);
            ServiceCatalogScreen.switchToSubTab(0);
          },
        )
      else
        _QuickAction(
          icon: Icons.medical_services,
          label: 'My Nurse',
          onTap: () => MainShell.switchToTab(1),
        ),
      if (!activeRole.contains('caretaker') &&
          !activeRole.contains('attendant'))
        _QuickAction(
          icon: Icons.person_pin,
          label: 'Book Caretaker',
          onTap: () {
            MainShell.switchToTab(2);
            ServiceCatalogScreen.switchToSubTab(0);
          },
        )
      else
        _QuickAction(
          icon: Icons.person_pin,
          label: 'My Caretaker',
          onTap: () => MainShell.switchToTab(1),
        ),
      if (!activeRole.contains('physio'))
        _QuickAction(
          icon: Icons.self_improvement,
          label: 'Physiotherapy',
          onTap: () {
            MainShell.switchToTab(2);
            ServiceCatalogScreen.switchToSubTab(0);
          },
        )
      else
        _QuickAction(
          icon: Icons.self_improvement,
          label: 'My Physio',
          onTap: () => MainShell.switchToTab(1),
        ),
      _QuickAction(
        icon: Icons.local_shipping,
        label: 'Equipment',
        onTap: () {
          MainShell.switchToTab(2);
          ServiceCatalogScreen.switchToSubTab(1);
        },
      ),
      _QuickAction(
        icon: Icons.science,
        label: 'Lab Tests',
        onTap: () {
          MainShell.switchToTab(2);
          ServiceCatalogScreen.switchToSubTab(5);
        },
      ),
      _QuickAction(
        icon: Icons.medical_information,
        label: 'Doctor Visit',
        onTap: () {
          MainShell.switchToTab(2);
          ServiceCatalogScreen.switchToSubTab(2);
        },
      ),
    ];

    // Book Services contains ONLY bookable services. Utility/navigation items
    // live elsewhere: SOS in the header, My Orders in Settings + booking flows,
    // Care Guides in its own entry card below.
    final allActions = browseActions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HousepitalCard(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        // 3 columns filling the row edge-to-edge; 6 service tiles → compact 2×3.
        // mainAxisExtent fixes each cell's HEIGHT in absolute px (instead of a
        // width-derived aspect ratio). A fixed aspect ratio made cells too short
        // on narrow phones (the Column overflowed ~12px on a 320px screen) while
        // leaving gaps on wide ones; a fixed 88px height fits the icon + 2-line
        // label on every width with no overflow and no gap.
        child: GridView.builder(
          // Explicit zero padding: nested scrollables otherwise absorb the
          // ambient bottom inset (the glass nav height under extendBody) as
          // internal padding — which rendered as a blank band inside this card.
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 8,
            mainAxisExtent: 88,
          ),
          itemCount: allActions.length,
          itemBuilder: (context, index) {
            final action = allActions[index];
            final tileId = 'quick_${action.label}';
            return Semantics(
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Calm pass: one accent — every quick-action tile is
                        // orange (the old per-service rainbow was decorative).
                        AppIconTile(
                          icon: action.icon,
                          color: HousepitalColors.orange,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            action.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: context.hc.grey,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Dai Maa cross-promo banner
  //
  // Dai Maa is a SEPARATE app (mother & baby care, a Housepital company). This
  // banner is pure cross-promotion: tapping it opens the standalone Dai Maa app
  // / site externally. The Housepital patient app itself does NOT sell any
  // mother-&-baby care. Styled with DaiMaaColors so the sub-brand is
  // recognisable.
  // ---------------------------------------------------------------------------
  Widget _buildDaiMaaEntry(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => launchUrl(
            Uri.parse(DaiMaaColors.exploreUrl),
            mode: LaunchMode.externalApplication,
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
                        'Dai Maa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Mother & baby care — a Housepital company',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Flexible so an extreme text size / locale
                            // ellipsizes instead of overflowing the banner at
                            // 320px; on real fonts it hugs the text unchanged.
                            const Flexible(
                              child: Text(
                                'Explore the app',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: DaiMaaColors.plum,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.open_in_new,
                              color: DaiMaaColors.plum,
                              size: 14,
                            ),
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
    return SectionHeader(
      title: title,
      actionText: onSeeAll != null ? 'See All' : null,
      onAction: onSeeAll,
    );
  }

  // ---------------------------------------------------------------------------
  // Report Snippet
  // ---------------------------------------------------------------------------
  Widget _buildReportSnippet(BuildContext context, AppProvider app) {
    final r = app.todayReport!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HousepitalCard(
        padding: const EdgeInsets.all(12),
        // Same destination as the section's "See All" — the chevron promised
        // a tap, so the card honours it.
        onTap: () => Navigator.pushNamed(
          context,
          '/report-detail',
          arguments: app.todayReport,
        ),
        child: Row(
          children: [
            CarePulseRing(
              value: r.totalTasks > 0
                  ? r.completedTasks / r.totalTasks
                  : 0,
              size: 40,
              strokeWidth: 3,
              semanticLabel:
                  '${r.completedTasks} of ${r.totalTasks} tasks done',
              center: Text(
                '${r.completedTasks}/${r.totalTasks}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.completedTasks} of ${r.totalTasks} tasks done',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (r.staffNotes != null)
                    Text(
                      r.staffNotes!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.hc.greyLight,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.hc.greyLight, size: 18),
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

    if (amountDue <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shared SectionHeader (16/w600) — matches every other Home section.
        const SectionHeader(title: 'Payments'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overdue card (red) — error-tinted by design, so it stays a
              // styled Container (HousepitalCard is the neutral surface card).
              if (isOverdue)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.hc.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.hc.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: context.hc.error,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Overdue Payment',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: context.hc.error,
                                  ),
                                ),
                                // audit batch 4 (Agent L): drop the duplicate
                                // ₹ — DateHelper.formatCurrency already
                                // prepends the symbol.
                                Text(
                                  '${DateHelper.formatCurrency(amountDue)} was due on ${DateHelper.formatDate(dueDate)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.hc.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => MainShell.switchToTab(3),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.hc.error,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              'Pay Now',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Reassurance — firm ask, calm tone: lateness never
                      // reads as a threat to the patient's care.
                      Text(
                        'Your care continues uninterrupted.',
                        style: TextStyle(fontSize: 12, color: context.hc.grey),
                      ),
                    ],
                  ),
                ),

              // Upcoming payment card — whole card opens the Billing tab.
              if (!isOverdue)
                HousepitalCard(
                  onTap: () => MainShell.switchToTab(3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: HousepitalColors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Upcoming Payment',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (dueDate != null)
                                  Text(
                                    'Due on ${DateHelper.formatDate(dueDate)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.hc.greyLight,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            DateHelper.formatCurrency(amountDue),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.hc.orangeText,
                            ),
                          ),
                        ],
                      ),
                      // Early-pay note — one quiet line, no shouting, no
                      // green savings box.
                      if (dueDate != null && earlyPayDiscount > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Pay by ${DateHelper.formatDate(dueDate)} to save ${DateHelper.formatCurrency(earlyPayDiscount)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.hc.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
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
        final candidate = DateTime(now.year, now.month, now.day, hour, minute);
        if (candidate.isAfter(now) &&
            (nextTime == null || candidate.isBefore(nextTime))) {
          nextTime = candidate;
          nextName = med.name;
        }
      }
    }

    final subtitle = (nextTime != null && nextName != null)
        ? 'Next: $nextName at ${_formatTime(nextTime)}'
        : 'All done for today';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HousepitalCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.pushNamed(context, '/medications'),
        child: Row(
          children: [
            // Standard home icon tile (matches all other Home sections).
            const AppIconTile(
              icon: Icons.medication,
              color: HousepitalColors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${active.length} active medication${active.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: context.hc.greyLight),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.hc.greyLight, size: 18),
          ],
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
      // Liquid Glass sheet: translucent blurred material; 0.85 fill keeps the
      // patient list fully legible while the page glows through faintly.
      backgroundColor: Colors.transparent,
      builder: (context) => GlassSurface(
        opacity: 0.85,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Switch Patient',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            ...app.patients.map(
              (patient) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.hc.orangeLight,
                  child: Text(
                    patient.name[0].toUpperCase(),
                    style: TextStyle(color: context.hc.orangeText),
                  ),
                ),
                title: Text(patient.name),
                trailing: patient.id == app.currentPatient?.id
                    ? const Icon(Icons.check, color: HousepitalColors.orange)
                    : null,
                onTap: () {
                  app.switchPatient(patient);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.label,
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
  final String? phone;

  const _TeamMemberRow({
    required this.role,
    required this.name,
    required this.icon,
    this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Standard home icon tile — rounded square, tinted bg, 22pt icon.
        // (Matches Current Services / Medications / Care Guides for a single
        // consistent icon system across the Home screen.) One accent: always
        // orange — per-role identity colors are retired.
        AppIconTile(icon: icon, color: HousepitalColors.orange),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.hc.black,
                ),
              ),
              Text(
                role,
                style: TextStyle(fontSize: 12, color: context.hc.greyLight),
              ),
            ],
          ),
        ),
        if (phone != null && phone!.isNotEmpty) ...[
          // Care Team pattern (care_team_screen._MemberRow): filled-orange
          // square call button + outlined square chat button.
          Semantics(
            label: 'Call $role',
            button: true,
            child: IconButton(
              onPressed: () => launchUrl(Uri.parse('tel:$phone')),
              style: IconButton.styleFrom(
                backgroundColor: HousepitalColors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.phone, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            label: 'WhatsApp $role',
            button: true,
            child: IconButton(
              onPressed: () => launchUrl(
                Uri.parse('https://wa.me/91$phone'),
                mode: LaunchMode.externalApplication,
              ),
              style: IconButton.styleFrom(
                backgroundColor: context.hc.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: context.hc.divider),
                ),
              ),
              // WhatsApp brand green on the glyph signals which app opens.
              icon: const Icon(Icons.chat, size: 20, color: _whatsAppGreen),
            ),
          ),
        ],
      ],
    );
  }
}
