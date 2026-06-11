// test/providers/reminders_provider_test.dart
//
// Unit tests for RemindersProvider: add / persist / load / delete, the
// date-bucket query and the CareEvent bridge. SharedPreferences is mocked
// per-test, and "reload" is asserted with a FRESH provider instance reading
// the same mock store (the real restart path).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/models/care_event.dart';
import 'package:housepital_patient/providers/reminders_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final day = DateTime(2026, 6, 11);

  test('add stores a sorted reminder and persists JSON', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = RemindersProvider();
    await provider.load();
    expect(provider.isLoaded, isTrue);
    expect(provider.reminders, isEmpty);

    var notified = 0;
    provider.addListener(() => notified++);

    await provider.add(
      title: 'Evening walk',
      date: day,
      time: '18:30',
      category: ReminderCategory.todo,
    );
    await provider.add(title: 'Buy BP batteries', date: day, time: '08:00');

    expect(provider.reminders, hasLength(2));
    expect(notified, 2);
    // Same-day reminders sort by time.
    expect(provider.reminders.first.title, 'Buy BP batteries');
    expect(provider.reminders.first.date, DateTime(2026, 6, 11));
    expect(provider.reminders.first.formattedTime, '8:00 AM');

    // Persisted as a JSON list under the storage key.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(RemindersProvider.storageKey);
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as List;
    expect(decoded, hasLength(2));
    expect(decoded.first['title'], 'Buy BP batteries');
    expect(decoded.first['date'], '2026-06-11');
  });

  test('reminders persist across a provider reload', () async {
    SharedPreferences.setMockInitialValues({});
    final first = RemindersProvider();
    await first.load();
    await first.add(
      title: 'Physio follow-up',
      date: day,
      time: '10:15',
      category: ReminderCategory.visit,
    );

    // Fresh instance = app restart; reads the same persisted store.
    final second = RemindersProvider();
    await second.load();
    expect(second.reminders, hasLength(1));
    final r = second.reminders.single;
    expect(r.title, 'Physio follow-up');
    expect(r.date, DateTime(2026, 6, 11));
    expect(r.time, '10:15');
    expect(r.category, ReminderCategory.visit);
  });

  test('delete removes the reminder and persists the removal', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = RemindersProvider();
    await provider.load();
    await provider.add(title: 'Order diapers', date: day);
    final id = provider.reminders.single.id;

    await provider.delete(id);
    expect(provider.reminders, isEmpty);

    // Deleting a missing id is a no-op (no throw, no notify churn).
    var notified = 0;
    provider.addListener(() => notified++);
    await provider.delete('rem_does_not_exist');
    expect(notified, 0);

    final reloaded = RemindersProvider();
    await reloaded.load();
    expect(reloaded.reminders, isEmpty);
  });

  test('remindersOn / eventsOn bucket by day and bridge to CareEvent',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = RemindersProvider();
    await provider.load();
    await provider.add(title: 'Buy batteries', date: day, time: '08:00');
    await provider.add(
      title: 'Dr. Sharma follow-up',
      date: day,
      category: ReminderCategory.visit,
    );
    await provider.add(
      title: 'Next day errand',
      date: day.add(const Duration(days: 1)),
    );

    expect(provider.remindersOn(day), hasLength(2));
    expect(provider.remindersOn(day.add(const Duration(days: 2))), isEmpty);

    final events = provider.eventsOn(day);
    expect(events, hasLength(2));
    // Reminder/to-do map to the dedicated reminder dot category; the visit
    // category joins the existing visit family.
    final byTitle = {for (final e in events) e.title: e};
    expect(byTitle['Buy batteries']!.type, CareEventType.reminder);
    expect(byTitle['Buy batteries']!.subtitle, '8:00 AM · Reminder');
    expect(byTitle['Dr. Sharma follow-up']!.type, CareEventType.visit);
    expect(byTitle['Dr. Sharma follow-up']!.subtitle, 'Visit');
  });

  test('corrupted storage degrades to an empty list (no crash)', () async {
    SharedPreferences.setMockInitialValues({
      RemindersProvider.storageKey: 'not-json{{{',
    });
    final provider = RemindersProvider();
    await provider.load();
    expect(provider.isLoaded, isTrue);
    expect(provider.reminders, isEmpty);
  });
}
