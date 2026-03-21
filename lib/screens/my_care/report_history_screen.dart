import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class ReportHistoryScreen extends StatefulWidget {
  final String deploymentId;

  const ReportHistoryScreen({super.key, required this.deploymentId});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  List<DailyReport> _reports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final app = context.read<AppProvider>();
      final patientId = app.currentPatient?.id;
      if (patientId != null) {
        _reports = await app.apiService.getReportHistory(patientId);
      }
    } catch (e) {
      _error = 'Failed to load reports';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('report_history'))),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l.t('error_load_data')),
                      TextButton(
                          onPressed: _loadReports,
                          child: Text(l.t('tap_to_retry'))),
                    ],
                  ),
                )
              : _reports.isEmpty
                  ? Center(child: Text(l.t('no_data')))
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                  DateHelper.formatDate(report.date)),
                              subtitle: Text(
                                  '${report.completedTasks} tasks completed'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pushNamed(
                                  context, '/report-detail',
                                  arguments: report.id),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
