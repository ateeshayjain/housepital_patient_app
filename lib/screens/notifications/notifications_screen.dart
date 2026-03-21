import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      _notifications = await ApiService().getNotifications();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('notifications_title')),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiService().markAllNotificationsRead();
              _loadNotifications();
            },
            child: Text(
              l.t('mark_all_read'),
              style: const TextStyle(
                  color: HousepitalColors.orange, fontSize: 13),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: HousepitalColors.orange))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_none,
                          size: 64, color: HousepitalColors.greyLighter),
                      const SizedBox(height: 16),
                      Text(l.t('no_data'),
                          style: const TextStyle(
                              color: HousepitalColors.greyLight)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    return _buildNotificationTile(n);
                  },
                ),
    );
  }

  Widget _buildNotificationTile(AppNotification n) {
    IconData icon;
    Color iconColor;

    switch (n.type) {
      case 'attendance':
        icon = Icons.person_pin;
        iconColor = HousepitalColors.success;
        break;
      case 'vitals_alert':
        icon = Icons.monitor_heart;
        iconColor = HousepitalColors.error;
        break;
      case 'report_ready':
        icon = Icons.description;
        iconColor = HousepitalColors.info;
        break;
      case 'payment_reminder':
        icon = Icons.payment;
        iconColor = HousepitalColors.warning;
        break;
      case 'booking_update':
        icon = Icons.event;
        iconColor = HousepitalColors.orange;
        break;
      default:
        icon = Icons.notifications;
        iconColor = HousepitalColors.grey;
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        n.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w600,
          color: HousepitalColors.black,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, color: HousepitalColors.greyLight)),
          const SizedBox(height: 2),
          Text(
            DateHelper.formatRelative(n.createdAt),
            style: const TextStyle(
                fontSize: 11, color: HousepitalColors.greyLight),
          ),
        ],
      ),
      trailing: n.isRead
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: HousepitalColors.orange,
                shape: BoxShape.circle,
              ),
            ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () async {
        if (!n.isRead) {
          await ApiService().markNotificationRead(n.id);
          _loadNotifications();
        }
      },
    );
  }
}
