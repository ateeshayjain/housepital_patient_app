import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../../providers/my_care_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/vital_classifier.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => _loadData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final patientId = context.read<AppProvider>().currentPatient?.id;
    if (patientId != null) {
      context.read<MyCareProvider>().loadMyCareData(patientId);
    } else {
      // Patient not loaded yet — seed demo data directly
      context.read<MyCareProvider>().loadMyCareData('pat_demo_rajesh');
    }
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
        showHome: false,
        title: Text(l.t('tab_my_care')),
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
      physics: const AlwaysScrollableScrollPhysics(),
      // top: clear the glass app bar; bottom: clear the glass nav.
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Health Manager Banner
          if (myCare.healthManager != null)
            HealthManagerBanner(manager: myCare.healthManager!),

          // 2. Active Services
          SectionHeader(title: l.t('active_services')),
          ...myCare.activeServices.map((service) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: app.todayReport!.totalTasks > 0
                                ? app.todayReport!.completedTasks / app.todayReport!.totalTasks
                                : 0,
                            backgroundColor: context.hc.greyLighter,
                            color: context.hc.success,
                            strokeWidth: 4,
                          ),
                          Text(
                            '${app.todayReport!.completedTasks}/${app.todayReport!.totalTasks}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
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

          // 4a. Daily Care Rating
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _DailyCareRatingCard(),
          ),

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
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/medications'),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.hc.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.hc.divider),
                ),
                child: Row(
                  children: [
                    const AppIconTile(icon: Icons.medication, color: HousepitalColors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('5 active medications',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('Amlodipine, Metformin, Aspirin, Pantoprazole, Insulin',
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
                    fontSize: 18, fontWeight: FontWeight.w600)),
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

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/vitals'),
        child: Container(
          width: 90,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.hc.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.hc.divider),
          ),
          // FittedBox(scaleDown): real font fits the 90x88 pill at scale 1, so
          // there's zero visual change on-device. Only when text would exceed
          // the box (very large Dynamic Type / the Ahem test font) does it
          // shrink to fit instead of painting an overflow stripe.
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
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.hc.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hc.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "How was today's care?",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_ratedToday != null)
            Row(
              children: [
                ...List.generate(5, (i) {
                  final filled = i < _ratedToday!;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: HousepitalColors.orange,
                      size: 24,
                    ),
                  );
                }),
                const SizedBox(width: 8),
                Text('Rated today',
                    style: TextStyle(
                        fontSize: 12, color: context.hc.greyLight)),
              ],
            )
          else ...[
            Row(
              children: List.generate(5, (i) {
                final stars = i + 1;
                return Expanded(
                  child: Semantics(
                    label: 'Rate $stars star${stars == 1 ? '' : 's'}',
                    button: true,
                    child: IconButton(
                      onPressed: () => _onRate(stars),
                      icon: const Icon(Icons.star_border,
                          color: HousepitalColors.orange, size: 32),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to rate. Your feedback helps us improve.',
              style:
                  TextStyle(fontSize: 12, color: context.hc.greyLight),
            ),
          ],
        ],
      ),
    );
  }
}
