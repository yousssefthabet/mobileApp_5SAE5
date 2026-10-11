// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'report_details_page.dart';
import 'reservation_confirmed_page.dart';
import 'charging_complete_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);
  static const Color cardBorder = Color(0xFFE8ECEB);
  static const Color backgroundColor = Color(0xFFF7F9F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Worker on the way (Figure 4)
              _buildNotificationTile(
                icon: Icons.delete_outline,
                iconColor: const Color(0xFFC05218),
                iconBg: const Color(0xFFFDEEE5),
                title: 'A worker is on the way',
                subtitle: 'Report #1042 is now in progress.',
                time: '5 min ago',
                isUnread: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReportDetailsPage(
                        reportId: '#1042',
                        problemTitle: 'Overflowing bin',
                        location: 'Rue de la Liberté · today',
                      ),
                    ),
                  );
                },
              ),

              const Divider(color: Color(0xFFF0F4F2), height: 1),

              // 2. Spot reserved (Figure 4)
              _buildNotificationTile(
                icon: Icons.bolt,
                iconColor: primaryGreen,
                iconBg: const Color(0xFFE4F3EE),
                title: 'Spot reserved',
                subtitle: 'Central Square Hub, today 10:30.',
                time: '1 hour ago',
                isUnread: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReservationConfirmedPage(
                        stationName: 'Central Square Hub',
                        connectorInfo: '1 · CCS',
                        timeSlot: 'Today 10:30, 1 hour',
                        heldFor: '14:52',
                      ),
                    ),
                  );
                },
              ),

              const Divider(color: Color(0xFFF0F4F2), height: 1),

              // 3. Report resolved (Figure 4)
              _buildNotificationTile(
                icon: Icons.check,
                iconColor: primaryGreen,
                iconBg: const Color(0xFFE4F3EE),
                title: 'Report resolved',
                subtitle: 'Illegal dumping on Avenue Habib Bourguiba was cleaned.',
                time: '3 days ago',
                isUnread: false,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report marked as successfully resolved.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              const Divider(color: Color(0xFFF0F4F2), height: 1),

              // 4. Charging finished (Figure 4)
              _buildNotificationTile(
                icon: Icons.access_time,
                iconColor: textMuted,
                iconBg: const Color(0xFFEEF2F0),
                title: 'Charging finished',
                subtitle: 'Your session is complete. See the receipt.',
                time: '4 days ago',
                isUnread: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChargingCompletePage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String time,
    required bool isUnread,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Circular Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: textMuted,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9AA7A3),
                    ),
                  ),
                ],
              ),
            ),

            // Unread Dot
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
