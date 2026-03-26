import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../../providers/my_care_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/vital_classifier.dart';
import '../../widgets/common_widgets.dart';
import '../../screens/main_shell.dart';
import 'widgets/health_manager_banner.dart';
import 'widgets/active_service_card.dart';
import 'widgets/staff_attendance_section.dart';
import 'widgets/billing_summary_section.dart';
import 'widgets/quick_actions_row.dart';

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
      appBar: AppBar(
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
      return const Center(child: LoadingWidget());
    }

    if (myCare.error != null && myCare.activeServices.isEmpty) {
      return _buildError(myCare, app, l);
    }

    if (!myCare.hasActiveServices) {
      return _buildEmpty(l);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Health Manager Banner
          if (myCare.healthManager != null)
            HealthManagerBanner(manager: myCare.healthManager!),

          // 2. Active Services
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l.t('active_services'),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l.t('today_vitals'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/vitals'),
                    child: Text(l.t('see_all'),
                        style: const TextStyle(
                            color: HousepitalColors.orange, fontSize: 13)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _vitalPill('BP', '${app.latestVitals!.systolic?.toInt() ?? "--"}/${app.latestVitals!.diastolic?.toInt() ?? "--"}', 'mmHg', app.latestVitals!.systolic, 'systolic'),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l.t('today_report'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/report-detail', arguments: app.todayReport),
                    child: Text(l.t('details'),
                        style: const TextStyle(
                            color: HousepitalColors.orange, fontSize: 13)),
                  ),
                ],
              ),
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
                            backgroundColor: HousepitalColors.greyLighter,
                            color: HousepitalColors.success,
                            strokeWidth: 4,
                          ),
                          Text(
                            '${app.todayReport!.completedTasks}/${app.todayReport!.totalTasks}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
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
                              style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 5. Today's Staff Attendance
          if (myCare.activeServices.any((s) => s.hasStaff))
            StaffAttendanceSection(services: myCare.activeServices),

          // 6. Medications Summary
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Medications',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/medications'),
                  child: Text(l.t('see_all'),
                      style: const TextStyle(
                          color: HousepitalColors.orange, fontSize: 13)),
                ),
              ],
            ),
          ),
          Padding(
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
                          Text('5 active medications',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('Amlodipine, Metformin, Aspirin, Pantoprazole, Insulin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: HousepitalColors.greyLight)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: HousepitalColors.greyLight, size: 18),
                  ],
                ),
              ),
            ),
          ),

          // 7. Billing Summary
          if (myCare.activeServices.any((s) => s.totalPaid != null))
            BillingSummarySection(services: myCare.activeServices),
        ],
      ),
    );
  }

  Widget _buildError(
      MyCareProvider myCare, AppProvider app, AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l.t('error_load_data'),
              style: const TextStyle(color: HousepitalColors.greyLight)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loadData,
            child: Text(l.t('tap_to_retry')),
          ),
        ],
      ),
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
                size: 64, color: HousepitalColors.greyLight),
            const SizedBox(height: 16),
            Text(l.t('no_active_services'),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(l.t('no_active_services_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: HousepitalColors.greyLight)),
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
    Color statusColor = HousepitalColors.greyLight;
    if (rawValue != null) {
      final status = classifyVital(vitalType, rawValue);
      statusColor = status == 'green'
          ? HousepitalColors.success
          : status == 'yellow'
              ? HousepitalColors.warning
              : HousepitalColors.error;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/vitals'),
        child: Container(
          width: 90,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: HousepitalColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HousepitalColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
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
                      style: const TextStyle(
                          fontSize: 11, color: HousepitalColors.greyLight)),
                ],
              ),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              Text(unit,
                  style: const TextStyle(
                      fontSize: 11, color: HousepitalColors.greyLight)),
            ],
          ),
        ),
      ),
    );
  }
}
