// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportDetailsPage extends StatelessWidget {
  final String reportId;
  final String? reportDocId;
  final String problemTitle;
  final String location;
  final String workerName;
  final String estimatedArrival;

  const ReportDetailsPage({
    super.key,
    this.reportId = '#1042',
    this.reportDocId,
    this.problemTitle = 'Overflowing bin',
    this.location = 'Rue de la Liberté · today',
    this.workerName = '[Worker name]',
    this.estimatedArrival = 'Arriving in about 15 min',
  });

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color orangeBadgeBg = Color(0xFFFDEEE5);
  static const Color orangeBadgeText = Color(0xFFC05218);
  static const Color greenBadgeBg = Color(0xFFE4F3EE);
  static const Color greenBadgeText = Color(0xFF0D6855);
  static const Color blueBadgeBg = Color(0xFFE8F1FC);
  static const Color blueBadgeText = Color(0xFF1E63B8);
  static const Color mintBadgeBg = Color(0xFFE2EFEA);
  static const Color mintBadgeText = Color(0xFF086B5B);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);
  static const Color cardBorder = Color(0xFFE8ECEB);
  static const Color backgroundColor = Color(0xFFF7F9F8);

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    return 'today';
  }

  @override
  Widget build(BuildContext context) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }

    if (reportDocId != null && user != null) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reports')
            .doc(reportDocId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: backgroundColor,
              body: Center(
                child: CircularProgressIndicator(color: primaryGreen),
              ),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: backgroundColor,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: textDark),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      const Text(
                        'Failed to load report details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final data = snapshot.data?.data();
          final displayId = (data?['reference'] as String?) ?? reportId;
          final title = (data?['problemTitle'] as String?) ?? problemTitle;
          final loc = (data?['location'] as String?) ?? location;
          final status = (data?['status'] as String?) ?? 'sent';
          final worker = (data?['workerName'] as String?) ?? workerName;
          final arrival = (data?['estimatedArrival'] as String?) ?? estimatedArrival;
          final photoBase64 = data?['photoBase64'] as String?;
          final createdTime = _formatTimestamp(data?['createdAt']);

          return _buildContent(
            context: context,
            displayId: displayId,
            title: title,
            loc: loc,
            status: status,
            worker: worker,
            arrival: arrival,
            sentTime: createdTime,
            photoBase64: photoBase64,
          );
        },
      );
    }

    return _buildContent(
      context: context,
      displayId: reportId,
      title: problemTitle,
      loc: location,
      status: 'in_progress',
      worker: workerName,
      arrival: estimatedArrival,
      sentTime: '10:02',
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required String displayId,
    required String title,
    required String loc,
    required String status,
    required String worker,
    required String arrival,
    required String sentTime,
    String? photoBase64,
  }) {
    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    switch (status.toLowerCase()) {
      case 'resolved':
        badgeBg = greenBadgeBg;
        badgeText = greenBadgeText;
        badgeLabel = 'Resolved';
        break;
      case 'in_progress':
        badgeBg = orangeBadgeBg;
        badgeText = orangeBadgeText;
        badgeLabel = 'In progress';
        break;
      case 'assigned':
        badgeBg = blueBadgeBg;
        badgeText = blueBadgeText;
        badgeLabel = 'Assigned';
        break;
      case 'sent':
      default:
        badgeBg = mintBadgeBg;
        badgeText = mintBadgeText;
        badgeLabel = 'Sent';
        break;
    }

    final isSentCompleted = true;
    final isSentCurrent = status == 'sent';

    final isAssignedCompleted =
        status == 'assigned' || status == 'in_progress' || status == 'resolved';
    final isAssignedCurrent = status == 'assigned';

    final isInProgressCompleted =
        status == 'in_progress' || status == 'resolved';
    final isInProgressCurrent = status == 'in_progress';

    final isResolvedCompleted = status == 'resolved';
    final isResolvedCurrent = status == 'resolved';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Report $displayId',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Photo Area (Figure 6)
            Container(
              height: 170,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFDCE8E2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: photoBase64 != null
                    ? Image.memory(
                        base64Decode(photoBase64),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 170,
                      )
                    : Stack(
                        children: [
                          Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 44,
                              color: primaryGreen.withOpacity(0.35),
                            ),
                          ),
                          const Positioned(
                            bottom: 14,
                            left: 16,
                            child: Text(
                              'Your photo',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4A5C57),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // 2. Problem Title + Status Badge + Location
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: badgeText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              loc,
              style: const TextStyle(
                fontSize: 13,
                color: textMuted,
              ),
            ),

            const SizedBox(height: 24),

            // 3. Vertical Timeline Stepper Card (Figure 6)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder, width: 1),
              ),
              child: Column(
                children: [
                  _buildTimelineStep(
                    isCompleted: isSentCompleted,
                    isCurrent: isSentCurrent,
                    isLast: false,
                    title: 'Sent',
                    subtitle: sentTime,
                  ),
                  _buildTimelineStep(
                    isCompleted: isAssignedCompleted,
                    isCurrent: isAssignedCurrent,
                    isLast: false,
                    title: 'Assigned',
                    subtitle: isAssignedCompleted ? 'Assigned to team' : 'Waiting',
                  ),
                  _buildTimelineStep(
                    isCompleted: isInProgressCompleted,
                    isCurrent: isInProgressCurrent,
                    isLast: false,
                    title: 'In progress',
                    subtitle: isInProgressCompleted
                        ? (status == 'resolved' ? 'Completed' : 'Worker on the way')
                        : 'Waiting',
                  ),
                  _buildTimelineStep(
                    isCompleted: isResolvedCompleted,
                    isCurrent: isResolvedCurrent,
                    isLast: true,
                    title: 'Resolved',
                    subtitle: isResolvedCompleted ? 'Area cleaned' : 'Waiting',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 4. Worker Card (Figure 6)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorder, width: 1),
              ),
              child: Row(
                children: [
                  // Worker Avatar W
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      worker.trim().isNotEmpty
                          ? worker.trim()[0].toUpperCase()
                          : 'W',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name & ETA
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          arrival,
                          style: const TextStyle(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chat bubble icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFCFB),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E7E5)),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: Color(0xFF283633),
                        size: 18,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Opening chat with $worker...'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
    required String title,
    required String subtitle,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Dot & Line
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? primaryGreen : Colors.white,
                  border: Border.all(
                    color: isCompleted ? primaryGreen : const Color(0xFFCCD6D2),
                    width: isCurrent ? 3 : 2,
                  ),
                ),
                child: isCompleted && !isCurrent
                    ? const Icon(
                        Icons.check,
                        size: 10,
                        color: Colors.white,
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.5,
                    color: isCompleted && !isCurrent
                        ? primaryGreen
                        : const Color(0xFFE2EBE7),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // Step Text
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isCurrent || isCompleted
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isCompleted ? textDark : const Color(0xFF8B9B96),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted ? textMuted : const Color(0xFFA2AEA9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
