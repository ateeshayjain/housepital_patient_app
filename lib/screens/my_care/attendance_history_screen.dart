import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/paginated_list.dart';
import '../../widgets/glass.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final String deploymentId;

  const AttendanceHistoryScreen({super.key, required this.deploymentId});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final apiService = context.read<AppProvider>().apiService;

    return Scaffold(
      appBar: GlassAppBar(title: Text(l.t('attendance_history'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: PaginatedListView<Attendance>(
          pageSize: 30,
          fetchPage: (page, pageSize) =>
              apiService.getAttendanceHistoryPaginated(
            widget.deploymentId,
            page: page,
            pageSize: pageSize,
          ),
          itemBuilder: (a) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                AttendanceHelper.getStatusIcon(a.status),
                color: AttendanceHelper.getStatusColor(a.status),
              ),
              title: Text(a.checkInTime != null
                  ? DateHelper.formatDate(a.checkInTime!)
                  : 'No check-in'),
              subtitle: Text(
                  '${a.status} · ${a.checkInTime != null ? "In: ${DateHelper.formatTime(a.checkInTime!)}" : ""} ${a.checkOutTime != null ? "· Out: ${DateHelper.formatTime(a.checkOutTime!)}" : ""}'),
              trailing: StatusBadge(
                text: a.status,
                color: AttendanceHelper.getStatusColor(a.status),
              ),
            ),
          ),
          emptyWidget: Center(child: Text(l.t('no_data'))),
        ),
      ),
    );
  }
}
