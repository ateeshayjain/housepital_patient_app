// lib/models/care_event.dart
//
// Care Calendar event model + the ONE pure aggregation helper that both the
// calendar grid (dots) and the selected-day detail sections derive from.
//
// Deliberately Flutter-free (pure Dart) so it is unit-testable. All values are
// DETERMINISTIC: no Random(), demo adherence is seeded off the calendar date.

import '../data/demo_data.dart';

/// Category of a calendar event. Order matters: it's the render order of the
/// per-day dots and of the detail sections.
///
/// `reminder` is the user-authored category (quick-add '+' on the calendar —
/// see RemindersProvider); it renders last so seeded care events keep their
/// long-standing dot order.
enum CareEventType { meds, staff, visit, test, renewal, reminder }

class CareEvent {
  final DateTime date;
  final CareEventType type;
  final String title;
  final String? subtitle;

  const CareEvent({
    required this.date,
    required this.type,
    required this.title,
    this.subtitle,
  });
}

/// Strips the time-of-day component.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Deterministic demo medicine-adherence percentage for a PAST day.
/// Seeded off the date itself (NO Random) so the same day always reports the
/// same number; range 80–100%.
int adherencePercentFor(DateTime day) =>
    80 + ((day.day * 7 + day.weekday * 3) % 21);

/// Average adherence over the 7 days ending [today] (inclusive) — used by the
/// medications screen "This week" header. Same seed → same number all session.
int weeklyAdherencePercent({DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  var sum = 0;
  for (var i = 0; i < 7; i++) {
    sum += adherencePercentFor(today.subtract(Duration(days: i)));
  }
  return (sum / 7).round();
}

/// Total scheduled dose slots per day across all active demo medications.
int dosesPerDay() => DemoData.medications
    .where((m) => m.isActive)
    .fold(0, (sum, m) => sum + m.timeSlots.length);

/// Pure helper: every care event that falls on [day].
///
/// [now] is injectable for tests; production callers omit it (defaults to
/// DateTime.now(), which is fine for a calendar's notion of "today").
List<CareEvent> eventsFor(DateTime day, {DateTime? now}) {
  final d = dateOnly(day);
  final today = dateOnly(now ?? DateTime.now());
  final events = <CareEvent>[];

  // ── Medicine adherence / schedule — every day meds are prescribed ──────
  final meds = DemoData.medications.where((m) => m.isActive).toList();
  if (meds.isNotEmpty) {
    final earliestPrescribed = meds
        .map((m) => dateOnly(m.prescribedDate ?? today))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    if (!d.isBefore(earliestPrescribed)) {
      final total = dosesPerDay();
      final String subtitle;
      if (d.isBefore(today)) {
        final taken = (total * adherencePercentFor(d) / 100).round();
        subtitle = '$taken of $total doses taken';
      } else {
        subtitle = '$total doses scheduled';
      }
      events.add(CareEvent(
        date: d,
        type: CareEventType.meds,
        title: 'Medicine adherence',
        subtitle: subtitle,
      ));
    }
  }

  // ── Staff attendance — past/today days within the active service window.
  // ICU-at-home nursing + caretaker cover is daily (24hr/12hr shifts), so
  // every day from service start through today has an attendance record.
  final services = DemoData.activeServices;
  if (services.isNotEmpty) {
    final serviceStart =
        services.map((s) => dateOnly(s.startDate)).reduce((a, b) => a.isBefore(b) ? a : b);
    if (!d.isBefore(serviceStart) && !d.isAfter(today)) {
      final icu = services.first; // ICU Setup at Home — 2 staff
      final present = icu.checkedInStaff ?? 0;
      final total = icu.totalStaff ?? 0;
      final nurse = DemoData.icuDeployment;
      final caretaker = DemoData.caretakerDeployment;
      events.add(CareEvent(
        date: d,
        type: CareEventType.staff,
        title: '$present/$total staff present',
        subtitle: '${nurse.staffName} (${nurse.staffRole}) · '
            '${caretaker.staffName} (${caretaker.staffRole})',
      ));
    }
  }

  // ── Upcoming visits / tests / renewals (seeded appointments) ───────────
  for (final appt in DemoData.upcomingAppointments) {
    if (_sameDay(appt.date, d)) events.add(appt);
  }

  return events;
}
