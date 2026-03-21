// lib/screens/my_care/widgets/care_report_section.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/my_care_models.dart';
import '../../../utils/app_localizations.dart';

class CareReportSection extends StatelessWidget {
  final CareReportSummary report;
  final String deploymentId;

  const CareReportSection({
    super.key,
    required this.report,
    required this.deploymentId,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final percent = (report.completionFraction * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l.t('todays_care_report'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${report.completedTasks}/${report.totalTasks} tasks, $percent%',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.orange),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ...report.tasks.map((task) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              task.status == 'completed'
                                  ? Icons.check_circle
                                  : task.status == 'in_progress'
                                      ? Icons.access_time
                                      : Icons.radio_button_unchecked,
                              size: 18,
                              color: task.status == 'completed'
                                  ? HousepitalColors.success
                                  : task.status == 'in_progress'
                                      ? HousepitalColors.orange
                                      : Colors.grey[400],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(task.name,
                                  style: const TextStyle(fontSize: 14)),
                            ),
                            if (task.completedAt != null)
                              Text(task.completedAt!,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      )),
                  if (report.staffNotes != null) ...[
                    const Divider(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.note, size: 16, color: HousepitalColors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(report.staffNotes!,
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(
                          context, '/report-history',
                          arguments: deploymentId),
                      child: Text(l.t('view_all_reports')),
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
