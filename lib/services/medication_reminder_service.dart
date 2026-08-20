import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/medication_models.dart';

/// Callback for handling notification taps. Must be a top-level or static
/// function so it can work even when the app is cold-started by a tap.
@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {
  MedicationReminderService()._onNotificationTap(response);
}

/// Manages local push-notification reminders for medications.
///
/// Uses [FlutterLocalNotificationsPlugin] to schedule daily repeating
/// notifications for each medication time slot. On web this is a no-op —
/// callers should show a SnackBar fallback instead.
class MedicationReminderService {
  // ---- singleton ----
  static final MedicationReminderService _instance =
      MedicationReminderService._();
  factory MedicationReminderService() => _instance;
  MedicationReminderService._();

  late FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Callback that the app layer can set so that tapping a notification can
  /// trigger navigation or provider calls.
  void Function(String medicationId, String action)? onNotificationAction;

  // ---- schedule-slot defaults (used only when timeSlots is empty) ----
  static const defaultSlotTimes = <String, String>{
    'morning': '08:00',
    'afternoon': '13:00',
    'evening': '18:00',
    'bedtime': '22:00',
  };

  // ---- Android notification channel ----
  static const _channelId = 'medication_reminders';
  static const _channelName = 'Medication Reminders';
  static const _channelDescription =
      'Daily reminders to take your medications on time';

  // ---- init ----

