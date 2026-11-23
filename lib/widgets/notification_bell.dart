import 'package:flutter/material.dart';
import 'package:chargi/services/report_service.dart';
import 'package:chargi/screens/pages/notifications_page.dart';

/// Bell icon with a live red badge showing how many notifications are unread.
class NotificationBell extends StatelessWidget {
  final Color? color;

  const NotificationBell({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ReportService.instance.watchUnreadCount(),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          ),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 9 ? '9+' : '$unread'),
            child: Icon(Icons.notifications_none, color: color),
          ),
        );
      },
    );
  }
}
