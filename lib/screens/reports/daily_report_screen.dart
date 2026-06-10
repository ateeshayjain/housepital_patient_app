import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass.dart';

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
      appBar: GlassAppBar(
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
                      // Summary header card — completion ring + staff + time
                      _buildSummaryHeader(),
                      const SizedBox(height: 16),

                      // Sections (each in its own card)
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
                                    color: context.hc.greyLighter,
                                    child: Icon(Icons.image,
                                        color: context.hc.greyLight),
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
                            style: TextStyle(
                              fontSize: 14,
                              color: context.hc.grey,
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
                          icon: Icon(Icons.warning_amber,
                              color: context.hc.warning),
                          label: Text(
                            l.t('raise_concern'),
                            style: TextStyle(
                                color: context.hc.warning),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // Summary header — the visual anchor: completion ring, staff, submit time.
  Widget _buildSummaryHeader() {
    final r = _report!;
    final frac = r.totalTasks > 0 ? r.completedTasks / r.totalTasks : 0.0;
    final allDone = r.completedTasks == r.totalTasks && r.totalTasks > 0;
    final ringColor = allDone
        ? context.hc.success
        : frac >= 0.5
            ? context.hc.warning
            : context.hc.error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HousepitalColors.orange,
            HousepitalColors.orange.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: frac,
                    strokeWidth: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                Text('${r.completedTasks}/${r.totalTasks}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allDone
                      ? 'All tasks completed'
                      : '${r.completedTasks} of ${r.totalTasks} tasks done',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        r.staffName ?? 'Care staff',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                if (r.submittedAt != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        'Submitted ${DateHelper.formatTime(r.submittedAt!)}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // a tiny accent reflecting overall health of the day
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(left: 8),
            decoration:
                BoxDecoration(color: ringColor, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(ReportSection section, AppLocalizations l) {
    Color sectionColor;
    String sectionStatus;
    switch (section.status) {
      case 'done':
        sectionColor = context.hc.success;
        sectionStatus = l.t('done');
        break;
      case 'partial':
        sectionColor = context.hc.warning;
        sectionStatus = l.t('partial');
        break;
      default:
        sectionColor = context.hc.greyLight;
        sectionStatus = l.t('pending');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.hc.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hc.divider),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status-coloured accent stripe down the left edge.
            Container(width: 4, color: sectionColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            section.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.hc.black,
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
                          ? context.hc.success
                          : task.skipped
                              ? context.hc.error
                              : context.hc.greyLight,
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
                                      ? context.hc.greyLight
                                      : context.hc.black,
                                  decoration: task.skipped
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (task.completedAt != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  task.completedAt!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.hc.greyLight,
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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.hc.greyLight,
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
              ),
            ),
          ],
        ),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.hc.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hc.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
          children: [
            const Icon(Icons.medication,
                size: 20, color: HousepitalColors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Medication Adherence',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.hc.black,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: takenCount == totalCount
                    ? context.hc.successLight
                    : context.hc.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$takenCount/$totalCount taken',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: takenCount == totalCount
                      ? context.hc.success
                      : context.hc.warning,
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
                        size: 16, color: context.hc.greyLight),
                    const SizedBox(width: 6),
                    Text(
                      timingLabel(entry.key),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.hc.grey,
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
                                ? context.hc.success
                                : context.hc.greyLight,
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
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.hc.black,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      med.dosage,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            context.hc.greyLight,
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
                                                BorderRadius.circular(8),
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
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.hc.greyLight,
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
      ),
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
