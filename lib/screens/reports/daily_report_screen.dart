import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class DailyReportScreen extends StatefulWidget {
  final String reportId;
  const DailyReportScreen({super.key, required this.reportId});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  DailyReport? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final report = await ApiService().getReportDetail(widget.reportId);
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading report: $e');
      // Mock data for preview
      _report = DailyReport.fromJson({
        'id': widget.reportId,
        'deployment_id': 'dep_001',
        'staff_id': 'staff_001',
        'staff_name': 'Priya Mehra',
        'date': DateTime.now().toIso8601String(),
        'submitted_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        'completed_tasks': 5,
        'total_tasks': 8,
        'staff_notes': 'Patient had a good day. Appetite is improving. Walked for 10 minutes in the evening with assistance.',
        'sections': [
          {
            'name': 'Morning Routine',
            'status': 'done',
            'tasks': [
              {'name': 'Sponge bath', 'completed': true, 'completed_at': '7:30 AM'},
              {'name': 'Medication administered', 'completed': true, 'completed_at': '8:00 AM', 'notes': 'Gave Metformin 500mg after breakfast'},
              {'name': 'Breakfast assisted', 'completed': true, 'completed_at': '8:30 AM'},
            ],
          },
          {
            'name': 'Afternoon Care',
            'status': 'partial',
            'tasks': [
              {'name': 'Vitals check', 'completed': true, 'completed_at': '1:00 PM'},
              {'name': 'Physiotherapy exercises', 'completed': true, 'completed_at': '2:30 PM', 'notes': 'Completed 15 min leg exercises'},
              {'name': 'Wound dressing change', 'completed': false},
            ],
          },
          {
            'name': 'Evening Routine',
            'status': 'pending',
            'tasks': [
              {'name': 'Evening medication', 'completed': false},
              {'name': 'Dinner assistance', 'completed': false},
            ],
          },
        ],
        'medications': [
          {'id': 'med1', 'name': 'Metformin', 'dosage': '500mg', 'timing': 'morning', 'taken': true, 'taken_at': '8:00 AM', 'taken_by': 'staff'},
          {'id': 'med2', 'name': 'Amlodipine', 'dosage': '5mg', 'timing': 'morning', 'taken': true, 'taken_at': '8:00 AM', 'taken_by': 'staff'},
          {'id': 'med3', 'name': 'Pantoprazole', 'dosage': '40mg', 'timing': 'morning', 'taken': true, 'taken_at': '7:45 AM', 'taken_by': 'patient', 'notes': 'Taken before breakfast'},
          {'id': 'med4', 'name': 'Metformin', 'dosage': '500mg', 'timing': 'evening', 'taken': false},
          {'id': 'med5', 'name': 'Calcium + Vitamin D', 'dosage': '1 tab', 'timing': 'afternoon', 'taken': true, 'taken_at': '1:30 PM', 'taken_by': 'staff'},
          {'id': 'med6', 'name': 'Multivitamin', 'dosage': '1 tab', 'timing': 'afternoon', 'taken': false},
        ],
      });
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_report != null
            ? '${l.t("todays_report")} — ${DateHelper.formatDate(_report!.date)}'
            : l.t('todays_report')),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _report == null
              ? ErrorRetryWidget(
                  message: l.t('error_occurred'),
                  onRetry: _loadReport,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Staff info
                      Row(
                        children: [
                          Text(
                            'Staff: ${_report!.staffName ?? ""}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: HousepitalColors.grey,
                            ),
                          ),
                          const Spacer(),
                          if (_report!.submittedAt != null)
                            Text(
                              'Submitted at ${DateHelper.formatTime(_report!.submittedAt!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: HousepitalColors.greyLight,
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Sections
                      ..._report!.sections.map((section) => _buildSection(section, l)),

                      // Medication Adherence
                      if (_report!.medications != null &&
                          _report!.medications!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildMedicationSection(l),
                      ],

                      // Photos
                      if (_report!.photoUrls != null &&
                          _report!.photoUrls!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SectionHeader(
                          title:
                              '${l.t("photos")} (${_report!.photoUrls!.length})',
                          actionText: l.t('view_all'),
                        ),
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _report!.photoUrls!.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _report!.photoUrls![index],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  semanticLabel:
                                      'Daily report photo ${index + 1} of ${_report!.photoUrls!.length}',
                                  errorBuilder: (_, _, _) => Container(
                                    width: 100,
                                    height: 100,
                                    color: HousepitalColors.greyLighter,
                                    child: const Icon(Icons.image,
                                        color: HousepitalColors.greyLight),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Staff notes
                      if (_report!.staffNotes != null &&
                          _report!.staffNotes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SectionHeader(title: l.t('staff_notes')),
                        HousepitalCard(
                          child: Text(
                            _report!.staffNotes!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: HousepitalColors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],

                      // Rate care
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showRatingDialog(context),
                          icon: const Icon(Icons.star_outline),
                          label: Text(l.t('rate_care')),
                        ),
                      ),

                      // Raise concern
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/raise-concern'),
                          icon: const Icon(Icons.warning_amber,
                              color: HousepitalColors.warning),
                          label: Text(
                            l.t('raise_concern'),
                            style: const TextStyle(
                                color: HousepitalColors.warning),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSection(ReportSection section, AppLocalizations l) {
    Color sectionColor;
    String sectionStatus;
    switch (section.status) {
      case 'done':
        sectionColor = HousepitalColors.success;
        sectionStatus = l.t('done');
        break;
      case 'partial':
        sectionColor = HousepitalColors.warning;
        sectionStatus = l.t('partial');
        break;
      default:
        sectionColor = HousepitalColors.greyLight;
        sectionStatus = l.t('pending');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  section.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.black,
                  ),
                ),
              ),
              StatusBadge(text: sectionStatus, color: sectionColor),
            ],
          ),
          const SizedBox(height: 8),
          ...section.tasks.map((task) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      task.completed
                          ? Icons.check_circle
                          : task.skipped
                              ? Icons.cancel
                              : Icons.radio_button_unchecked,
                      size: 18,
                      color: task.completed
                          ? HousepitalColors.success
                          : task.skipped
                              ? HousepitalColors.error
                              : HousepitalColors.greyLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                task.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: task.skipped
                                      ? HousepitalColors.greyLight
                                      : HousepitalColors.black,
                                  decoration: task.skipped
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (task.completedAt != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  task.completedAt!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: HousepitalColors.greyLight,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (task.notes != null && task.notes!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '"${task.notes}"',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: HousepitalColors.greyLight,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Medication Adherence Section
  // ---------------------------------------------------------------------------
  Widget _buildMedicationSection(AppLocalizations l) {
    final meds = _report!.medications!;
    final takenCount = meds.where((m) => m.taken).length;
    final totalCount = meds.length;

    // Group by timing
    final timings = ['morning', 'afternoon', 'evening', 'night'];
    final grouped = <String, List<MedicationEntry>>{};
    for (final timing in timings) {
      final items = meds.where((m) => m.timing == timing).toList();
      if (items.isNotEmpty) grouped[timing] = items;
    }

    String timingLabel(String timing) {
      switch (timing) {
        case 'morning':
          return 'Morning';
        case 'afternoon':
          return 'Afternoon';
        case 'evening':
          return 'Evening';
        case 'night':
          return 'Night';
        default:
          return timing;
      }
    }

    IconData timingIcon(String timing) {
      switch (timing) {
        case 'morning':
          return Icons.wb_sunny;
        case 'afternoon':
          return Icons.wb_cloudy;
        case 'evening':
          return Icons.wb_twilight;
        case 'night':
          return Icons.nightlight_round;
        default:
          return Icons.schedule;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.medication,
                size: 20, color: HousepitalColors.orange),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Medication Adherence',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.black,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: takenCount == totalCount
                    ? HousepitalColors.successLight
                    : HousepitalColors.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$takenCount/$totalCount taken',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: takenCount == totalCount
                      ? HousepitalColors.success
                      : HousepitalColors.warning,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...grouped.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(timingIcon(entry.key),
                        size: 16, color: HousepitalColors.greyLight),
                    const SizedBox(width: 6),
                    Text(
                      timingLabel(entry.key),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: HousepitalColors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...entry.value.map((med) => Padding(
                      padding: const EdgeInsets.only(left: 22, bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            med.taken
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: med.taken
                                ? HousepitalColors.success
                                : HousepitalColors.greyLight,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      med.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: HousepitalColors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      med.dosage,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color:
                                            HousepitalColors.greyLight,
                                      ),
                                    ),
                                  ],
                                ),
                                if (med.taken && med.takenAt != null)
                                  Row(
                                    children: [
                                      Text(
                                        med.takenAt!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: HousepitalColors
                                              .greyLight,
                                        ),
                                      ),
                                      if (med.takenBy != null) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 1),
                                          decoration: BoxDecoration(
                                            color: med.takenBy == 'staff'
                                                ? HousepitalColors
                                                    .infoLight
                                                : HousepitalColors
                                                    .orangeLight,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            med.takenBy == 'staff'
                                                ? 'By Staff'
                                                : 'Self',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  med.takenBy == 'staff'
                                                      ? HousepitalColors
                                                          .info
                                                      : HousepitalColors
                                                          .orangeText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                if (med.notes != null &&
                                    med.notes!.isNotEmpty)
                                  Text(
                                    med.notes!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: HousepitalColors.greyLight,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 4),
              ],
            )),
      ],
    );
  }

  void _showRatingDialog(BuildContext context) {
    int selectedRating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate Today\'s Care'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final emojis = ['\u{1F61F}', '\u{1F610}', '\u{1F642}', '\u{1F60A}', '\u{1F929}'];
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedRating = index + 1),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        emojis[index],
                        style: TextStyle(
                          fontSize: selectedRating == index + 1 ? 36 : 28,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Optional feedback...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedRating > 0
                  ? () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rating submitted!')),
                      );
                    }
                  : null,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
