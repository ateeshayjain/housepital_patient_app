// lib/providers/reminders_provider.dart
//
// Quick-add reminders for the Care Calendar ('+' in the calendar app bar).
// Session-local list persisted as a JSON array in SharedPreferences, so a
// reminder added today is still there after an app restart.
//
// Reminders surface on the calendar as CareEvents (see [ReminderItem.toCareEvent])
// so the month dots, week-card previews and day detail all share one event
// pipeline with the seeded demo events.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/care_event.dart';

/// What kind of thing the user is reminding themselves about. Kept small on
/// purpose — anything richer (doses, staff shifts) already has a first-class
/// flow elsewhere in the app.
enum ReminderCategory { reminder, visit, todo }

/// Display label per category (calendar copy is literal-English by design).
String reminderCategoryLabel(ReminderCategory c) => switch (c) {
  ReminderCategory.reminder => 'Reminder',
  ReminderCategory.visit => 'Visit',
  ReminderCategory.todo => 'To-do',
};

class ReminderItem {
  final String id;
  final String title;

  /// Date-only (midnight) — reminders belong to a calendar day.
  final DateTime date;

  /// Optional 24h 'HH:mm' time (matches the medication time-slot format).
  final String? time;
  final ReminderCategory category;

  const ReminderItem({
    required this.id,
    required this.title,
    required this.date,
    required this.category,
    this.time,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    if (time != null) 'time': time,
    'category': category.name,
  };

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    final parsed = DateTime.tryParse(json['date'] as String? ?? '');
    return ReminderItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      date: parsed == null ? dateOnly(DateTime.now()) : dateOnly(parsed),
      time: json['time'] as String?,
      category: ReminderCategory.values.asNameMap()[json['category']] ??
          ReminderCategory.reminder,
    );
  }

  /// 'HH:mm' → '8:00 AM' (same convention as the dose rows). Null-safe.
  String? get formattedTime {
    final t = time;
    if (t == null) return null;
    final parts = t.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? parts[1] : '00';
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:$minute $period';
  }

  /// Bridge into the calendar's shared event pipeline. Visit-category
  /// reminders join the existing visit color family; reminders and to-dos
  /// get the dedicated reminder dot category.
  CareEvent toCareEvent() => CareEvent(
    date: date,
    type: category == ReminderCategory.visit
        ? CareEventType.visit
        : CareEventType.reminder,
    title: title,
    subtitle: formattedTime == null
        ? reminderCategoryLabel(category)
        : '$formattedTime · ${reminderCategoryLabel(category)}',
  );
}

class RemindersProvider extends ChangeNotifier {
  static const storageKey = 'housepital_reminders';

  final List<ReminderItem> _items = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<ReminderItem> get reminders => List.unmodifiable(_items);

  /// Loads the persisted list. Corrupted/missing storage degrades to an
  /// empty list — a reminder cache is never worth a crash.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      _items.clear();
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items.addAll(
            decoded.whereType<Map<String, dynamic>>().map(ReminderItem.fromJson),
          );
          _sort();
        }
      }
    } catch (_) {
      _items.clear();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> add({
    required String title,
    required DateTime date,
    String? time,
    ReminderCategory category = ReminderCategory.reminder,
  }) async {
    _items.add(
      ReminderItem(
        id: 'rem_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        date: dateOnly(date),
        time: time,
        category: category,
      ),
    );
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    final before = _items.length;
    _items.removeWhere((r) => r.id == id);
    if (_items.length == before) return;
    notifyListeners();
    await _persist();
  }

  /// All reminders falling on [day] (date-only comparison), in time order.
  List<ReminderItem> remindersOn(DateTime day) {
    final d = dateOnly(day);
    return _items.where((r) => r.date == d).toList();
  }

  /// [remindersOn] mapped into the calendar event pipeline.
  List<CareEvent> eventsOn(DateTime day) =>
      remindersOn(day).map((r) => r.toCareEvent()).toList();

  void _sort() {
    _items.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return (a.time ?? '99:99').compareTo(b.time ?? '99:99');
    });
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        storageKey,
        jsonEncode(_items.map((r) => r.toJson()).toList()),
      );
    } catch (_) {
      // Persistence is best-effort; the in-memory list stays authoritative.
    }
  }
}
