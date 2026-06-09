// lib/screens/my_care/widgets/staff_attendance_section.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../models/my_care_models.dart';
import '../../../utils/app_localizations.dart';

class StaffAttendanceSection extends StatelessWidget {
  final List<ActiveService> services;

  const StaffAttendanceSection({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Aggregate staff status from all services that have staff
    final staffServices = services.where((s) => s.hasStaff).toList();
    if (staffServices.isEmpty) return const SizedBox.shrink();

    final totalStaff =
        staffServices.fold<int>(0, (sum, s) => sum + (s.totalStaff ?? 0));
    final checkedIn =
        staffServices.fold<int>(0, (sum, s) => sum + (s.checkedInStaff ?? 0));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.t('todays_staff'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(
                '$checkedIn/$totalStaff checked in',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: checkedIn == totalStaff
                      ? context.hc.success
                      : context.hc.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Summary card — detailed attendance is in ServiceDetailScreen
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    checkedIn == totalStaff
                        ? Icons.check_circle
                        : Icons.access_time,
                    color: checkedIn == totalStaff
                        ? context.hc.success
                        : context.hc.warning,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      checkedIn == totalStaff
                          ? l.t('all_staff_checked_in')
                          : l.t('staff_pending_checkin'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
