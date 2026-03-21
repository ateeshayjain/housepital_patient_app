import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../data/care_packages.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/payment_reminder_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
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
  Duration _onDutySince = Duration.zero;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<AppProvider>().loadPatients().then((_) {
        context.read<AppProvider>().loadDashboard();
      });
    });
    _startDutyTimer();
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

  @override
  void dispose() {
    _dutyTimer?.cancel();
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
                if (app.isDashboardLoading)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: LoadingWidget(),
                  )
                else ...[
                  _buildVitalsHighlights(context, l, app),
                  _buildStaffSection(context, l, app),
                  _buildDailyReportSection(context, l, app),
                  _buildServicesSection(context, l),
                  _buildCarePackagesSection(context),
                  _buildPaymentBanner(context, l, app),
                  const SizedBox(height: 16),
                  SOSButton(onTap: () => Navigator.pushNamed(context, '/sos')),
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
                if (app.currentPatient != null)
                  Semantics(
                    label: 'Switch patient. Current: ${app.currentPatient!.name}',
                    button: app.patients.length > 1,
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
                            if (app.patients.length > 1) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down,
                                  color: HousepitalColors.grey, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Search icon
          Semantics(
            label: 'Search',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.pushNamed(context, '/search'),
            ),
          ),
          // Cart icon with badge
          Consumer<CartProvider>(
            builder: (_, cart, __) => Semantics(
              label: 'Cart${cart.itemCount > 0 ? ", ${cart.itemCount} items" : ""}',
              button: true,
              child: IconButton(
                icon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text('${cart.itemCount}',
                      style: const TextStyle(fontSize: 10)),
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
          Semantics(
            label: 'Settings',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Vitals — Apple Health minimal style
  // ---------------------------------------------------------------------------
  Widget _buildVitalsHighlights(
      BuildContext context, AppLocalizations l, AppProvider app) {
    final vitals = app.latestVitals;

    return Column(
      children: [
        const SizedBox(height: 8),
        SectionHeader(
          title: l.t('todays_vitals'),
          actionText: l.t('see_all'),
          onAction: () => Navigator.pushNamed(context, '/vitals'),
        ),
        const SizedBox(height: 4),
        // Horizontal scrolling vitals row — clean, minimal
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
                color: const Color(0xFFE53935),
                onTap: () => Navigator.pushNamed(context, '/vitals', arguments: 'bp'),
              ),
              _VitalPill(
                label: 'SpO2',
                value: vitals?.spo2?.toInt().toString() ?? '--',
                unit: '%',
                color: const Color(0xFF1565C0),
                onTap: () => Navigator.pushNamed(context, '/vitals', arguments: 'spo2'),
              ),
              _VitalPill(
                label: 'Pulse',
                value: vitals?.pulse?.toInt().toString() ?? '--',
                unit: 'bpm',
                color: const Color(0xFFE53935),
                onTap: () => Navigator.pushNamed(context, '/vitals', arguments: 'pulse'),
              ),
              _VitalPill(
                label: 'Temp',
                value: vitals?.temperature?.toStringAsFixed(1) ?? '--',
                unit: '\u00B0F',
                color: const Color(0xFFEF6C00),
                onTap: () => Navigator.pushNamed(context, '/vitals', arguments: 'temperature'),
              ),
              _VitalPill(
                label: 'Sugar',
                value: vitals?.sugar?.toInt().toString() ?? '--',
                unit: 'mg/dl',
                color: const Color(0xFF7B1FA2),
                onTap: () => Navigator.pushNamed(context, '/vitals', arguments: 'sugar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Staff Section — Redesigned with photo, verified badge, shift, quick actions
  // ---------------------------------------------------------------------------
  Widget _buildStaffSection(
      BuildContext context, AppLocalizations l, AppProvider app) {
    final deployment = app.activeDeployment;
    final attendance = app.todayAttendance;

    if (deployment == null) return const SizedBox.shrink();

    final status = attendance?.status ?? 'waiting';
    final statusColor = AttendanceHelper.getStatusColor(status);
    final statusIcon = AttendanceHelper.getStatusIcon(status);

    String statusText;
    switch (status) {
      case 'checked_in':
        statusText = l.t('attendance_checked_in', {
          'time': attendance?.checkInTime != null
              ? DateHelper.formatTime(attendance!.checkInTime!)
              : ''
        });
        break;
      case 'late':
        statusText = l.t('attendance_late', {
          'time': attendance?.checkInTime != null
              ? DateHelper.formatTime(attendance!.checkInTime!)
              : ''
        });
        break;
      case 'absent':
        statusText = l.t('attendance_absent');
        break;
      case 'on_leave':
        statusText = l.t('attendance_on_leave',
            {'name': attendance?.replacementName ?? ''});
        break;
      case 'checked_out':
        statusText = l.t('attendance_checked_out', {
          'time': attendance?.checkOutTime != null
              ? DateHelper.formatTime(attendance!.checkOutTime!)
              : ''
        });
        break;
      default:
        statusText = l.t('attendance_waiting');
    }

    // Calculate on-duty duration
    final dutyHours = attendance?.checkInTime != null
        ? DateTime.now().difference(attendance!.checkInTime!)
        : Duration.zero;
    final dutyHoursText = dutyHours.inHours > 0
        ? '${dutyHours.inHours}h ${dutyHours.inMinutes % 60}m'
        : '${dutyHours.inMinutes}m';

    return Column(
      children: [
        const SizedBox(height: 16),
        const SectionHeader(
          title: 'Your Staff',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: HousepitalCard(
            onTap: () => Navigator.pushNamed(context, '/staff-profile',
                arguments: deployment.staffId),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Staff info row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: HousepitalColors.orangeLight,
                      backgroundImage: deployment.staffPhoto != null
                          ? NetworkImage(deployment.staffPhoto!)
                          : null,
                      child: deployment.staffPhoto == null
                          ? const Icon(Icons.person,
                              color: HousepitalColors.orange, size: 28)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  deployment.staffName ?? 'Staff',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: HousepitalColors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Semantics(
                                label: 'Verified staff',
                                child: const Icon(Icons.verified,
                                    color: HousepitalColors.success, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            deployment.staffRole ?? 'Caretaker',
                            style: const TextStyle(
                              fontSize: 13,
                              color: HousepitalColors.greyLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Rating stars
                          if (deployment.staffRating != null)
                            Row(
                              children: [
                                ..._buildRatingStars(deployment.staffRating!),
                                const SizedBox(width: 6),
                                Text(
                                  deployment.staffRating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: HousepitalColors.grey,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      text: status.replaceAll('_', ' ').toUpperCase(),
                      color: statusColor,
                      icon: statusIcon,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Status + duty info row
                Row(
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 13,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Shift info
                    const Icon(Icons.schedule,
                        size: 14, color: HousepitalColors.greyLight),
                    const SizedBox(width: 4),
                    Text(
                      _getShiftLabel(deployment.shiftType),
                      style: const TextStyle(
                        fontSize: 12,
                        color: HousepitalColors.greyLight,
                      ),
                    ),
                    if (attendance?.checkInTime != null &&
                        status == 'checked_in') ...[
                      const SizedBox(width: 16),
                      const Icon(Icons.timelapse,
                          size: 14, color: HousepitalColors.greyLight),
                      const SizedBox(width: 4),
                      Text(
                        'On duty: $dutyHoursText',
                        style: const TextStyle(
                          fontSize: 12,
                          color: HousepitalColors.greyLight,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      l.t('day_count', {
                        'current': deployment.daysSinceStart.toString(),
                        'total': (deployment.totalDays ?? 90).toString(),
                      }),
                      style: const TextStyle(
                        fontSize: 12,
                        color: HousepitalColors.greyLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quick action buttons — 44pt touch targets
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.phone,
                        label: 'Call',
                        semanticsLabel: 'Call ${deployment.staffName ?? "staff"}',
                        onTap: () {
                          // TODO: launch phone call
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.message,
                        label: 'Message',
                        semanticsLabel:
                            'Message ${deployment.staffName ?? "staff"}',
                        onTap: () {
                          // TODO: open messaging
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.star_border,
                        label: 'Rate',
                        semanticsLabel:
                            'Rate ${deployment.staffName ?? "staff"}',
                        onTap: () {
                          // TODO: open rating sheet
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getShiftLabel(String shiftType) {
    switch (shiftType) {
      case '12hr_day':
        return '8 AM - 8 PM';
      case '12hr_night':
        return '8 PM - 8 AM';
      case '24hr':
        return '24-hour shift';
      default:
        return shiftType;
    }
  }

  List<Widget> _buildRatingStars(double rating) {
    final List<Widget> stars = [];
    for (int i = 1; i <= 5; i++) {
      if (rating >= i) {
        stars.add(const Icon(Icons.star,
            size: 14, color: HousepitalColors.orange));
      } else if (rating >= i - 0.5) {
        stars.add(const Icon(Icons.star_half,
            size: 14, color: HousepitalColors.orange));
      } else {
        stars.add(const Icon(Icons.star_border,
            size: 14, color: HousepitalColors.greyLight));
      }
    }
    return stars;
  }

  // ---------------------------------------------------------------------------
  // Daily Report Section — Progress ring + task list
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
                      // Progress ring + summary
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

                      // Task sections with checkmarks
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

                      // View Full Report button
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
  // Quick Services — improved touch targets, InkWell
  // ---------------------------------------------------------------------------
  Widget _buildServicesSection(BuildContext context, AppLocalizations l) {
    return Column(
      children: [
        const SizedBox(height: 8),
        SectionHeader(title: l.t('book_services')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: HousepitalCard(
            child: Row(
              children: [
                _serviceChip(
                    context, Icons.people, 'Manpower', () {
                      MainShell.switchToTab(2);
                      ServiceCatalogScreen.switchToSubTab(0);
                    }),
                const SizedBox(width: 12),
                _serviceChip(
                    context, Icons.local_shipping, 'Equipment', () {
                      MainShell.switchToTab(2);
                      ServiceCatalogScreen.switchToSubTab(1);
                    }),
                const SizedBox(width: 12),
                _serviceChip(
                    context, Icons.biotech, 'Lab Tests', () {
                      MainShell.switchToTab(2);
                      ServiceCatalogScreen.switchToSubTab(3);
                    }),
                const SizedBox(width: 12),
                _serviceChip(
                    context, Icons.arrow_forward, l.t('see_all'), () {
                      MainShell.switchToTab(2);
                      ServiceCatalogScreen.switchToSubTab(0);
                    }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _serviceChip(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 80, // >= 44pt touch target
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HousepitalColors.orangeLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(icon, color: HousepitalColors.orange, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 12, color: HousepitalColors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // Care Packages Section
  // ---------------------------------------------------------------------------
  Widget _buildCarePackagesSection(BuildContext context) {
    final iconMap = <String, IconData>{
      'healing': Icons.healing,
      'bedtime': Icons.bedtime,
      'child_care': Icons.child_care,
      'psychology': Icons.psychology,
      'elderly': Icons.elderly,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Care Packages',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: () {
                  // Switch to Services tab and show packages
                  MainShell.switchToTab(2);
                },
                child: const Text('See All',
                    style: TextStyle(color: HousepitalColors.orange)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: carePackages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final pkg = carePackages[index];
              return GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/package-detail',
                    arguments: pkg),
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: HousepitalColors.orangeLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              iconMap[pkg.icon] ?? Icons.local_hospital,
                              color: HousepitalColors.orange,
                              size: 22,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: HousepitalColors.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${pkg.discountPercent.toInt()}% OFF',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(pkg.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(pkg.condition,
                          style: const TextStyle(
                              fontSize: 12,
                              color: HousepitalColors.greyLight)),
                      const Spacer(),
                      Text(
                        '${pkg.items.length} items + ${pkg.services.length} ${pkg.services.length == 1 ? "service" : "services"}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: HousepitalColors.orange),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Payment Reminders Section (Airtel-style)
  // ---------------------------------------------------------------------------
  Widget _buildPaymentBanner(
      BuildContext context, AppLocalizations l, AppProvider app) {
    final reminders = PaymentReminderService.getUpcomingReminders();
    final urgentReminders =
        reminders.where((r) => r.shouldShowReminder).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Urgent reminder banner (2 days or less)
          if (urgentReminders.isNotEmpty)
            ...urgentReminders.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
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
                                        fontSize: 10,
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

          // Upcoming payments summary (all reminders)
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
                    padding: const EdgeInsets.all(14),
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
// Vital Pill — Apple Health minimal style
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
                  // Color dot
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
// Quick Action Button — 44pt touch target
// =============================================================================
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Material(
        color: HousepitalColors.orangeLight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 48, // >= 44pt
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: HousepitalColors.orangeText),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.orangeText,
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
// Progress Ring Painter — circular progress indicator
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

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
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
