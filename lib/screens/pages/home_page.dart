// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:chargi/widgets/BottomNavigationBar.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onNavigateToReport;
  final VoidCallback? onNavigateToMyReports;
  final bool showBottomNavBar;

  const HomePage({
    super.key,
    this.onNavigateToProfile,
    this.onNavigateToReport,
    this.onNavigateToMyReports,
    this.showBottomNavBar = true,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedFilterIndex = 0; // 0: EV, 1: Kiosks, 2: Reports
  bool _isReserved = false;

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color badgeGreenText = Color(0xFF0D6855);
  static const Color orangeTrashColor = Color(0xFFC35624);
  static const Color blueKioskColor = Color(0xFF1E63B8);

  final List<Map<String, dynamic>> _filters = [
    {'label': 'EV', 'icon': Icons.bolt},
    {'label': 'Kiosks', 'icon': Icons.storefront_outlined},
    {'label': 'Reports', 'icon': Icons.delete_outline},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Full Screen Interactive Stylized Map Background
            Positioned.fill(
              child: CustomPaint(
                painter: _StylizedMapPainter(),
              ),
            ),

            // 2. Map Pins Layer (responsive coordinates using LayoutBuilder)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;

                  return Stack(
                    children: [
                      // EV Charger Pin 1 (North Station)
                      Positioned(
                        top: h * 0.32,
                        left: w * 0.22,
                        child: _buildMapPin(
                          color: primaryGreen,
                          icon: Icons.bolt,
                          onTap: () => _showPinInfo(context, 'EV Station - North'),
                        ),
                      ),

                      // EV Charger Pin 2 (Central Square Hub - Highlighted)
                      Positioned(
                        top: h * 0.42,
                        left: w * 0.46,
                        child: _buildMapPin(
                          color: primaryGreen,
                          icon: Icons.bolt,
                          isHighlighted: true,
                          onTap: () => _showPinInfo(context, 'Central Square Hub'),
                        ),
                      ),

                      // Kiosk Pin (City Info Kiosk)
                      Positioned(
                        top: h * 0.36,
                        left: w * 0.65,
                        child: _buildMapPin(
                          color: blueKioskColor,
                          icon: Icons.storefront_outlined,
                          onTap: () => _showPinInfo(context, 'City Info Kiosk'),
                        ),
                      ),

                      // Report / Trash Pin (Overflowing Bin)
                      Positioned(
                        top: h * 0.50,
                        left: w * 0.67,
                        child: _buildMapPin(
                          color: orangeTrashColor,
                          icon: Icons.delete_outline,
                          onTap: () => _showPinInfo(context, 'Reported Trash Bin'),
                        ),
                      ),

                      // User Current Location Pin (Pulsing blue indicator)
                      Positioned(
                        top: h * 0.51,
                        left: w * 0.38,
                        child: _buildUserLocationPin(),
                      ),

                      // Map Recenter / GPS Button (Positioned just above the card on the right)
                      Positioned(
                        bottom: 245,
                        right: 20,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0xFFE2E7E5),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.my_location,
                              color: Color(0xFF283230),
                              size: 20,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Centered to current location'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // 3. Top Floating Search Bar and Filter Chips
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search Bar Container
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              color: Color(0xFF70807C),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search chargers, kiosks, places',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF7A8B86),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: widget.onNavigateToProfile,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  color: primaryGreen,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'A',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Filter Chips Row
                      Row(
                        children: List.generate(_filters.length, (index) {
                          final isSelected = _selectedFilterIndex == index;
                          final filter = _filters[index];

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedFilterIndex = index;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected ? primaryGreen : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? primaryGreen
                                        : const Color(0xFFDEE5E2),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      filter['icon'] as IconData,
                                      size: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF2C3935),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      filter['label'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF2C3935),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Nearest Charger Floating Card (Positioned at bottom)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.09),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Little drag handle indicator
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E7E5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header Row: Nearest Charger + Available badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'NEAREST CHARGER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF7E8F8B),
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Central Square Hub',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E2A27),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '350 m · Open 24 hours',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF7E8F8B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE4F3EE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Available',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: badgeGreenText,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 3 Info Columns (FREE, POWER, PRICE)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFCFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFECEFEF),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildStatColumn('FREE', '2 of 4'),
                          _buildStatDivider(),
                          _buildStatColumn('POWER', '50 kW'),
                          _buildStatDivider(),
                          _buildStatColumn('PRICE', '[PRICE]'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Action Buttons: Reserve a spot + Direction arrow
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isReserved = !_isReserved;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: primaryGreen,
                                    content: Text(
                                      _isReserved
                                          ? 'Spot reserved at Central Square Hub!'
                                          : 'Reservation cancelled',
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
                                _isReserved ? 'Spot Reserved ✓' : 'Reserve a spot',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFD6DFDC),
                              width: 1.2,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.near_me_outlined,
                              color: Color(0xFF283633),
                              size: 22,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Navigating to Central Square Hub...'),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNavBar
          ? CustomBottomNavigationBar(
              currentIndex: 0,
              onTap: (index) {
                if (index == 1 && widget.onNavigateToReport != null) {
                  widget.onNavigateToReport!();
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

  Widget _buildStatColumn(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Color(0xFF869793),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E2A27),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 28,
      color: const Color(0xFFE5EBE8),
    );
  }

  Widget _buildMapPin({
    required Color color,
    required IconData icon,
    bool isHighlighted = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isHighlighted ? 46 : 36,
        height: isHighlighted ? 46 : 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.38),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white,
            width: isHighlighted ? 2.5 : 2,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: isHighlighted ? 24 : 18,
        ),
      ),
    );
  }

  Widget _buildUserLocationPin() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF2E6FF2).withOpacity(0.22),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFF2E6FF2),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E6FF2).withOpacity(0.4),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }

  void _showPinInfo(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: $title'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

/// Custom painter to generate an authentic stylized road and city map matching Figure 1 in the PDF
class _StylizedMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background tone
    final backgroundPaint = Paint()..color = const Color(0xFFEEF2F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Green parks/open areas
    final parkPaint = Paint()..color = const Color(0xFFE1EAE4);

    final parkPath1 = Path()
      ..moveTo(0, size.height * 0.12)
      ..lineTo(size.width * 0.46, size.height * 0.24)
      ..lineTo(size.width * 0.38, size.height * 0.48)
      ..lineTo(0, size.height * 0.44)
      ..close();
    canvas.drawPath(parkPath1, parkPaint);

    final parkPath2 = Path()
      ..moveTo(size.width * 0.62, size.height * 0.16)
      ..lineTo(size.width, size.height * 0.08)
      ..lineTo(size.width, size.height * 0.42)
      ..lineTo(size.width * 0.70, size.height * 0.38)
      ..close();
    canvas.drawPath(parkPath2, parkPaint);

    final parkPath3 = Path()
      ..moveTo(0, size.height * 0.45)
      ..lineTo(size.width * 0.44, size.height * 0.50)
      ..lineTo(size.width * 0.36, size.height * 0.76)
      ..lineTo(0, size.height * 0.72)
      ..close();
    canvas.drawPath(parkPath3, parkPaint);

    final parkPath4 = Path()
      ..moveTo(size.width * 0.58, size.height * 0.56)
      ..lineTo(size.width, size.height * 0.48)
      ..lineTo(size.width, size.height * 0.85)
      ..lineTo(size.width * 0.66, size.height * 0.82)
      ..close();
    canvas.drawPath(parkPath4, parkPaint);

    // Road styling: Border and Center
    final roadBorderPaint = Paint()
      ..color = const Color(0xFFDFE6E3)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 38;

    final roadSurfacePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 32;

    // Road 1: Diagonal across screen
    final road1 = Path()
      ..moveTo(-30, size.height * 0.38)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.42,
        size.width * 0.65,
        size.height * 0.30,
        size.width + 40,
        size.height * 0.24,
      );

    // Road 2: North to South curved avenue
    final road2 = Path()
      ..moveTo(size.width * 0.52, -30)
      ..cubicTo(
        size.width * 0.50,
        size.height * 0.30,
        size.width * 0.42,
        size.height * 0.60,
        size.width * 0.35,
        size.height + 40,
      );

    // Road 3: Lower connecting street
    final road3 = Path()
      ..moveTo(-30, size.height * 0.64)
      ..lineTo(size.width + 30, size.height * 0.52);

    // Road 4: Secondary branch street
    final road4 = Path()
      ..moveTo(size.width * 0.45, size.height * 0.35)
      ..lineTo(size.width + 30, size.height * 0.65);

    // Draw borders then white surfaces
    canvas.drawPath(road1, roadBorderPaint);
    canvas.drawPath(road2, roadBorderPaint);
    canvas.drawPath(road3, roadBorderPaint);
    canvas.drawPath(road4, roadBorderPaint);

    canvas.drawPath(road1, roadSurfacePaint);
    canvas.drawPath(road2, roadSurfacePaint);
    canvas.drawPath(road3, roadSurfacePaint);
    canvas.drawPath(road4, roadSurfacePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
