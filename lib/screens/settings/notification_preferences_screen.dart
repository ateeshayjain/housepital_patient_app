import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/common_widgets.dart';

class _NotifPref {
  final String key;
  final String title;
  final String subtitle;
  final bool forced;
  final bool defaultValue;

  const _NotifPref({
    required this.key,
    required this.title,
    required this.subtitle,
    this.forced = false,
    this.defaultValue = true,
  });
}

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final Map<String, bool> _prefs = {};
  bool _isLoading = true;

  static const List<_NotifPref> _toggleablePrefs = [
    _NotifPref(
      key: 'notif_staff_checkin',
      title: 'Staff Check-in',
      subtitle: 'Get notified when staff checks in for duty',
      defaultValue: true,
    ),
    _NotifPref(
      key: 'notif_daily_report',
      title: 'Daily Report Ready',
      subtitle: 'Notification when the daily care report is available',
      defaultValue: true,
    ),
    _NotifPref(
      key: 'notif_weekly_summary',
      title: 'Weekly Summary',
      subtitle: 'Weekly summary of care activities and vitals',
      defaultValue: true,
    ),
    _NotifPref(
      key: 'notif_promotional',
      title: 'Promotional',
      subtitle: 'Offers, discounts, and new service updates',
      defaultValue: false,
    ),
  ];

  static const List<_NotifPref> _forcedPrefs = [
    _NotifPref(
      key: 'notif_late_checkin',
      title: 'Late Check-in Alert',
      subtitle: 'Alert when staff is late for duty',
      forced: true,
    ),
    _NotifPref(
      key: 'notif_noshow',
      title: 'No-show Alert',
      subtitle: 'Alert when staff does not show up',
      forced: true,
    ),
    _NotifPref(
      key: 'notif_vitals_red',
      title: 'Vitals RED Alert',
      subtitle: 'Critical health vitals alert',
      forced: true,
    ),
    _NotifPref(
      key: 'notif_payment_reminder',
      title: 'Payment Reminder',
      subtitle: 'Reminders for pending payments',
      forced: true,
    ),
    _NotifPref(
      key: 'notif_booking_confirmation',
      title: 'Booking Confirmation',
      subtitle: 'Confirmation of service bookings',
      forced: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final appProvider = context.read<AppProvider>();
    final toggleable = _toggleablePrefs
        .map((p) => {'key': p.key, 'defaultValue': p.defaultValue})
        .toList();
    final forced = _forcedPrefs
        .map((p) => {'key': p.key, 'defaultValue': true})
        .toList();
    final prefs = await appProvider.getNotificationPreferences(toggleable, forced);

    setState(() {
      _prefs.addAll(prefs);
      _isLoading = false;
    });
  }

  Future<void> _updatePref(String key, bool value) async {
    setState(() => _prefs[key] = value);
    await context.read<AppProvider>().setNotificationPreference(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      // audit batch 4 (Agent L): Apple P5 — replace bare spinner with a
      // Shimmer skeleton that mimics the SwitchListTile rows so the layout
      // doesn't pop in when prefs arrive from the provider.
      body: _isLoading
          ? _buildSkeleton()
          : ListView(
              children: [
                // Toggleable preferences
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Preferences',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.greyLight,
                    ),
                  ),
                ),
                ..._toggleablePrefs.map(_buildToggleTile),

                const Divider(height: 32),

                // Forced preferences
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Required Notifications',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HousepitalColors.greyLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.lock, size: 14, color: HousepitalColors.greyLight),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'These notifications cannot be turned off for your safety.',
                    style: TextStyle(
                        fontSize: 12, color: HousepitalColors.greyLight),
                  ),
                ),
                const SizedBox(height: 8),
                ..._forcedPrefs.map(_buildForcedTile),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // audit batch 4 (Agent L): Shimmer skeleton — 5 toggle rows + section
  // header bar. Heights mirror SwitchListTile so the page settles without a
  // jump when prefs hydrate.
  Widget _buildSkeleton() {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surface;
    Widget bar({double width = double.infinity, double height = 14}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        );

    Widget row() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(width: 160, height: 15),
                    const SizedBox(height: 8),
                    bar(width: 240, height: 12),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: bar(width: 100, height: 13),
          ),
          for (int i = 0; i < 5; i++) row(),
        ],
      ),
    );
  }

  Widget _buildToggleTile(_NotifPref pref) {
    return SwitchListTile(
      value: _prefs[pref.key] ?? pref.defaultValue,
      onChanged: (v) => _updatePref(pref.key, v),
      activeThumbColor: HousepitalColors.orange,
      title: Text(pref.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(pref.subtitle,
          style:
              const TextStyle(fontSize: 12, color: HousepitalColors.greyLight)),
    );
  }

  Widget _buildForcedTile(_NotifPref pref) {
    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(pref.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          const StatusBadge(
            text: 'Required',
            color: HousepitalColors.grey,
            icon: Icons.lock,
          ),
        ],
      ),
      subtitle: Text(pref.subtitle,
          style:
              const TextStyle(fontSize: 12, color: HousepitalColors.greyLight)),
      trailing: Switch(
        value: true,
        onChanged: null,
        activeThumbColor: HousepitalColors.orange,
      ),
    );
  }
}
