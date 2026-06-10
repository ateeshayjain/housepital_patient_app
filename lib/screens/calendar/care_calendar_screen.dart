// lib/screens/calendar/care_calendar_screen.dart
//
// CARE CALENDAR — one place to see staff attendance, medicine adherence and
// upcoming visits/tests/renewals, day by day.
//
// All event data comes from the pure `eventsFor()` aggregator in
// lib/models/care_event.dart (deterministic, demo-seeded — no Random()).
// "Today" is simply DateTime.now().

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/theme.dart';
import '../../models/care_event.dart';
import '../../models/medication_models.dart';
import '../../providers/app_provider.dart';
import '../../providers/medication_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass.dart';

/// Order matches the segmented control: [Day | Week | Month].
enum _CalView { day, week, month }

class CareCalendarScreen extends StatefulWidget {
  const CareCalendarScreen({super.key});

  @override
  State<CareCalendarScreen> createState() => _CareCalendarScreenState();
}

class _CareCalendarScreenState extends State<CareCalendarScreen> {
  _CalView _view = _CalView.month;
  late DateTime _selected;
  late DateTime _visibleMonth;

  static const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  DateTime get _today => dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _selected = _today;
    _visibleMonth = DateTime(_selected.year, _selected.month, 1);
    Future.microtask(() {
      if (!mounted) return;
      final patientId =
          context.read<AppProvider>().currentPatient?.id ?? 'pat_demo_rajesh';
      context.read<MedicationProvider>().loadMedications(patientId);
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color _typeColor(CareEventType t) {
    switch (t) {
      case CareEventType.meds:
        return HousepitalColors.orange;
      case CareEventType.staff:
        return context.hc.success;
      case CareEventType.visit:
        return context.hc.info;
      // Renewal/Test share the warning hue (approved reference legend).
      case CareEventType.test:
        return context.hc.warning;
      case CareEventType.renewal:
        return context.hc.warning;
    }
  }

  IconData _typeIcon(CareEventType t) {
    switch (t) {
      case CareEventType.meds:
        return Icons.medication;
      case CareEventType.staff:
        return Icons.groups;
      case CareEventType.visit:
        return Icons.medical_services;
      case CareEventType.test:
        return Icons.science;
      case CareEventType.renewal:
        return Icons.autorenew;
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _step(int delta) {
    setState(() {
      switch (_view) {
        case _CalView.month:
          _visibleMonth =
              DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
        case _CalView.week:
          _selected = DateTime(
              _selected.year, _selected.month, _selected.day + 7 * delta);
          _visibleMonth = DateTime(_selected.year, _selected.month, 1);
        case _CalView.day:
          _selected =
              DateTime(_selected.year, _selected.month, _selected.day + delta);
          _visibleMonth = DateTime(_selected.year, _selected.month, 1);
      }
    });
  }

  void _goToToday() {
    setState(() {
      _selected = _today;
      _visibleMonth = DateTime(_selected.year, _selected.month, 1);
    });
  }

  void _selectDay(DateTime date) {
    setState(() {
      _selected = dateOnly(date);
      _visibleMonth = DateTime(date.year, date.month, 1);
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: Text('Care Calendar')),
      body: ListView(
        padding: EdgeInsets.only(
            top: 8, bottom: MediaQuery.of(context).padding.bottom + 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _segmentedControl(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _headerRow(),
          ),
          if (_view == _CalView.month) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _weekdayHeaderRow(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _monthGrid(),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _legend(),
            ),
          ] else if (_view == _CalView.week) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _weekStrip(),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _legend(),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              DateFormat('EEEE, d MMMM').format(_selected),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.hc.black,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ..._detailSections(),
        ],
      ),
    );
  }

  // ── Segmented control (hand-rolled pill) ────────────────────────────────

  Widget _segmentedControl() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.hc.greyLighter,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: _CalView.values.map((v) {
          final selected = v == _view;
          final label = switch (v) {
            _CalView.day => 'Day',
            _CalView.week => 'Week',
            _CalView.month => 'Month',
          };
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label: '$label view',
              child: GestureDetector(
                onTap: () => setState(() => _view = v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  decoration: selected
                      ? BoxDecoration(
                          color: context.hc.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        )
                      : null,
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? context.hc.black : context.hc.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Month header row ────────────────────────────────────────────────────

  Widget _headerRow() {
    final title = DateFormat('MMMM yyyy')
        .format(_view == _CalView.month ? _visibleMonth : _selected);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.hc.black,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous',
          color: context.hc.grey,
          onPressed: () => _step(-1),
        ),
        TextButton(
          onPressed: _goToToday,
          style: TextButton.styleFrom(
            foregroundColor: context.hc.orangeText,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Today',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next',
          color: context.hc.grey,
          onPressed: () => _step(1),
        ),
      ],
    );
  }

  // ── Month grid ──────────────────────────────────────────────────────────

  Widget _weekdayHeaderRow() {
    return Row(
      children: _weekdayLetters
          .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.hc.greyLight,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _monthGrid() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final lead = first.weekday - 1; // Monday-first grid.
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final totalCells = ((lead + daysInMonth) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.82,
      ),
      itemCount: totalCells,
      itemBuilder: (context, i) {
        final date =
            DateTime(_visibleMonth.year, _visibleMonth.month, i - lead + 1);
        final dimmed = date.month != _visibleMonth.month;
        return _dayCell(date, dimmed: dimmed);
      },
    );
  }

  Widget _dayCell(DateTime date, {required bool dimmed}) {
    final isToday = _sameDay(date, _today);
    final isSelected = _sameDay(date, _selected);
    // Up to 3 dots, one per distinct category, in CareEventType order.
    final types =
        eventsFor(date).map((e) => e.type).toSet().take(3).toList();

    final Color numberColor;
    if (dimmed) {
      numberColor = context.hc.greyLight;
    } else if (isSelected) {
      numberColor = context.hc.orangeText;
    } else {
      numberColor = context.hc.black;
    }

    return InkWell(
      key: dimmed
          ? null
          : ValueKey('cal-day-${date.year}-${date.month}-${date.day}'),
      onTap: () => _selectDay(date),
      borderRadius: BorderRadius.circular(10),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: DateFormat('d MMMM').format(date) +
            (types.isEmpty ? '' : ', has events'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isSelected ? context.hc.orangeLight : null,
                // SELECTED day: orange rounded-square outline (today is
                // selected by default, so it carries the outline on open).
                border: isSelected
                    ? Border.all(color: HousepitalColors.orange, width: 1.5)
                    : null,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: numberColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: types
                    .map((t) => Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dimmed
                                ? _typeColor(t).withValues(alpha: 0.35)
                                : _typeColor(t),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Week strip ──────────────────────────────────────────────────────────

  Widget _weekStrip() {
    final monday = DateTime(_selected.year, _selected.month,
        _selected.day - (_selected.weekday - 1));
    return Row(
      children: List.generate(7, (i) {
        final date = DateTime(monday.year, monday.month, monday.day + i);
        return Expanded(
          child: Column(
            children: [
              Text(
                _weekdayLetters[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.hc.greyLight,
                ),
              ),
              const SizedBox(height: 4),
              _dayCell(date, dimmed: false),
            ],
          ),
        );
      }),
    );
  }

  // ── Legend ──────────────────────────────────────────────────────────────

  Widget _legend() {
    const labels = {
      CareEventType.meds: 'Meds',
      CareEventType.staff: 'Staff',
      CareEventType.visit: 'Visit',
      CareEventType.test: 'Test',
      CareEventType.renewal: 'Renewal',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '● A dot marks a day with events — tap to see',
          style: TextStyle(fontSize: 12, color: context.hc.greyLight),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CareEventType.values.map((t) {
            final color = _typeColor(t);
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: color),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labels[t]!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Selected-day detail ─────────────────────────────────────────────────

  List<Widget> _detailSections() {
    final events = eventsFor(_selected);
    final isPast = _selected.isBefore(_today);
    final isToday = _sameDay(_selected, _today);

    if (events.isEmpty) return [_emptyCard()];

    final widgets = <Widget>[];

    final staff = events.where((e) => e.type == CareEventType.staff).toList();
    if (staff.isNotEmpty) {
      widgets.add(const SectionHeader(title: 'Staff attendance'));
      widgets.add(_padCard(_staffCard(staff.first)));
    }

    final meds = events.where((e) => e.type == CareEventType.meds).toList();
    if (meds.isNotEmpty) {
      widgets.add(const SectionHeader(title: 'Medicine adherence'));
      if (isToday) {
        widgets.add(_padCard(_todayMedsCard()));
      } else if (isPast) {
        widgets.add(_padCard(_pastMedsCard(meds.first)));
      } else {
        widgets.add(_padCard(_futureMedsCard(meds.first)));
      }
    }

    final upcoming = events
        .where((e) =>
            e.type == CareEventType.visit ||
            e.type == CareEventType.test ||
            e.type == CareEventType.renewal)
        .toList();
    if (upcoming.isNotEmpty && !isPast) {
      widgets.add(const SectionHeader(title: 'Visits, tests & renewals'));
      for (final e in upcoming) {
        widgets.add(_padCard(_upcomingCard(e)));
      }
    }

    return widgets;
  }

  Widget _padCard(Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: child,
      );

  Widget _emptyCard() {
    return _padCard(
      HousepitalCard(
        child: Row(
          children: [
            Icon(Icons.event_available, size: 22, color: context.hc.greyLight),
            const SizedBox(width: 12),
            Text(
              'Nothing scheduled',
              style: TextStyle(fontSize: 14, color: context.hc.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _staffCard(CareEvent e) {
    return HousepitalCard(
      child: Row(
        children: [
          AppIconTile(icon: _typeIcon(e.type), color: context.hc.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (e.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(e.subtitle!,
                      style:
                          TextStyle(fontSize: 12, color: context.hc.grey)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(
            text: 'Present',
            color: context.hc.success,
            icon: Icons.check_circle,
          ),
        ],
      ),
    );
  }

  /// PAST day — deterministic demo adherence + progress bar.
  Widget _pastMedsCard(CareEvent e) {
    final pct = adherencePercentFor(_selected);
    return HousepitalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconTile(
                  icon: Icons.medication, color: HousepitalColors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(e.subtitle ?? e.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Text('$pct%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.hc.orangeText,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              color: HousepitalColors.orange,
              backgroundColor: context.hc.greyLighter,
            ),
          ),
        ],
      ),
    );
  }

  /// FUTURE day — scheduled dose count only.
  Widget _futureMedsCard(CareEvent e) {
    return HousepitalCard(
      child: Row(
        children: [
          const AppIconTile(
              icon: Icons.medication, color: HousepitalColors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(e.subtitle ?? e.title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          StatusBadge(
            text: 'Scheduled',
            color: context.hc.info,
            icon: Icons.schedule,
          ),
        ],
      ),
    );
  }

  /// TODAY — actual dose slots with per-dose "Mark taken" quick actions.
  /// Shares mark-taken state with the rest of the app via MedicationProvider.
  Widget _todayMedsCard() {
    final medProv = context.watch<MedicationProvider>();
    final meds = medProv.activeMedications;

    // (timeSlot, medication) pairs sorted by time.
    final doses = <(String, MedicationFull)>[
      for (final med in meds)
        for (final slot in med.timeSlots) (slot, med),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final takenCount = doses
        .where((d) => medProv.isDoseTakenToday(d.$2.id, d.$1))
        .length;

    return HousepitalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconTile(
                  icon: Icons.medication, color: HousepitalColors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text("Today's doses",
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Text('$takenCount/${doses.length} taken',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: takenCount == doses.length && doses.isNotEmpty
                        ? context.hc.success
                        : context.hc.grey,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          ...doses.map((d) => _doseRow(medProv, d.$1, d.$2)),
        ],
      ),
    );
  }

  Widget _doseRow(MedicationProvider medProv, String slot, MedicationFull med) {
    final taken = medProv.isDoseTakenToday(med.id, slot);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              _formatSlot(slot),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.hc.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${med.name} ${med.dosage}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.hc.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (taken)
            StatusBadge(
              text: 'Taken',
              color: context.hc.success,
              icon: Icons.check,
            )
          else
            SizedBox(
              height: 32,
              child: TextButton(
                onPressed: () => medProv.markDoseTakenToday(med.id, slot),
                style: TextButton.styleFrom(
                  foregroundColor: context.hc.orangeText,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('Mark taken',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _upcomingCard(CareEvent e) {
    final color = _typeColor(e.type);
    return HousepitalCard(
      child: Row(
        children: [
          AppIconTile(icon: _typeIcon(e.type), color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (e.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(e.subtitle!,
                      style:
                          TextStyle(fontSize: 12, color: context.hc.grey)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(text: 'Upcoming', color: color),
        ],
      ),
    );
  }

  String _formatSlot(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? parts[1] : '00';
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:$minute $period';
  }
}
