import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/theme.dart';
import '../../models/my_care_models.dart';
import '../../providers/my_care_provider.dart';
import '../../providers/orders_provider.dart';
import '../../services/invoice_pdf_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import 'widgets/vitals_trend_grid.dart';
import 'widgets/care_report_section.dart';
import 'widgets/equipment_deployed_section.dart';
import '../../widgets/glass.dart';

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

    return Scaffold(
      // Liquid Glass: content glides under the translucent app bar; the hero
      // ribbon itself starts below the bar via the scrollable's top padding.
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(widget.service.name),
      ),
      body: myCare.isDetailLoading
          ? const LoadingWidget()
          : myCare.detailError != null
              ? ErrorRetryWidget(
                  message: l.t('error_load_data'),
                  onRetry: () {
                    if (widget.service.deploymentIds.isNotEmpty) {
                      myCare.loadServiceDetail(
                          widget.service.deploymentIds.first);
                    }
                  },
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
                    // top: clear the glass app bar so the ribbon starts
                    // below it; bottom: clear the home indicator.
                    padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top +
                            kToolbarHeight +
                            8,
                        bottom: 24 + MediaQuery.of(context).padding.bottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with progress
                        _buildHeader(),

                        // Staff on duty
                        if (widget.service.showStaff &&
                            myCare.selectedServiceDetail != null)
                          _buildStaffSection(myCare.selectedServiceDetail!, l),

                        // Verify Staff button (when staff checked in but not yet verified)
                        if (widget.service.showStaff &&
                            myCare.selectedServiceDetail != null &&
                            myCare.selectedServiceDetail!.staffOnDuty.any(
                                (s) => s.checkInTime != null))
                          _buildVerifyStaffButton(
                              myCare.selectedServiceDetail!),

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

                        // Invoice download + full service history
                        _buildRecordsActions(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    // This screen's ONE solid-orange hero ribbon — inset squircle-16, not a
    // full-bleed rectangle (the edge-to-edge banner butted against the glass
    // app bar and read as a stray alert strip). Brand orange, NOT the
    // service-category colour: care_package red made an ICU page read as an
    // emergency alert — red is reserved for SOS/error meaning.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: context.hc.orange,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // No service name here — the glass app bar already titles the
          // screen; repeating it large in the ribbon doubled the type scale
          // (owner field report: 'why is the font so large vs home?').
          // White-on-orange copy stays bold + ≥14px (owner decision).
          Text(
            'Started ${DateHelper.formatDate(widget.service.startDate)}',
            style: TextStyle(
                color: context.hc.onOrange.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  widget.service.isSessionBased
                      ? 'Session ${widget.service.consumedDays} of ${widget.service.totalDays}'
                      : 'Day ${widget.service.consumedDays} of ${widget.service.totalDays}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.hc.onOrange,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.service.dailyRate != null)
                Flexible(
                  child: Text(
                    '${DateHelper.formatCurrency(widget.service.dailyRate!)}/day',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: context.hc.onOrange.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widget.service.progressFraction,
              minHeight: 6,
              backgroundColor: Colors.white24,
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
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          // Standard card surface — green is reserved for good-STATUS only,
          // so avatars are the brand orange-tinted initials tile and the
          // shift duration is plain text; the single green presence is the
          // tiny checked-in status dot. Replacement keeps a warning tint.
          ...detail.staffOnDuty.map((staff) => Card(
                color:
                    staff.isReplacement ? context.hc.warningLight : null,
                child: ListTile(
                  // AppIconTile-style initials: orange @0.12 fill + orangeText
                  // (same grammar as the Home patient-switcher avatars).
                  leading: CircleAvatar(
                    backgroundColor: staff.isReplacement
                        ? context.hc.warning.withValues(alpha: 0.12)
                        : context.hc.orange.withValues(alpha: 0.12),
                    child: Text(
                      staff.name.split(' ').map((n) => n[0]).take(2).join(),
                      style: TextStyle(
                          color: staff.isReplacement
                              ? context.hc.warning
                              : context.hc.orangeText,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(staff.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.hc.black)),
                      ),
                      if (staff.isReplacement)
                        Flexible(
                          child: Text(' (Replacement)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: context.hc.warning)),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role as GREY subtext under the bold name — matches the
                      // Home health-team hierarchy (was unstyled, so it read at
                      // the same weight as the name).
                      Text('${staff.role} (${staff.shiftType})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: context.hc.grey)),
                      if (staff.checkInTime != null)
                        Row(
                          children: [
                            // Literal checked-in STATUS — the one green dot.
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.hc.success),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Checked in ${DateHelper.formatTime(staff.checkInTime!)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: context.hc.grey),
                              ),
                            ),
                          ],
                        ),
                    ],
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
                                  color: context.hc.black),
                            ),
                            Text('on shift',
                                style: TextStyle(
                                    fontSize: 11, color: context.hc.grey)),
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
              const Flexible(
                child: Text('7-Day Attendance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
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
                  dotColor = context.hc.success;
                  break;
                case 'replacement':
                  dotColor = context.hc.warning;
                  break;
                case 'absent':
                case 'late':
                  dotColor = context.hc.error;
                  break;
                default:
                  dotColor = context.hc.divider;
              }
              final isToday = _isToday(day.date);
              return Expanded(
                child: Column(
                children: [
                  Text(DateHelper.formatDateShort(day.date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: context.hc.greyLight)),
                  const SizedBox(height: 4),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday ? context.hc.greyLight : dotColor,
                      border: isToday
                          ? Border.all(color: HousepitalColors.orange, width: 2)
                          : null,
                    ),
                  ),
                ],
              ),
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
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          // Two equal-height tonal pills ('Schedule' not 'Today's Schedule'
          // so both stay single-line at 320px) — the outlined buttons used
          // to wrap to different heights and look mismatched.
          Row(
            children: [
              _actionPill(
                label: 'Schedule',
                icon: Icons.schedule,
                onPressed: () =>
                    Navigator.pushNamed(context, '/medication-schedule'),
              ),
              const SizedBox(width: 8),
              _actionPill(
                label: 'Medications',
                icon: Icons.medication,
                onPressed: () =>
                    Navigator.pushNamed(context, '/medications'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tonal stadium pill (doctor_advice_card grammar) at a fixed 44pt height
  /// so paired actions always render the same size. FittedBox(scaleDown)
  /// guards single-line labels at 320px.
  ButtonStyle _pillStyle(BuildContext context) => FilledButton.styleFrom(
        backgroundColor: context.hc.orangeLight,
        foregroundColor: context.hc.orangeText,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );

  Widget _actionPill({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: SizedBox(
        height: 44,
        child: FilledButton.tonalIcon(
          onPressed: onPressed,
          style: _pillStyle(context),
          icon: Icon(icon, size: 16),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1),
          ),
        ),
      ),
    );
  }

  /// Owner ask: download the invoice and the full service history from this
  /// screen directly, instead of hunting through Orders / 7-day attendance.
  Widget _buildRecordsActions() {
    final order = _findInvoiceOrder(context.watch<OrdersProvider>().orders);
    final hasHistory = widget.service.deploymentIds.isNotEmpty;
    // No matching order AND no deployment → nothing to offer; hide the row.
    if (order == null && !hasHistory) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Hidden (not disabled) when no order matches — an Invoice pill
          // that errors would be worse than no pill.
          if (order != null)
            _actionPill(
              label: 'Invoice (PDF)',
              icon: Icons.download,
              onPressed: () => _shareInvoice(order),
            ),
          if (order != null && hasHistory) const SizedBox(width: 8),
          if (hasHistory)
            _actionPill(
              label: 'Service history',
              icon: Icons.history,
              onPressed: () => Navigator.pushNamed(
                  context, '/attendance-history',
                  arguments: widget.service.deploymentIds.first),
            ),
        ],
      ),
    );
  }

  /// Best-effort match between this service and an order: an order whose
  /// item names overlap the service name wins; otherwise fall back to the
  /// first order that contains a service-type item. Null → no invoice pill.
  Map<String, dynamic>? _findInvoiceOrder(List<Map<String, dynamic>> orders) {
    final serviceName = widget.service.name.toLowerCase();
    for (final order in orders) {
      final items = (order['items'] as List?) ?? const [];
      for (final item in items) {
        final itemName =
            ((item as Map)['name'] as String? ?? '').toLowerCase();
        if (itemName.isEmpty) continue;
        if (itemName.contains(serviceName) ||
            serviceName.contains(itemName)) {
          return order;
        }
      }
    }
    for (final order in orders) {
      final items = (order['items'] as List?) ?? const [];
      if (items.any((i) => (i as Map)['isService'] == true)) return order;
    }
    return null;
  }

  Future<void> _shareInvoice(Map<String, dynamic> order) async {
    try {
      await InvoicePdfService().shareInvoice(order);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not generate the invoice — try again.'),
          backgroundColor: context.hc.error,
        ),
      );
    }
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
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: context.hc.grey)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
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

  Widget _buildVerifyStaffButton(ServiceDetail detail) {
    // Pick the first checked-in staff member for verification
    final checkedInStaff =
        detail.staffOnDuty.where((s) => s.checkInTime != null).first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, '/staff-otp', arguments: {
              'deploymentId': widget.service.deploymentIds.isNotEmpty
                  ? widget.service.deploymentIds.first
                  : '',
              'staffName': checkedInStaff.name,
              'staffRole': checkedInStaff.role,
              'staffPhotoUrl': checkedInStaff.photoUrl,
            });
          },
          icon: const Icon(Icons.verified_user, size: 20),
          label: const Text('Verify Staff'),
          // Standard orange primary — verification is an ACTION, not a
          // success state; green buttons broke the one-accent brand system.
        ),
      ),
    );
  }
}
