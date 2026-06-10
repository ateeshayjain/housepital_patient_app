// test/models/care_event_test.dart
//
// Unit tests for the Care Calendar's pure event aggregator (eventsFor) and
// the deterministic demo-adherence helpers. Demo data is seeded relative to
// DateTime.now(), so all expected dates here are computed the same way.

import 'package:flutter_test/flutter_test.dart';

import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/care_event.dart';

void main() {
  final today = dateOnly(DateTime.now());
  DateTime daysFromToday(int d) =>
      DateTime(today.year, today.month, today.day + d);

  group('eventsFor — determinism', () {
    test('same day always yields identical events (no Random)', () {
      final a = eventsFor(today);
      final b = eventsFor(today);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].type, b[i].type);
        expect(a[i].title, b[i].title);
        expect(a[i].subtitle, b[i].subtitle);
      }
    });

    test('past-day adherence subtitle is stable across calls', () {
      final day = daysFromToday(-4);
      final a = eventsFor(day).firstWhere((e) => e.type == CareEventType.meds);
      final b = eventsFor(day).firstWhere((e) => e.type == CareEventType.meds);
      expect(a.subtitle, b.subtitle);
      expect(a.subtitle, matches(RegExp(r'^\d+ of \d+ doses taken$')));
    });
  });

  group('eventsFor — categories on known dates', () {
    test('today has staff attendance AND meds', () {
      final types = eventsFor(today).map((e) => e.type).toSet();
      expect(types, contains(CareEventType.staff));
      expect(types, contains(CareEventType.meds));
    });

    test('today meds show the scheduled dose count (not past adherence)', () {
      final meds =
          eventsFor(today).firstWhere((e) => e.type == CareEventType.meds);
      expect(meds.subtitle, '${dosesPerDay()} doses scheduled');
    });

    test('past day in service window has staff + meds-taken summary', () {
      final events = eventsFor(daysFromToday(-3));
      final types = events.map((e) => e.type).toSet();
      expect(types, contains(CareEventType.staff));
      expect(types, contains(CareEventType.meds));
      final meds = events.firstWhere((e) => e.type == CareEventType.meds);
      expect(meds.subtitle, contains('doses taken'));
    });

    test('+1 day has the physiotherapy session visit', () {
      final events = eventsFor(daysFromToday(1));
      expect(
        events.any((e) =>
            e.type == CareEventType.visit &&
            e.title.contains('Physiotherapy')),
        isTrue,
      );
      // Future day: no staff attendance yet.
      expect(events.any((e) => e.type == CareEventType.staff), isFalse);
    });

    test('+2 days has the CBC sample pickup (test)', () {
      final events = eventsFor(daysFromToday(2));
      expect(
        events.any(
            (e) => e.type == CareEventType.test && e.title.contains('CBC')),
        isTrue,
      );
    });

    test('+3 days has the doctor follow-up visit', () {
      final events = eventsFor(daysFromToday(3));
      expect(
        events.any((e) =>
            e.type == CareEventType.visit &&
            e.title.contains('Follow-up') &&
            e.title.contains('Dr. Ananya Sharma')),
        isTrue,
      );
    });

    test('ICU renewal lands on ActiveService.renewalDate', () {
      final renewal = DemoData.activeServices.first.renewalDate!;
      final events = eventsFor(renewal);
      expect(
        events.any((e) =>
            e.type == CareEventType.renewal &&
            e.title.contains('ICU service renewal')),
        isTrue,
      );
    });

    test('a day long before any demo data is empty', () {
      expect(eventsFor(daysFromToday(-60)), isEmpty);
    });

    test('a plain future day (+10) has meds-only', () {
      final types = eventsFor(daysFromToday(10)).map((e) => e.type).toSet();
      expect(types, {CareEventType.meds});
    });
  });

  group('adherence helpers', () {
    test('adherencePercentFor is deterministic and within 80–100', () {
      for (var i = 1; i <= 40; i++) {
        final day = daysFromToday(-i);
        final p = adherencePercentFor(day);
        expect(p, adherencePercentFor(day)); // stable
        expect(p, inInclusiveRange(80, 100));
      }
    });

    test('weeklyAdherencePercent is within 80–100 and stable', () {
      final p = weeklyAdherencePercent();
      expect(p, weeklyAdherencePercent());
      expect(p, inInclusiveRange(80, 100));
    });

    test('dosesPerDay counts every time slot of active demo meds', () {
      final expected = DemoData.medications
          .where((m) => m.isActive)
          .fold<int>(0, (s, m) => s + m.timeSlots.length);
      expect(dosesPerDay(), expected);
      expect(dosesPerDay(), greaterThan(0));
    });
  });
}
