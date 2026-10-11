import 'package:flutter/material.dart';
import 'package:chargi/widgets/BottomNavigationBar.dart';
import 'report_sent_page.dart';

class ReportTrashPage extends StatefulWidget {
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToMyReports;
  final VoidCallback? onNavigateToProfile;
  final bool showBottomNavBar;

  const ReportTrashPage({
    super.key,
    this.onNavigateToMap,
    this.onNavigateToMyReports,
    this.onNavigateToProfile,
    this.showBottomNavBar = true,
  });

  @override
  State<ReportTrashPage> createState() => _ReportTrashPageState();
}

class _ReportTrashPageState extends State<ReportTrashPage> {
  int _selectedProblemIndex = 0; // 0: Overflowing bin, 1: Illegal dumping, 2: Broken bin, 3: Other
  bool _hasPhoto = false;

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color lightMintBackground = Color(0xFFE2EFEA);
  static const Color backgroundColor = Color(0xFFF7F9F8);

  final List<Map<String, dynamic>> _problemOptions = [
    {
      'title': 'Overflowing bin',
      'icon': Icons.delete_outline,
    },
    {
      'title': 'Illegal dumping',
      'icon': Icons.delete_outline,
    },
    {
      'title': 'Broken bin',
      'icon': Icons.build_outlined,
    },
    {
      'title': 'Other',
      'icon': Icons.menu,
    },
  ];

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
                'NEW REPORT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Color(0xFF7E8F8B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Report trash',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E2926),
                ),
              ),

              const SizedBox(height: 20),

              // 1. Photo Upload Area (Dashed border box)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _hasPhoto = !_hasPhoto;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_hasPhoto ? 'Photo selected' : 'Photo removed'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: const Color(0xFFCCD7D3),
                    strokeWidth: 1.5,
                    dashWidth: 6,
                    dashSpace: 4,
                    radius: 18,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _hasPhoto ? const Color(0xFFE9F4F0) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: lightMintBackground,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _hasPhoto ? Icons.check_circle_outline : Icons.camera_alt_outlined,
                            color: primaryGreen,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _hasPhoto ? 'Photo added ✓' : 'Take a photo',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2926),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hasPhoto ? 'Tap to change photo' : 'or choose from gallery',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7A8B86),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 2. Location Detected Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8ECEB), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: lightMintBackground,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        color: primaryGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Location detected',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E2926),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Rue de la Liberté, near Central Square',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7A8B86),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. Problem Options Header
              const Text(
                'WHAT IS THE PROBLEM?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Color(0xFF7E8F8B),
                ),
              ),

              const SizedBox(height: 14),

              // 4. 2x2 Grid of Problem Options
              Row(
                children: [
                  Expanded(child: _buildProblemCard(0)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildProblemCard(1)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildProblemCard(2)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildProblemCard(3)),
                ],
              ),

              const SizedBox(height: 28),

              // 5. Submit Report Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text(
                    'Submit report',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNavBar
          ? CustomBottomNavigationBar(
              currentIndex: 1,
              onTap: (index) {
                if (index == 0 && widget.onNavigateToMap != null) {
                  widget.onNavigateToMap!();
                } else if (index == 2 && widget.onNavigateToMyReports != null) {
                  widget.onNavigateToMyReports!();
                } else if (index == 3 && widget.onNavigateToProfile != null) {
                  widget.onNavigateToProfile!();
                }
              },
            )
          : null,
    );
  }

  Widget _buildProblemCard(int index) {
    final isSelected = _selectedProblemIndex == index;
    final item = _problemOptions[index];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProblemIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 94,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryGreen : const Color(0xFFE5EDE9),
            width: isSelected ? 2 : 1,
          ),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item['icon'] as IconData,
              color: isSelected ? primaryGreen : const Color(0xFF70857D),
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              item['title'] as String,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? const Color(0xFF1E2926) : const Color(0xFF3C4D48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReportSentPage(reportId: '#1043'),
      ),
    );
  }
}

/// Custom painter for dashed border around photo area
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length) ? dashWidth : metric.length - distance;
        final extractPath = metric.extractPath(distance, distance + length);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
