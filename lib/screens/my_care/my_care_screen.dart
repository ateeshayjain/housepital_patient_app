import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../../providers/medication_provider.dart';
import '../../providers/my_care_provider.dart';
import '../../services/handover_report_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/permissions.dart';
import '../../utils/vital_classifier.dart';
import '../../widgets/care_pulse_ring.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass.dart';
import '../../screens/main_shell.dart';
import 'widgets/health_manager_banner.dart';
import 'widgets/active_service_card.dart';
import 'widgets/doctor_advice_card.dart';
import 'widgets/staff_attendance_section.dart';

class MyCareScreen extends StatefulWidget {
  const MyCareScreen({super.key});

  @override
  State<MyCareScreen> createState() => _MyCareScreenState();
}

class _MyCareScreenState extends State<MyCareScreen> with WidgetsBindingObserver {
  // C3 calm pass (iOS large-title pattern): the display title lives in the
  // body; the GlassAppBar title only fades in once the body title has
  // scrolled under the bar.
  final ScrollController _scrollController = ScrollController();
  bool _showBarTitle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _loadData());
  }

  void _onScroll() {
    final show =
        _scrollController.hasClients && _scrollController.offset > 28;
    if (show != _showBarTitle) setState(() => _showBarTitle = show);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app comes to foreground and data is stale
    if (state == AppLifecycleState.resumed) {
      final myCare = context.read<MyCareProvider>();
      if (myCare.isStale) _loadData();
    }
  }

  void _loadData() {
    final patientId =
        context.read<AppProvider>().currentPatient?.id ?? 'pat_demo_rajesh';
    context.read<MyCareProvider>().loadMyCareData(patientId);
    // Medications summary card reads MedicationProvider (same source as the
    // Home snippet) — make sure it's populated even if Home wasn't visited.
    context.read<MedicationProvider>().loadMedications(patientId);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final myCare = context.watch<MyCareProvider>();
    final app = context.watch<AppProvider>();

    return Scaffold(
      // Liquid Glass: content scrolls under the translucent app bar.
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        showHome: true, // owner: home button on every screen (only the Home tab omits it)
        // Care calendar lives here now (owner: 'move the calendar to My Care
        // so that there are five icons below'). Custom actions sit first in
        // the trailing group, before search and cart.
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Care calendar',
            onPressed: () => Navigator.pushNamed(context, '/care-calendar'),
          ),
        ],
        // Bar title is hidden while the in-body large title is at rest, and
        // fades in on scroll. Loading/error/empty states have no in-body
        // title, so the bar title stays visible there.
        title: AnimatedOpacity(
          opacity: (!myCare.hasActiveServices || _showBarTitle) ? 1.0 : 0.0,
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 150),
          child: Text(l.t('tab_my_care')),
        ),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final patientId = app.currentPatient?.id;
          if (patientId != null) {
            await myCare.refresh(patientId);
          }
        },
        child: _buildBody(myCare, app, l),
      ),
    );
  }

  Widget _buildBody(MyCareProvider myCare, AppProvider app, AppLocalizations l) {
    // Watch so the summary card live-updates when meds are added/stopped.
    final activeMeds = context.watch<MedicationProvider>().activeMedications;

    if (myCare.isLoading && myCare.activeServices.isEmpty) {
      return const LoadingWidget();
    }

    if (myCare.error != null && myCare.activeServices.isEmpty) {
      return _buildError(myCare, app, l);
    }

    if (!myCare.hasActiveServices) {
      return _buildEmpty(l);
    }

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      // top: clear the glass app bar; bottom: clear the glass nav.
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
          bottom: 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0. Large display title (C3 calm pass) — confident in-body
          // large-title header; the bar title takes over once scrolled.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              l.t('tab_my_care'),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: context.hc.black,
              ),
            ),
          ),

          // 1. Health Manager Banner
          if (myCare.healthManager != null)
            HealthManagerBanner(manager: myCare.healthManager!),

          // 2. Doctor Handover Report — flagship; owner moved it to the TOP
          // of My Care (field request 2026-06-11). Role-gated: the handover
          // PDF is the patient's full medical history — only patient/family
          // may export it; hidden entirely (not disabled) for staff roles.
          if (canUserPerform(app.currentUserRole, UserAction.shareHandover)) ...[
            const SectionHeader(title: 'Share with your doctor'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _DoctorHandoverCard(),
            ),
          ],

          // 3. Active Services
          SectionHeader(title: l.t('active_services')),
          ...myCare.activeServices.map((service) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                child: ActiveServiceCard(
                  service: service,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/service-detail',
                    arguments: service,
                  ),
                ),
              )),

          // 3. Today's Vitals
          if (app.latestVitals != null) ...[
            SectionHeader(
              title: l.t('today_vitals'),
              actionText: l.t('see_all'),
              onAction: () => Navigator.pushNamed(context, '/vitals'),
            ),
            SizedBox(
              // Pill content (8+8 padding + label row + 4 gap + value + unit)
              // is ~77px; 88 gives headroom so it never overflows the strip
              // (was 72 → "BOTTOM OVERFLOWED" stripe).
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _vitalPill('BP', '${app.latestVitals!.systolic?.toInt() ?? "--"}/${app.latestVitals!.diastolic?.toInt() ?? "--"}', 'mmHg', app.latestVitals!.systolic, 'bp_systolic'),
                  _vitalPill('SpO2', '${app.latestVitals!.spo2?.toInt() ?? "--"}', '%', app.latestVitals!.spo2, 'spo2'),
                  _vitalPill('Pulse', '${app.latestVitals!.pulse?.toInt() ?? "--"}', 'bpm', app.latestVitals!.pulse, 'pulse'),
                  _vitalPill('Temp', '${app.latestVitals!.temperature ?? "--"}', '°F', app.latestVitals!.temperature, 'temperature'),
                  _vitalPill('Sugar', '${app.latestVitals!.sugar?.toInt() ?? "--"}', 'mg/dl', app.latestVitals!.sugar, 'sugar'),
                ],
              ),
            ),
          ],

          // 4. Today's Report
          if (app.todayReport != null) ...[
            SectionHeader(
              title: l.t('today_report'),
              actionText: l.t('details'),
              onAction: () => Navigator.pushNamed(context, '/report-detail',
                  arguments: app.todayReport),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HousepitalCard(
                child: Row(
                  children: [
                    CarePulseRing(
                      value: app.todayReport!.totalTasks > 0
                          ? app.todayReport!.completedTasks / app.todayReport!.totalTasks
                          : 0,
                      size: 48,
                      strokeWidth: 4,
                      semanticLabel:
                          '${app.todayReport!.completedTasks} of ${app.todayReport!.totalTasks} tasks completed',
                      center: Text(
                        '${app.todayReport!.completedTasks}/${app.todayReport!.totalTasks}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${app.todayReport!.completedTasks} of ${app.todayReport!.totalTasks} tasks completed',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          if (app.todayReport!.staffNotes != null)
                            Text(
                              app.todayReport!.staffNotes!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: context.hc.greyLight),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 4b. Doctor's Advice — recommendations from the last consultation
          const DoctorAdviceCard(),

          // 5. Today's Staff Attendance
          if (myCare.activeServices.any((s) => s.hasStaff))
            StaffAttendanceSection(services: myCare.activeServices),

          // 6. Medications Summary
          SectionHeader(
            title: 'Medications',
            actionText: l.t('see_all'),
            onAction: () => Navigator.pushNamed(context, '/medications'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Canonical top-level card: HousepitalCard (squircle 16, press
            // 0.97) with onTap — no more hand-rolled radius-12 Container in a
            // bare GestureDetector.
            child: HousepitalCard(
              padding: const EdgeInsets.all(12),
              onTap: () => Navigator.pushNamed(context, '/medications'),
              child: Row(
                children: [
                  const AppIconTile(icon: Icons.medication, color: HousepitalColors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live count + names from MedicationProvider — same
                        // source as the Home medications snippet (no more
                        // hardcoded "5 active medications" demo copy).
                        Text(
                            activeMeds.isEmpty
                                ? 'No active medications'
                                : '${activeMeds.length} active medication${activeMeds.length == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        if (activeMeds.isNotEmpty)
                          Text(activeMeds.map((m) => m.name).join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: context.hc.greyLight)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.hc.greyLight, size: 18),
                ],
              ),
            ),
          ),

          // 8. Daily Care Rating — rating belongs at the END of the journey,
          // after the day's care summary (last content card before padding).
          // Full-bleed like every sibling section (field report: the card
          // wasn't spanning the screen width).
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: _DailyCareRatingCard(),
            ),
          ),

          // Billing intentionally NOT shown here — it lives in the Billing tab
          // (single source of truth for invoices, dues, and payment history).
        ],
      ),
    );
  }

  Widget _buildError(
      MyCareProvider myCare, AppProvider app, AppLocalizations l) {
    return ErrorRetryWidget(
      message: l.t('error_load_data'),
      onRetry: _loadData,
    );
  }

  Widget _buildEmpty(AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border,
                size: 64, color: context.hc.greyLight),
            const SizedBox(height: 16),
            Text(l.t('no_active_services'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(l.t('no_active_services_desc'),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.hc.greyLight)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => MainShell.switchToTab(2), // Services tab
              child: Text(l.t('book_a_service')),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/vitals'),
              child: Text(l.t('view_vitals_history')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vitalPill(String label, String value, String unit, double? rawValue, String vitalType) {
    Color statusColor = context.hc.greyLight;
    if (rawValue != null) {
      final status = classifyVital(vitalType, rawValue);
      statusColor = status == 'green'
          ? context.hc.success
          : status == 'yellow'
              ? context.hc.warning
              : context.hc.error;
    }

    // Flat radius-12 bordered SUB-tile by canon (small pill inside the strip,
    // not a top-level card) — but tappable surfaces use Material + InkWell,
    // never a bare GestureDetector, so taps get ripple feedback.
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: context.hc.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/vitals'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 90,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.hc.divider),
            ),
            // FittedBox(scaleDown): real font fits the 90x88 pill at scale 1,
            // so there's zero visual change on-device. Only when text would
            // exceed the box (very large Dynamic Type / the Ahem test font)
            // does it shrink to fit instead of painting an overflow stripe.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(label,
                          style: TextStyle(
                              fontSize: 11, color: context.hc.greyLight)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(unit,
                      style: TextStyle(
                          fontSize: 11, color: context.hc.greyLight)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doctor Handover Report card — builds + shares the flagship PDF
// ---------------------------------------------------------------------------
class _DoctorHandoverCard extends StatefulWidget {
  const _DoctorHandoverCard();

  @override
  State<_DoctorHandoverCard> createState() => _DoctorHandoverCardState();
}

class _DoctorHandoverCardState extends State<_DoctorHandoverCard> {
  bool _building = false;

  Future<void> _share() async {
    if (_building) return;
    setState(() => _building = true);
    try {
      await HandoverReportService().shareHandover();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Couldn't build the report. Please try again, or ask your "
                  'Health Manager to send it to you.')),
        );
      }
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HousepitalCard(
      child: Row(
        children: [
          // Mini page thumbnail — an instantly readable "document" glyph that
          // teases the PDF artifact this flagship card produces (decorative;
          // hc.white = surface in light, elevated surface in dark).
          ExcludeSemantics(
            child: Container(
              width: 40,
              height: 52,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.hc.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: context.hc.divider),
              ),
              child: Row(
                children: [
                  // 3px orange left rule — the report's brand spine.
                  Container(width: 3, color: context.hc.orange),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 5,
                        children: [
                          for (final w in const [24.0, 18.0, 21.0])
                            Container(
                              width: w,
                              height: 2,
                              color: context.hc.greyLight,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Doctor Handover Report',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Complete summary: history, medicines, vitals, visits & reports',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.hc.greyLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Share doctor handover report',
            button: true,
            child: FilledButton.tonal(
              onPressed: _building ? null : _share,
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: _building
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Share'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily Care Rating Card
// ---------------------------------------------------------------------------
class _DailyCareRatingCard extends StatefulWidget {
  const _DailyCareRatingCard();

  @override
  State<_DailyCareRatingCard> createState() => _DailyCareRatingCardState();
}

class _DailyCareRatingCardState extends State<_DailyCareRatingCard> {
  int? _ratedToday;
  bool _loaded = false;

  String get _todayKey {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'daily_rating_$y-$m-$d';
  }

  @override
  void initState() {
    super.initState();
    _loadExistingRating();
  }

  Future<void> _loadExistingRating() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getInt(_todayKey);
    if (mounted) {
      setState(() {
        _ratedToday = existing;
        _loaded = true;
      });
    }
  }

  Future<void> _onRate(int stars) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_todayKey, stars);
    if (!mounted) return;
    setState(() => _ratedToday = stars);

    if (stars >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Thanks for rating! We've shared your feedback with the team."),
        ),
      );
    } else {
      _showLowRatingModal(stars);
    }
  }

  void _showLowRatingModal(int stars) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("We're sorry. What went wrong?",
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'Tell us what we can do better (visible to your coordinator)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    Navigator.pushNamed(
                      context,
                      '/raise-concern',
                      arguments: {
                        'rating': stars,
                        'preFilledNote': controller.text.trim(),
                        'source': 'daily_care_rating',
                      },
                    );
                  },
                  child: const Text('Send to coordinator'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      // Avoid flicker: render nothing until SharedPreferences resolves
      return const SizedBox.shrink();
    }

    // Rationale: rating belongs at the END of the journey (after the day's
    // care summary). User-review feedback: the previous single-row layout
    // truncated the question to "How was t…" on narrow phones, so the card
    // is now a tight TWO-LINE layout — full-width question on line 1 (never
    // ellipsised), the 5 stars left-aligned on line 2. Tapping a star still
    // rates the day (SnackBar for 4–5 stars, "what went wrong" sheet for
    // 1–3), so the post-tap feedback already explains the interaction.
    // Canonical top-level card: HousepitalCard (squircle 16) instead of a
    // hand-rolled radius-12 bordered Container.
    return HousepitalCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1: full question — no maxLines/ellipsis, wraps if it must.
          const Text(
            "How was today's care?",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          // Line 2: the 5 stars, left-aligned with small gaps.
          if (_ratedToday != null)
            Semantics(
              label: 'Rated $_ratedToday of 5 today',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = i < _ratedToday!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 2, vertical: 8),
                    child: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: HousepitalColors.orange,
                      size: 24,
                    ),
                  );
                }),
              ),
            )
          else
            // 24px stars; each star keeps a ≥44pt tap target. No extra gap
            // widgets: the ~48px Material tap targets around the 24px glyphs
            // already yield a comfortable visual gap, and 5×48 = 240 is
            // exactly what fits inside the card at the 320px minimum.
            // This card's accessible rater is now the shared StarRatingInput
            // (lib/widgets/common_widgets.dart) — same Semantics + 44pt
            // behavior, used app-wide.
            StarRatingInput(value: 0, onChanged: _onRate),
        ],
      ),
    );
  }
}
