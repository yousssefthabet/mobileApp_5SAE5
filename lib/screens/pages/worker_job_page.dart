// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:chargi/widgets/BottomNavigationBar.dart';

class WorkerJobPage extends StatefulWidget {
  final VoidCallback? onNavigateToHome;
  final VoidCallback? onNavigateToProfile;
  final bool showBottomNavBar;

  const WorkerJobPage({
    super.key,
    this.onNavigateToHome,
    this.onNavigateToProfile,
    this.showBottomNavBar = true,
  });

  @override
  State<WorkerJobPage> createState() => _WorkerJobPageState();
}

class _WorkerJobPageState extends State<WorkerJobPage> {
  int _currentWorkerNavIndex = 0;
  bool _jobStarted = false;
  bool _afterPhotoUploaded = false;

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color cardBorderColor = Color(0xFFE8ECEB);
  static const Color onDutyBadgeBg = Color(0xFFDDF0EB);
  static const Color orangePriorityBg = Color(0xFFFDEEE5);
  static const Color orangePriorityText = Color(0xFFC05218);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'WORKER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Color(0xFF7E8F8B),
                ),
              ),
              const SizedBox(height: 4),

              // Title Row with "On duty" badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's jobs",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E2926),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: onDutyBadgeBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'On duty',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 1. Three Stats Cards (Assigned, Done, Avg time)
              Row(
                children: [
                  _buildStatCard(count: '3', label: 'Assigned'),
                  const SizedBox(width: 12),
                  _buildStatCard(count: '1', label: 'Done'),
                  const SizedBox(width: 12),
                  _buildStatCard(count: '12 min', label: 'Avg time'),
                ],
              ),

              const SizedBox(height: 22),

              // 2. Active Job Card (#1042 · Overflowing bin)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mini Map Preview with Trash Pin
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _MiniMapPainter(),
                              ),
                            ),
                            // Trash Marker Pin
                            Center(
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC04C16),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFC04C16).withOpacity(0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title & Location
                          const Text(
                            'Job #1042 · Overflowing bin',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E2926),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Rue de la Liberté, near Central Square',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7A8B86),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Badges Row: High priority, 1.2 km, 20 min ago
                          Row(
                            children: [
                              _buildPillBadge(
                                label: 'High priority',
                                bgColor: orangePriorityBg,
                                textColor: orangePriorityText,
                              ),
                              const SizedBox(width: 8),
                              _buildPillBadge(
                                label: '1.2 km',
                                bgColor: const Color(0xFFEFF3F1),
                                textColor: const Color(0xFF556561),
                              ),
                              const SizedBox(width: 8),
                              _buildPillBadge(
                                label: '20 min ago',
                                bgColor: const Color(0xFFEFF3F1),
                                textColor: const Color(0xFF556561),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Action Button 1: Start job and navigate
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _jobStarted = !_jobStarted;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: primaryGreen,
                                    content: Text(
                                      _jobStarted
                                          ? 'Job #1042 Started! Navigation active.'
                                          : 'Job navigation stopped.',
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: Text(
                                _jobStarted ? 'Job In Progress (Navigating...)' : 'Start job and navigate',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Action Button 2: Upload after photo
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _afterPhotoUploaded = !_afterPhotoUploaded;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _afterPhotoUploaded
                                          ? 'After photo uploaded! Marked as Done.'
                                          : 'Upload cancelled',
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryGreen,
                                side: const BorderSide(
                                  color: primaryGreen,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: Text(
                                _afterPhotoUploaded ? 'After photo uploaded ✓' : 'Upload after photo',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNavBar
          ? CustomBottomNavigationBar(
              isWorker: true,
              currentIndex: _currentWorkerNavIndex,
              onTap: (index) {
                setState(() {
                  _currentWorkerNavIndex = index;
                });
                if (index == 1 && widget.onNavigateToHome != null) {
                  widget.onNavigateToHome!();
                } else if (index == 3 && widget.onNavigateToProfile != null) {
                  widget.onNavigateToProfile!();
                }
              },
            )
          : null,
    );
  }

  Widget _buildStatCard({required String count, required String label}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E2926),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7A8B86),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillBadge({
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

/// Mini Map Painter for Worker Job Card Preview
class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFEFF4F1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final greenPark = Paint()..color = const Color(0xFFE2EBE5);
    final parkPath = Path()
      ..moveTo(0, size.height * 0.3)
      ..lineTo(size.width * 0.7, 0)
      ..lineTo(size.width, size.height * 0.4)
      ..lineTo(size.width * 0.4, size.height)
      ..close();
    canvas.drawPath(parkPath, greenPark);

    final roadBorder = Paint()
      ..color = const Color(0xFFDFE7E3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26;

    final roadWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;

    final roadPath = Path()
      ..moveTo(-10, size.height * 0.6)
      ..cubicTo(
        size.width * 0.4,
        size.height * 0.75,
        size.width * 0.6,
        size.height * 0.25,
        size.width + 10,
        size.height * 0.4,
      );

    canvas.drawPath(roadPath, roadBorder);
    canvas.drawPath(roadPath, roadWhite);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
