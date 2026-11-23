import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargi/services/report_service.dart';
import 'report_details_page.dart';
import 'reservation_confirmed_page.dart';
import 'charging_complete_page.dart';

/// Shows the notifications workers send about the user's reports
/// (`users/{uid}/notifications`), newest first.
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
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textDark),
        ),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () => ReportService.instance.markAllRead(),
            style: TextButton.styleFrom(foregroundColor: primaryGreen),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ReportService.instance.watchMyNotifications(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              _sectionLabel('YOUR REPORTS'),
              const SizedBox(height: 8),
              if (snapshot.hasError)
                _infoCard('Could not load notifications: ${snapshot.error}')
              else if (!snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: primaryGreen)),
                )
              else if (docs.isEmpty)
                _infoCard(
                  'No notifications yet. You will be notified here when a worker '
                  'starts working on one of your reports.',
                )
              else
                _group([
                  for (final doc in docs) _buildReportNotification(context, doc),
                ]),

              const SizedBox(height: 24),

              // Charging notifications are still demo content.
              _sectionLabel('CHARGING'),
              const SizedBox(height: 8),
              _group([
                _buildTile(
                  icon: Icons.bolt,
                  iconColor: primaryGreen,
                  iconBg: const Color(0xFFE4F3EE),
                  title: 'Spot reserved',
                  subtitle: 'Central Square Hub, today 10:30.',
                  time: '1 hour ago',
                  isUnread: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReservationConfirmedPage(
                        stationName: 'Central Square Hub',
                        connectorInfo: '1 · CCS',
                        timeSlot: 'Today 10:30, 1 hour',
                        heldFor: '14:52',
                      ),
                    ),
                  ),
                ),
                _buildTile(
                  icon: Icons.access_time,
                  iconColor: textMuted,
                  iconBg: const Color(0xFFEEF2F0),
                  title: 'Charging finished',
                  subtitle: 'Your session is complete. See the receipt.',
                  time: '4 days ago',
                  isUnread: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChargingCompletePage()),
                  ),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportNotification(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final type = data['type'] as String? ?? 'status';
    final status = data['status'] as String?;
    final reportId = data['reportId'] as String?;
    final isUnread = data['read'] != true;

    final IconData icon;
    final Color fg;
    final Color bg;
    if (type == 'deleted') {
      icon = Icons.delete_outline;
      fg = Colors.redAccent;
      bg = const Color(0xFFFDECEC);
    } else if (type == 'edited') {
      icon = Icons.edit_outlined;
      fg = const Color(0xFF1E63B8);
      bg = const Color(0xFFE8F1FC);
    } else {
      icon = ReportStatus.icon(status);
      fg = ReportStatus.foreground(status);
      bg = ReportStatus.background(status);
    }

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => ReportService.instance.deleteNotification(doc.id),
      child: _buildTile(
        icon: icon,
        iconColor: fg,
        iconBg: bg,
        title: (data['title'] as String?) ?? 'Report update',
        subtitle: (data['body'] as String?) ?? '',
        time: _timeAgo(data['createdAt']),
        isUnread: isUnread,
        onTap: () {
          if (isUnread) ReportService.instance.markRead(doc.id);
          if (reportId != null && type != 'deleted') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportDetailsPage(reportId: '', reportDocId: reportId),
              ),
            );
          }
        },
      ),
    );
  }

  static String _timeAgo(dynamic ts) {
    if (ts is! Timestamp) return 'just now';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Color(0xFF7E8F8B),
        ),
      );

  Widget _infoCard(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder),
        ),
        child: Text(text, style: const TextStyle(color: textMuted, height: 1.35)),
      );

  Widget _group(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const Divider(color: Color(0xFFF0F4F2), height: 1),
            tiles[i],
          ],
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String time,
    required bool isUnread,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: textMuted, height: 1.3),
                    ),
                    const SizedBox(height: 5),
                    Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF9AA7A3))),
                  ],
                ),
              ),
              if (isUnread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(color: primaryGreen, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
