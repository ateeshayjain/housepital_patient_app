import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final String deploymentId;

  const AttendanceHistoryScreen({super.key, required this.deploymentId});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<Attendance> _records = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _records = await context.read<AppProvider>().apiService
          .getAttendanceHistoryPaginated(widget.deploymentId);
    } catch (e) {
      _error = 'Failed to load attendance';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('attendance_history'))),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l.t('error_load_data')),
                      TextButton(
                          onPressed: _loadData,
                          child: Text(l.t('tap_to_retry'))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final a = _records[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            AttendanceHelper.getStatusIcon(a.status),
                            color:
                                AttendanceHelper.getStatusColor(a.status),
                          ),
                          title: Text(a.checkInTime != null
                              ? DateHelper.formatDate(a.checkInTime!)
                              : 'No check-in'),
                          subtitle: Text(
                              '${a.status} · ${a.checkInTime != null ? "In: ${DateHelper.formatTime(a.checkInTime!)}" : ""} ${a.checkOutTime != null ? "· Out: ${DateHelper.formatTime(a.checkOutTime!)}" : ""}'),
                          trailing: StatusBadge(
                            text: a.status,
                            color:
                                AttendanceHelper.getStatusColor(a.status),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
