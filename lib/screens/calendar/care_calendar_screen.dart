// lib/screens/calendar/care_calendar_screen.dart
//
// CARE CALENDAR — one place to see staff attendance, medicine adherence and
// upcoming visits/tests/renewals, day by day.
//
// All event data comes from the pure `eventsFor()` aggregator in
// lib/models/care_event.dart (deterministic, demo-seeded — no Random()).
// "Today" is simply DateTime.now().

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/theme.dart';
import '../../data/demo_data.dart';
import '../../models/care_event.dart';
import '../../models/medication_models.dart';
import '../../providers/app_provider.dart';
import '../../providers/medication_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/day_part_header.dart';
import '../../widgets/empty_state.dart';
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

  // Patient-side staff attendance confirmations, keyed '<staffId>|<yyyy-MM-dd>'
  // (demo session state — mirrors the dose Mark-taken pattern).
  final Set<String> _staffMarked = {};

  // Future-day "N doses scheduled" card expansion (reset when the selected
  // day changes so each day starts collapsed).
  bool _futureMedsExpanded = false;

  // Legend teaching sentence ("A dot marks a day with events — tap to see")
  // shows only until the first day-tap — once the user has tapped a day they
  // have learnt the interaction (session state, no persistence needed).
  bool _hasTappedDay = false;

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
      // Day selection may change below — collapse the future-doses card.
      _futureMedsExpanded = false;
      switch (_view) {
        case _CalView.month:
          _visibleMonth = DateTime(
            _visibleMonth.year,
            _visibleMonth.month + delta,
            1,
          );
        case _CalView.week:
          _selected = DateTime(
            _selected.year,
            _selected.month,
            _selected.day + 7 * delta,
          );
          _visibleMonth = DateTime(_selected.year, _selected.month, 1);
        case _CalView.day:
          _selected = DateTime(
            _selected.year,
            _selected.month,
            _selected.day + delta,
          );
          _visibleMonth = DateTime(_selected.year, _selected.month, 1);
      }
    });
  }

  void _goToToday() {
    setState(() {
      _selected = _today;
      _futureMedsExpanded = false;
      _visibleMonth = DateTime(_selected.year, _selected.month, 1);
    });
  }

  void _selectDay(DateTime date) {
    setState(() {
      _selected = dateOnly(date);
      _futureMedsExpanded = false;
      _hasTappedDay = true;
      _visibleMonth = DateTime(date.year, date.month, 1);
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Glass idiom: content glides under the translucent app bar (matches
      // Care Team / My Care / Billing).
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('Care Calendar')),
      // Builder: resolve MediaQuery from a context BELOW the Scaffold so the
      // scroll padding sees the body's actual insets.
      body: Builder(
        builder: (context) {
          // At narrow widths (≤320 class) the 7-column grid needs slimmer
          // gutters so day cells stay near the 44pt tap-target minimum.
          final narrow = MediaQuery.of(context).size.width < 360;
          final gridHPad = narrow ? 8.0 : 16.0;
          return ListView(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            children: [
              // Selected day + date FIRST — the question the screen answers.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  DateFormat('EEEE, d MMMM').format(_selected),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.hc.black,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _segmentedControl(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _headerRow(),
              ),
              if (_view == _CalView.month) ...[
                // Weekday header shares the grid's gutter so columns align.
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gridHPad),
                  child: _weekdayHeaderRow(),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gridHPad),
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
                  padding: EdgeInsets.symmetric(horizontal: gridHPad),
                  child: _weekStrip(),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _legend(),
                ),
              ],
              const SizedBox(height: 12),
              // Day-detail transition: switching days used to jump-cut the
              // detail sections. Now the column cross-fades with a slight
              // upward settle (220ms easeOut), keyed by the selected date,
              // inside AnimatedSize so height changes glide too. Same-day
              // updates (e.g. marking a dose) keep the same key and rebuild
              // in place — no spurious transition. The detail stays in this
              // ListView, so scroll position is untouched.
              _animatedDetail(context),
            ],
          );
        },
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
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
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
    final title = DateFormat(
      'MMMM yyyy',
    ).format(_view == _CalView.month ? _visibleMonth : _selected);
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            'Today',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
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
          .map(
            (d) => Expanded(
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
            ),
          )
          .toList(),
    );
  }

  Widget _monthGrid() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final lead = first.weekday - 1; // Monday-first grid.
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
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
        final date = DateTime(
          _visibleMonth.year,
          _visibleMonth.month,
          i - lead + 1,
        );
        final dimmed = date.month != _visibleMonth.month;
        return _dayCell(date, dimmed: dimmed);
      },
    );
  }

  /// Spoken category name per event type for the day-cell Semantics label.
  String _typeName(CareEventType t) {
    switch (t) {
      case CareEventType.meds:
        return 'medicines';
      case CareEventType.staff:
        return 'staff';
      case CareEventType.visit:
        return 'doctor visit';
      case CareEventType.test:
        return 'test';
      case CareEventType.renewal:
        return 'renewal';
    }
  }

  Widget _dayCell(DateTime date, {required bool dimmed}) {
    final isToday = _sameDay(date, _today);
    final isSelected = _sameDay(date, _selected);
    // All distinct categories for the day (Semantics names every one);
    // the visual shows up to 3 dots, in CareEventType order.
    final allTypes = eventsFor(date).map((e) => e.type).toSet().toList();
    final types = allTypes.take(3).toList();

    final Color numberColor;
    if (dimmed) {
      numberColor = context.hc.greyLight;
    } else if (isSelected) {
      numberColor = context.hc.orangeText;
    } else {
      numberColor = context.hc.black;
    }

    // SELECTED day: orange rounded-square outline (today is selected by
    // default, so it carries the outline on open). TODAY, when NOT
    // selected, keeps a subtle persistent marker — a filled orangeLight
    // circle behind the number — so "today" never gets lost while browsing.
    final BoxDecoration? numberDecoration;
    if (isSelected) {
      numberDecoration = BoxDecoration(
        color: context.hc.orangeLight,
        border: Border.all(color: HousepitalColors.orange, width: 1.5),
        borderRadius: BorderRadius.circular(9),
      );
    } else if (isToday && !dimmed) {
      numberDecoration = BoxDecoration(
        color: context.hc.orangeLight,
        shape: BoxShape.circle,
      );
    } else {
      numberDecoration = null;
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
        label:
            DateFormat('d MMMM').format(date) +
            (isToday ? ', today' : '') +
            (allTypes.isEmpty
                ? ''
                : ', has ${allTypes.map(_typeName).join(', ')}'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: numberDecoration,
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
                    .map(
                      (t) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dimmed
                              ? _typeColor(t).withValues(alpha: 0.35)
                              : _typeColor(t),
                        ),
                      ),
                    )
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
    final monday = DateTime(
      _selected.year,
      _selected.month,
      _selected.day - (_selected.weekday - 1),
    );
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
        // Teaching copy: only until the user taps a day for the first time —
        // after that the interaction is learnt and the line is noise.
        if (!_hasTappedDay) ...[
          Text(
            '● A dot marks a day with events — tap to see',
            style: TextStyle(fontSize: 12, color: context.hc.greyLight),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CareEventType.values.map((t) {
            final color = _typeColor(t);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
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

  /// Wraps [_detailSections] in the day-switch transition (see build()).
  /// Honors reduced motion: Duration.zero renders the new day immediately.
  Widget _animatedDetail(BuildContext context) {
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        // Top-aligned stack (default centers) so the outgoing day doesn't
        // float while the incoming one settles.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [...previousChildren, ?currentChild],
        ),
        child: Column(
          key: ValueKey<DateTime>(_selected),
          // ListView stretched these children; a Column defaults to center —
          // stretch keeps every card at full width during and after the swap.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _detailSections(),
        ),
      ),
    );
  }

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
        .where(
          (e) =>
              e.type == CareEventType.visit ||
              e.type == CareEventType.test ||
              e.type == CareEventType.renewal,
        )
        .toList();
    if (upcoming.isNotEmpty && !isPast) {
      widgets.add(const SectionHeader(title: 'Visits, tests & renewals'));
      for (final e in upcoming) {
        widgets.add(_padCard(_upcomingCard(e)));
      }
    }

    // TODAY also answers "what's coming?" — the next 7 days' visits, tests
    // and renewals in one list (previously only discoverable by tapping
    // future dot-days on the grid).
    if (isToday) {
      final week = <(DateTime, CareEvent)>[];
      for (var i = 1; i <= 7; i++) {
        final day = _today.add(Duration(days: i));
        for (final e in eventsFor(day)) {
          if (e.type == CareEventType.visit ||
              e.type == CareEventType.test ||
              e.type == CareEventType.renewal) {
            week.add((day, e));
          }
        }
      }
      if (week.isNotEmpty) {
        widgets.add(const SectionHeader(title: 'Upcoming this week'));
        widgets.add(
          _padCard(
            HousepitalCard(
              child: Column(
                children: [
                  for (final (day, e) in week)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Text(
                              DateFormat('EEE d').format(day),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.hc.orangeText,
                              ),
                            ),
                          ),
                          Icon(
                            _typeIcon(e.type),
                            size: 18,
                            color: _typeColor(e.type),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (e.subtitle != null)
                                  Text(
                                    e.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.hc.greyLight,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _padCard(Widget child) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: child);

  Widget _emptyCard() {
    return _padCard(
      const HousepitalEmptyState.compact(
        icon: Icons.event_available,
        title: 'A free day',
        body: 'No doses, visits or duties scheduled.',
      ),
    );
  }

  /// Per-staff line items (like the dose rows): name + role, with the day's
  /// attendance state. Today's unconfirmed staff get a 'Mark present' quick
  /// action (patient-side confirmation, demo state — kept per day).
  Widget _staffCard(CareEvent e) {
    final members = DemoData.icuServiceDetail.staffOnDuty;
    final isToday = _sameDay(_selected, _today);
    final isFuture = _selected.isAfter(_today);
    final dayKey = DateFormat('yyyy-MM-dd').format(_selected);
    final presentCount = isFuture
        ? 0
        : members
              .where(
                (m) => !isToday || _staffMarked.contains('${m.id}|$dayKey'),
              )
              .length;

    return HousepitalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconTile(icon: Icons.groups, color: context.hc.success),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isFuture
                      ? 'Scheduled staff'
                      : '$presentCount/${members.length} confirmed present',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...members.map((m) {
            final marked = _staffMarked.contains('${m.id}|$dayKey');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${m.role} · ${m.shiftType} shift',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.hc.greyLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isFuture)
                    StatusBadge(text: 'Scheduled', color: context.hc.greyLight)
                  else if (!isToday)
                    StatusBadge(
                      text: 'Present',
                      color: context.hc.success,
                      icon: Icons.check_circle,
                    )
                  else if (marked)
                    StatusBadge(
                      text: 'Present',
                      color: context.hc.success,
                      icon: Icons.check_circle,
                    )
                  else
                    Semantics(
                      label: 'Mark ${m.name} present',
                      button: true,
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _staffMarked.add('${m.id}|$dayKey')),
                        child: const Text('Mark present'),
                      ),
                    ),
                ],
              ),
            );
          }),
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
                icon: Icons.medication,
                color: HousepitalColors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.subtitle ?? e.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.hc.orangeText,
                ),
              ),
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
  /// FUTURE day — tappable: expands to the full scheduled-dose breakdown
  /// (grouped Morning/Afternoon/Evening) so "6 doses scheduled" is never a
  /// dead-end summary.
  Widget _futureMedsCard(CareEvent e) {
    final meds = context.watch<MedicationProvider>().activeMedications;
    final doses = <(String, MedicationFull)>[
      for (final med in meds)
        for (final slot in med.timeSlots) (slot, med),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    return Semantics(
      button: true,
      expanded: _futureMedsExpanded,
      child: HousepitalCard(
        onTap: () => setState(() => _futureMedsExpanded = !_futureMedsExpanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppIconTile(
                  icon: Icons.medication,
                  color: HousepitalColors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.subtitle ?? e.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                StatusBadge(
                  text: 'Scheduled',
                  color: context.hc.info,
                  icon: Icons.schedule,
                ),
                const SizedBox(width: 4),
                Icon(
                  _futureMedsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: context.hc.greyLight,
                ),
              ],
            ),
            if (_futureMedsExpanded)
              ..._doseGroups(doses).expand(
                (g) => [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: DayPartHeader(g.part),
                  ),
                  ...g.doses.map(
                    (d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              _formatSlot(d.$1),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.hc.greyLight,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${d.$2.name} ${d.$2.dosage}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
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
                icon: Icons.medication,
                color: HousepitalColors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Today's doses",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Quick cross-fade (150ms) so the count visibly ticks when a
              // dose is marked, rather than snapping between frames.
              AnimatedSwitcher(
                duration: MediaQuery.of(context).disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                child: Text(
                  '$takenCount/${doses.length} taken',
                  key: ValueKey(takenCount),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: takenCount == doses.length && doses.isNotEmpty
                        ? context.hc.success
                        : context.hc.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Doses grouped by time of day — matches how patients think about
          // medication routines (subah / dopahar / raat).
          ..._doseGroups(doses).expand(
            (g) => [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: DayPartHeader(g.part),
              ),
              ...g.doses.map((d) => _doseRow(medProv, d.$1, d.$2)),
            ],
          ),
        ],
      ),
    );
  }

  /// Partition sorted (slot, med) pairs into Morning (<12:00),
  /// Afternoon (12:00–16:59) and Evening (17:00+) groups; empty groups
  /// are omitted.
  List<({DayPart part, List<(String, MedicationFull)> doses})>
  _doseGroups(List<(String, MedicationFull)> doses) {
    int hourOf(String slot) => int.tryParse(slot.split(':').first) ?? 0;
    final morning = doses.where((d) => hourOf(d.$1) < 12).toList();
    final afternoon = doses
        .where((d) => hourOf(d.$1) >= 12 && hourOf(d.$1) < 17)
        .toList();
    final evening = doses.where((d) => hourOf(d.$1) >= 17).toList();
    return [
      if (morning.isNotEmpty) (part: DayPart.morning, doses: morning),
      if (afternoon.isNotEmpty) (part: DayPart.afternoon, doses: afternoon),
      if (evening.isNotEmpty) (part: DayPart.evening, doses: evening),
    ];
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
          // Mark-taken micro-ceremony: the button → badge swap gets a calm
          // 200ms scale+fade instead of a frameless rebuild. Keyed on the
          // taken-state so the switcher only fires on the actual transition.
          AnimatedSwitcher(
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: taken
                ? StatusBadge(
                    key: const ValueKey('dose-taken'),
                    text: 'Taken',
                    color: context.hc.success,
                    icon: Icons.check,
                  )
                // Compact pill, compliant tap target (doctor_advice_card
                // pattern): the visual stays small but the padded Material
                // tap target keeps the interactive area ≥ 44pt.
                : TextButton(
                    key: const ValueKey('dose-mark'),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      medProv.markDoseTakenToday(med.id, slot);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 32),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    child: const Text(
                      'Mark taken',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                Text(
                  e.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (e.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    e.subtitle!,
                    style: TextStyle(fontSize: 12, color: context.hc.grey),
                  ),
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
