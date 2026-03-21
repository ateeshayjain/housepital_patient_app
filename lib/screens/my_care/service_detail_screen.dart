import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/my_care_models.dart';
import '../../providers/my_care_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import 'widgets/vitals_trend_grid.dart';
import 'widgets/care_report_section.dart';
import 'widgets/equipment_deployed_section.dart';

class ServiceDetailScreen extends StatefulWidget {
  final ActiveService service;

  const ServiceDetailScreen({super.key, required this.service});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      if (widget.service.deploymentIds.isNotEmpty) {
        context
            .read<MyCareProvider>()
            .loadServiceDetail(widget.service.deploymentIds.first);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final myCare = context.watch<MyCareProvider>();
    final color = HousepitalColors.serviceColor(widget.service.serviceCategory);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.service.name),
      ),
      body: myCare.isDetailLoading
          ? const Center(child: LoadingWidget())
          : myCare.detailError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l.t('error_load_data')),
                      TextButton(
                        onPressed: () {
                          if (widget.service.deploymentIds.isNotEmpty) {
                            myCare.loadServiceDetail(
                                widget.service.deploymentIds.first);
                          }
                        },
                        child: Text(l.t('tap_to_retry')),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    if (widget.service.deploymentIds.isNotEmpty) {
                      await myCare.loadServiceDetail(
                          widget.service.deploymentIds.first);
                    }
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with progress
                        _buildHeader(color),

                        // Staff on duty
                        if (widget.service.showStaff &&
                            myCare.selectedServiceDetail != null)
                          _buildStaffSection(myCare.selectedServiceDetail!, l),

                        // 7-day attendance
                        if (widget.service.showAttendance &&
                            myCare.selectedServiceDetail != null)
                          _buildAttendanceCalendar(
                              myCare.selectedServiceDetail!, l),

                        // Vitals trend
                        if (widget.service.showVitals &&
                            myCare.selectedServiceDetail?.vitalsSummary != null)
                          VitalsTrendGrid(
                              vitals:
                                  myCare.selectedServiceDetail!.vitalsSummary!),

                        // Today's care report
                        if (widget.service.showDailyReport &&
                            myCare.selectedServiceDetail?.todayReport != null)
                          CareReportSection(
                            report: myCare.selectedServiceDetail!.todayReport!,
                            deploymentId: widget.service.deploymentIds.isNotEmpty
                                ? widget.service.deploymentIds.first
                                : '',
                          ),

                        // Medications
                        if (widget.service.showMedications)
                          _buildMedicationsLink(l),

                        // Equipment deployed
                        if (widget.service.showEquipment &&
                            myCare.selectedServiceDetail != null)
                          EquipmentDeployedSection(
                              equipment:
                                  myCare.selectedServiceDetail!.equipment),

                        // Billing summary for this service
                        _buildServiceBilling(l),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader(Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.service.name,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Started ${DateHelper.formatDate(widget.service.startDate)}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                widget.service.isSessionBased
                    ? 'Session ${widget.service.consumedDays} of ${widget.service.totalDays}'
                    : 'Day ${widget.service.consumedDays} of ${widget.service.totalDays}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (widget.service.dailyRate != null)
                Text(
                  '${DateHelper.formatCurrency(widget.service.dailyRate!)}/day',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widget.service.progressFraction,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffSection(ServiceDetail detail, AppLocalizations l) {
    if (detail.staffOnDuty.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('staff_on_duty'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...detail.staffOnDuty.map((staff) => Card(
                color: staff.isReplacement
                    ? const Color(0xFFFEFCE8)
                    : const Color(0xFFF0FDF4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: staff.isReplacement
                        ? HousepitalColors.warning
                        : HousepitalColors.success,
                    child: Text(
                      staff.name.split(' ').map((n) => n[0]).take(2).join(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(staff.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (staff.isReplacement)
                        Text(' (Replacement)',
                            style: TextStyle(
                                fontSize: 11,
                                color: HousepitalColors.warning)),
                    ],
                  ),
                  subtitle: Text(
                    '${staff.role} (${staff.shiftType})${staff.checkInTime != null ? ' · Checked in ${DateHelper.formatTime(staff.checkInTime!)}' : ''}',
                  ),
                  trailing: staff.checkInTime != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatDuration(staff.onDutyDuration),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: staff.isReplacement
                                      ? HousepitalColors.warning
                                      : HousepitalColors.success),
                            ),
                            Text('on shift',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[400])),
                          ],
                        )
                      : null,
                  onTap: () => Navigator.pushNamed(context, '/staff-profile',
                      arguments: staff.id),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAttendanceCalendar(ServiceDetail detail, AppLocalizations l) {
    if (detail.attendanceDays.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('7-Day Attendance',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (widget.service.deploymentIds.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                      context, '/attendance-history',
                      arguments: widget.service.deploymentIds.first),
                  child: const Text('View All'),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: detail.attendanceDays.map((day) {
              Color dotColor;
              switch (day.status) {
                case 'on_time':
                  dotColor = HousepitalColors.success;
                  break;
                case 'replacement':
                  dotColor = HousepitalColors.warning;
                  break;
                case 'absent':
                case 'late':
                  dotColor = HousepitalColors.error;
                  break;
                default:
                  dotColor = Colors.grey[300]!;
              }
              final isToday = _isToday(day.date);
              return Column(
                children: [
                  Text(DateHelper.formatDateShort(day.date),
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday ? Colors.grey[400] : dotColor,
                      border: isToday
                          ? Border.all(color: HousepitalColors.orange, width: 2)
                          : null,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsLink(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('medications'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/medication-schedule'),
                  icon: const Icon(Icons.schedule),
                  label: Text(l.t('medication_schedule')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/medications'),
                  icon: const Icon(Icons.medication),
                  label: Text(l.t('medications')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceBilling(AppLocalizations l) {
    final s = widget.service;
    if (s.totalPaid == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('billing_summary'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _billingRow('Package Paid',
                      DateHelper.formatCurrency(s.totalPaid!)),
                  _billingRow('Consumed',
                      DateHelper.formatCurrency(s.totalConsumed ?? 0)),
                  _billingRow('Remaining',
                      DateHelper.formatCurrency(s.remaining ?? 0)),
                  if (s.renewalDate != null)
                    _billingRow(
                        'Renewal', DateHelper.formatDate(s.renewalDate!)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
