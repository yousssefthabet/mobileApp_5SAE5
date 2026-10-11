// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

class ReportDetailsPage extends StatelessWidget {
  final String reportId;
  final String problemTitle;
  final String location;
  final String workerName;
  final String estimatedArrival;

  const ReportDetailsPage({
    super.key,
    this.reportId = '#1042',
    this.problemTitle = 'Overflowing bin',
    this.location = 'Rue de la Liberté · today',
    this.workerName = '[Worker name]',
    this.estimatedArrival = 'Arriving in about 15 min',
  });

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color orangeBadgeBg = Color(0xFFFDEEE5);
  static const Color orangeBadgeText = Color(0xFFC05218);
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
        title: Text(
          'Report $reportId',
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
              child: Stack(
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

            const SizedBox(height: 20),

            // 2. Problem Title + Status Badge + Location
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    problemTitle,
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
                    color: orangeBadgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'In progress',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: orangeBadgeText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              location,
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
                    isCompleted: true,
                    isCurrent: false,
                    isLast: false,
                    title: 'Sent',
                    subtitle: '10:02',
                  ),
                  _buildTimelineStep(
                    isCompleted: true,
                    isCurrent: false,
                    isLast: false,
                    title: 'Assigned',
                    subtitle: '10:09',
                  ),
                  _buildTimelineStep(
                    isCompleted: true,
                    isCurrent: true,
                    isLast: false,
                    title: 'In progress',
                    subtitle: 'Worker on the way',
                  ),
                  _buildTimelineStep(
                    isCompleted: false,
                    isCurrent: false,
                    isLast: true,
                    title: 'Resolved',
                    subtitle: 'Waiting',
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
                    child: const Text(
                      'W',
                      style: TextStyle(
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
                          workerName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          estimatedArrival,
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
                            content: Text('Opening chat with $workerName...'),
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
