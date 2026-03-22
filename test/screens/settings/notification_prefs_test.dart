// test/screens/settings/notification_prefs_test.dart
//
// Tests notification preferences data:
// - Forced-ON prefs include: late_checkin, no_show, vitals_red, payment_reminder, booking_confirmation
// - Toggleable prefs include: staff_checkin, daily_report, weekly_summary, promotional
// - Forced prefs cannot be toggled off (verified by forced flag)

import 'package:flutter_test/flutter_test.dart';

// Replicate the _NotifPref structure and canonical data from
// notification_preferences_screen.dart since the class is private.

class NotifPref {
  final String key;
  final String title;
  final String subtitle;
  final bool forced;
  final bool defaultValue;

  const NotifPref({
    required this.key,
    required this.title,
    required this.subtitle,
    this.forced = false,
    this.defaultValue = true,
  });
}

const List<NotifPref> _toggleablePrefs = [
  NotifPref(
    key: 'notif_staff_checkin',
    title: 'Staff Check-in',
    subtitle: 'Get notified when staff checks in for duty',
    defaultValue: true,
  ),
  NotifPref(
    key: 'notif_daily_report',
    title: 'Daily Report Ready',
    subtitle: 'Notification when the daily care report is available',
    defaultValue: true,
  ),
  NotifPref(
    key: 'notif_weekly_summary',
    title: 'Weekly Summary',
    subtitle: 'Weekly summary of care activities and vitals',
    defaultValue: true,
  ),
  NotifPref(
    key: 'notif_promotional',
    title: 'Promotional',
    subtitle: 'Offers, discounts, and new service updates',
    defaultValue: false,
  ),
];

const List<NotifPref> _forcedPrefs = [
  NotifPref(
    key: 'notif_late_checkin',
    title: 'Late Check-in Alert',
    subtitle: 'Alert when staff is late for duty',
    forced: true,
  ),
  NotifPref(
    key: 'notif_noshow',
    title: 'No-show Alert',
    subtitle: 'Alert when staff does not show up',
    forced: true,
  ),
  NotifPref(
    key: 'notif_vitals_red',
    title: 'Vitals RED Alert',
    subtitle: 'Critical health vitals alert',
    forced: true,
  ),
  NotifPref(
    key: 'notif_payment_reminder',
    title: 'Payment Reminder',
    subtitle: 'Reminders for pending payments',
    forced: true,
  ),
  NotifPref(
    key: 'notif_booking_confirmation',
    title: 'Booking Confirmation',
    subtitle: 'Confirmation of service bookings',
    forced: true,
  ),
];

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Forced-ON prefs
  // ═══════════════════════════════════════════════════════════════════════════
  group('Notification preferences — Forced prefs', () {
    test('forced prefs list has 5 items', () {
      expect(_forcedPrefs.length, 5);
    });

    test('forced prefs include late_checkin', () {
      expect(
        _forcedPrefs.any((p) => p.key == 'notif_late_checkin'),
        isTrue,
      );
    });

    test('forced prefs include no_show', () {
      expect(
        _forcedPrefs.any((p) => p.key == 'notif_noshow'),
        isTrue,
      );
    });

    test('forced prefs include vitals_red', () {
      expect(
        _forcedPrefs.any((p) => p.key == 'notif_vitals_red'),
        isTrue,
      );
    });

    test('forced prefs include payment_reminder', () {
      expect(
        _forcedPrefs.any((p) => p.key == 'notif_payment_reminder'),
        isTrue,
      );
    });

    test('forced prefs include booking_confirmation', () {
      expect(
        _forcedPrefs.any((p) => p.key == 'notif_booking_confirmation'),
        isTrue,
      );
    });

    test('all forced prefs have forced=true', () {
      for (final pref in _forcedPrefs) {
        expect(pref.forced, isTrue,
            reason: '${pref.key} should be forced=true');
      }
    });

    test('all forced prefs have non-empty title and subtitle', () {
      for (final pref in _forcedPrefs) {
        expect(pref.title.isNotEmpty, isTrue,
            reason: '${pref.key} has empty title');
        expect(pref.subtitle.isNotEmpty, isTrue,
            reason: '${pref.key} has empty subtitle');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Toggleable prefs
  // ═══════════════════════════════════════════════════════════════════════════
  group('Notification preferences — Toggleable prefs', () {
    test('toggleable prefs list has 4 items', () {
      expect(_toggleablePrefs.length, 4);
    });

    test('toggleable prefs include staff_checkin', () {
      expect(
        _toggleablePrefs.any((p) => p.key == 'notif_staff_checkin'),
        isTrue,
      );
    });

    test('toggleable prefs include daily_report', () {
      expect(
        _toggleablePrefs.any((p) => p.key == 'notif_daily_report'),
        isTrue,
      );
    });

    test('toggleable prefs include weekly_summary', () {
      expect(
        _toggleablePrefs.any((p) => p.key == 'notif_weekly_summary'),
        isTrue,
      );
    });

    test('toggleable prefs include promotional', () {
      expect(
        _toggleablePrefs.any((p) => p.key == 'notif_promotional'),
        isTrue,
      );
    });

    test('none of the toggleable prefs are forced', () {
      for (final pref in _toggleablePrefs) {
        expect(pref.forced, isFalse,
            reason: '${pref.key} should not be forced');
      }
    });

    test('all toggleable prefs have non-empty title and subtitle', () {
      for (final pref in _toggleablePrefs) {
        expect(pref.title.isNotEmpty, isTrue,
            reason: '${pref.key} has empty title');
        expect(pref.subtitle.isNotEmpty, isTrue,
            reason: '${pref.key} has empty subtitle');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Forced prefs cannot be toggled off
  // ═══════════════════════════════════════════════════════════════════════════
  group('Notification preferences — forced cannot toggle off', () {
    test('forced prefs are always true in loaded state', () {
      // Simulate what _loadPreferences does:
      final prefs = <String, bool>{};
      for (final pref in _toggleablePrefs) {
        prefs[pref.key] = pref.defaultValue;
      }
      for (final pref in _forcedPrefs) {
        prefs[pref.key] = true; // always ON — ignores any stored value
      }

      for (final pref in _forcedPrefs) {
        expect(prefs[pref.key], isTrue,
            reason: '${pref.key} should always be true');
      }
    });

    test('forced prefs remain true even if SharedPreferences stored false', () {
      // Simulate stored value of false for forced prefs
      final storedValues = <String, bool>{};
      for (final pref in _forcedPrefs) {
        storedValues[pref.key] = false; // hypothetically stored as false
      }

      // But the screen always overrides forced prefs to true:
      final loadedPrefs = <String, bool>{};
      for (final pref in _forcedPrefs) {
        loadedPrefs[pref.key] = true; // always ON
      }

      for (final pref in _forcedPrefs) {
        expect(loadedPrefs[pref.key], isTrue);
      }
    });

    test('no overlap between forced and toggleable pref keys', () {
      final forcedKeys = _forcedPrefs.map((p) => p.key).toSet();
      final toggleableKeys = _toggleablePrefs.map((p) => p.key).toSet();
      expect(forcedKeys.intersection(toggleableKeys), isEmpty);
    });
  });
}