  /// Initialise the notification plug-in with platform-specific settings.
  /// Must be called once (e.g., in main.dart) before scheduling anything.
  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return; // local notifications not supported on web
    }

    tz.initializeTimeZones();
    // Use the device's local timezone
    final localTimeZone = tz.local;
    if (localTimeZone.name == 'UTC') {
      // Fallback: try to detect from DateTime
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      // Find a timezone that matches the offset
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (location.currentTimeZone.offset == offset.inMilliseconds) {
          tz.setLocalLocation(location);
          break;
        }
      }
    }

    _plugin = FlutterLocalNotificationsPlugin();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Create Android notification channel
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  // ---- scheduling ----

  /// Schedule daily reminders for a medication based on its [timeSlots].
  ///
  /// Each time slot gets its own notification with a unique ID derived from
  /// [medication.id] and the slot index, so they can be independently cancelled.
  ///
  /// If [medication.remindersEnabled] is false or the medication is inactive,
  /// this method is a no-op.
  Future<void> scheduleMedicationReminders(
      MedicationFull medication) async {
    if (kIsWeb || !_initialized) return;
    if (!medication.remindersEnabled || !medication.isActive) return;
    if (medication.frequency == 'as_needed') return;

    // If medication has an end date in the past, skip
    if (medication.endDate != null &&
        medication.endDate!.isBefore(DateTime.now())) {
      return;
    }

    final slots = medication.timeSlots.isNotEmpty
        ? medication.timeSlots
        : _defaultSlotsForFrequency(medication.frequency);

    for (var i = 0; i < slots.length; i++) {
      final notificationId = _generateNotificationId(medication.id, i);
      final time = _parseTime(slots[i]);
      if (time == null) continue;

      final scheduledDate = _nextInstanceOfTime(time.hour, time.minute);

      await _plugin.zonedSchedule(
        notificationId,
        '${medication.name} ${medication.dosage}',
        'Time to take your medication',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            actions: <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'taken',
                'Taken \u2713',
                showsUserInterface: true,
              ),
              const AndroidNotificationAction(
                'snooze',
                'Snooze 10 min',
                showsUserInterface: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
        payload: '${medication.id}|${slots[i]}',
      );
    }
  }

  /// Schedule a one-time snooze notification 10 minutes from now.
  Future<void> _scheduleSnooze(String medicationId, String payload) async {
    if (kIsWeb || !_initialized) return;

    // Use a snooze-specific ID range
    final snoozeId = _generateSnoozeId(medicationId);
    final snoozeTime =
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));

    // Extract medication name from payload if possible
    await _plugin.zonedSchedule(
      snoozeId,
      'Snoozed: Medication Reminder',
      'Time to take your medication (snoozed)',
      snoozeTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'taken',
              'Taken \u2713',
              showsUserInterface: true,
            ),
            const AndroidNotificationAction(
              'snooze',
              'Snooze 10 min',
              showsUserInterface: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Cancel all reminders for a specific medication.
  Future<void> cancelReminders(String medicationId) async {
    if (kIsWeb || !_initialized) return;

    // Cancel all possible slot IDs (max 4 slots for four_times_daily)
    for (var i = 0; i < 4; i++) {
      await _plugin.cancel(_generateNotificationId(medicationId, i));
    }
    // Also cancel any pending snooze
    await _plugin.cancel(_generateSnoozeId(medicationId));
  }

  /// Cancel all medication reminders.
  Future<void> cancelAllReminders() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancelAll();
  }

  /// Reschedule all reminders — useful after bulk load or edit.
  Future<void> rescheduleAll(List<MedicationFull> medications) async {
    if (kIsWeb || !_initialized) return;
    await cancelAllReminders();
    for (final med in medications) {
      await scheduleMedicationReminders(med);
    }
  }

  // ---- notification tap handling ----

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final parts = payload.split('|');
    final medicationId = parts.first;
    final actionId = response.actionId;

    if (actionId == 'snooze') {
      _scheduleSnooze(medicationId, payload);
      return;
    }

    // 'taken' action or plain tap → notify listener
    final action = (actionId == 'taken') ? 'taken' : 'open';
    onNotificationAction?.call(medicationId, action);
  }

  // ---- ID generation ----

  /// Largest base value that survives the `* 10 + slot` expansion inside a
  /// 32-bit signed int: 199_999_999 * 10 + 9 = 1_999_999_999 < 2^31 - 1.
  static const int _idBaseModulus = 200000000;

  /// Folds a medication ID into the notification ID space.
  ///
  /// WHY NOT `hashCode.abs() * 10`
  /// A notification ID is a Java `int` on Android and an `Int32` on iOS —
  /// ±2^31-1. Dart's `String.hashCode` on the 64-bit VM ranges far past that,
  /// so `hashCode.abs() * 10 + slot` routinely produced values the platform
  /// channel truncated or rejected. Truncation is the dangerous half: two
  /// medications whose IDs differ only above bit 31 collapse onto the SAME
  /// notification ID, and scheduling the second silently REPLACES the first.
  /// The patient is simply never reminded about one of their drugs, and
  /// nothing anywhere reports an error.
  ///
  /// `.abs()` was also not a safety net: `int.minValue.abs()` returns
  /// `int.minValue` in Dart — still negative. Masking off the sign bit is,
  /// because it cannot have an exceptional case.
  static int _foldToIdSpace(String medicationId) =>
      (medicationId.hashCode & 0x7FFFFFFF) % _idBaseModulus;

  /// Generates a deterministic notification ID from a medication ID string
  /// and a slot index. The ID space is partitioned so each medication gets
  /// up to 10 unique IDs (slots 0-3 for schedules, 5 for snooze).
  static int _generateNotificationId(String medicationId, int slotIndex) {
    return _foldToIdSpace(medicationId) * 10 + slotIndex;
  }

  static int _generateSnoozeId(String medicationId) {
    return _foldToIdSpace(medicationId) * 10 + 5;
  }

  /// Returns the list of notification IDs that would be generated for a
  /// medication with the given number of time slots.
  static List<int> getNotificationIds(String medicationId, int slotCount) {
    return List.generate(
        slotCount, (i) => _generateNotificationId(medicationId, i));
  }

  // ---- helpers ----

  /// Calculates the next upcoming reminder from a list of medications.
  /// Returns null if there are no upcoming reminders today.
  static ({String medicationName, String dosage, String time})?
      getNextReminder(List<MedicationFull> medications) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    String? nextMedName;
    String? nextDosage;
    String? nextTime;
    int smallestDiff = 999999;

    for (final med in medications) {
      if (!med.isActive || !med.remindersEnabled) continue;
      if (med.frequency == 'as_needed') continue;

      final slots = med.timeSlots.isNotEmpty
          ? med.timeSlots
          : _defaultSlotsForFrequency(med.frequency);

      for (final slot in slots) {
        final time = _parseTime(slot);
        if (time == null) continue;

        final slotMinutes = time.hour * 60 + time.minute;
        final diff = slotMinutes - currentMinutes;

        // Only consider future slots today
        if (diff > 0 && diff < smallestDiff) {
          smallestDiff = diff;
          nextMedName = med.name;
          nextDosage = med.dosage;
          nextTime = slot;
        }
      }
    }

    if (nextMedName == null || nextTime == null || nextDosage == null) {
      return null;
    }

    return (
      medicationName: nextMedName,
      dosage: nextDosage,
      time: nextTime,
    );
  }

  /// Return the status of a slot relative to now: 'upcoming', 'taken', or 'missed'.
  static String getSlotStatus(
    String timeSlot, {
    required bool isTaken,
  }) {
    if (isTaken) return 'taken';

    final time = _parseTime(timeSlot);
    if (time == null) return 'upcoming';

    final now = DateTime.now();
    final slotMinutes = time.hour * 60 + time.minute;
    final currentMinutes = now.hour * 60 + now.minute;

    return slotMinutes > currentMinutes ? 'upcoming' : 'missed';
  }

  static List<String> _defaultSlotsForFrequency(String frequency) {
    switch (frequency) {
      case 'once_daily':
        return ['08:00'];
      case 'twice_daily':
        return ['08:00', '20:00'];
      case 'thrice_daily':
        return ['08:00', '14:00', '21:00'];
      case 'four_times_daily':
        return ['06:00', '12:00', '18:00', '22:00'];
      default:
        return ['08:00'];
    }
  }

  static ({int hour, int minute})? _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour: hour, minute: minute);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
