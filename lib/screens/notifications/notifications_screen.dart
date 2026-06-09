import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../utils/notification_router.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/paginated_list.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Key _listKey = UniqueKey();

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
              setState(() => _listKey = UniqueKey());
            },
            child: Text(
              l.t('mark_all_read'),
              style: const TextStyle(
                  color: HousepitalColors.orange, fontSize: 13),
            ),
          ),
        ],
      ),
      body: PaginatedListView<AppNotification>(
        key: _listKey,
        pageSize: 20,
        showEmptyOnError: true,
        fetchPage: (page, pageSize) =>
            ApiService().getNotificationsPaginated(
          page: page,
          pageSize: pageSize,
        ),
        itemBuilder: (n) => _buildNotificationTile(n),
        emptyWidget: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none,
                  size: 64, color: context.hc.greyLight),
              const SizedBox(height: 16),
              Text(l.t('no_data'),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.hc.grey)),
              const SizedBox(height: 8),
              Text(
                  'No notifications yet',
                  style: TextStyle(
                      fontSize: 13,
                      color: context.hc.greyLight)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTile(AppNotification n) {
    IconData icon;
    Color iconColor;

    switch (n.type) {
      case 'attendance':
        icon = Icons.person_pin;
        iconColor = context.hc.success;
        break;
      case 'vitals_alert':
        icon = Icons.monitor_heart;
        iconColor = context.hc.error;
        break;
      case 'report_ready':
        icon = Icons.description;
        iconColor = context.hc.info;
        break;
      case 'payment_reminder':
        icon = Icons.payment;
        iconColor = context.hc.warning;
        break;
      case 'booking_update':
        icon = Icons.event;
        iconColor = HousepitalColors.orange;
        break;
      default:
        icon = Icons.notifications;
        iconColor = context.hc.grey;
    }

    return ListTile(
      leading: AppIconTile(icon: icon, color: iconColor, size: 22),
      title: Text(
        n.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w600,
          color: context.hc.black,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, color: context.hc.greyLight)),
          const SizedBox(height: 2),
          Text(
            DateHelper.formatRelative(n.createdAt),
            style: TextStyle(
                fontSize: 11, color: context.hc.greyLight),
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
        }
        if (!mounted) return;
        // Route to relevant screen based on notification type
        NotificationRouter.handleNotification(context, {
          'type': n.type,
          if (n.data != null && n.data!['id'] != null) 'id': n.data!['id'],
        });
      },
    );
  }
}
