import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/paginated_list.dart';

class ReportHistoryScreen extends StatefulWidget {
  final String deploymentId;

  const ReportHistoryScreen({super.key, required this.deploymentId});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final app = context.read<AppProvider>();
    final patientId = app.currentPatient?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(l.t('report_history'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: PaginatedListView<DailyReport>(
          pageSize: 20,
          fetchPage: (page, pageSize) =>
              app.apiService.getReportHistoryPaginated(
            patientId,
            page: page,
            pageSize: pageSize,
          ),
          itemBuilder: (report) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(DateHelper.formatDate(report.date)),
              subtitle: Text('${report.completedTasks} tasks completed'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(
                  context, '/report-detail',
                  arguments: report.id),
            ),
          ),
          emptyWidget: Center(child: Text(l.t('no_data'))),
        ),
      ),
    );
  }
}
