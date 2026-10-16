import 'package:flutter/material.dart';

class MapLocationResult {
  final String address;
  final String landmark;
  final double latitude;
  final double longitude;
  final Offset mapOffsetRatio; // normalized 0.0 to 1.0 coordinates on map

  const MapLocationResult({
    required this.address,
    required this.landmark,
    required this.latitude,
    required this.longitude,
    required this.mapOffsetRatio,
  });
}

class MapLocationPickerPage extends StatefulWidget {
  final MapLocationResult? initialLocation;

  const MapLocationPickerPage({
    super.key,
    this.initialLocation,
  });

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage>
    with SingleTickerProviderStateMixin {
  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color lightMintBackground = Color(0xFFE2EFEA);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);

  // Normalized map offset (0.0 - 1.0)
  late Offset _selectedRatio;
  late String _currentAddress;
  late String _currentLandmark;
  late double _currentLat;
  late double _currentLng;

  double _zoomScale = 1.0;
  final TransformationController _transformationController =
      TransformationController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Preset landmarks that users can tap or pick
  final List<MapLocationResult> _presetLandmarks = const [
    MapLocationResult(
      address: 'Rue de la Liberté, near Central Square',
      landmark: 'Central Square Hub',
      latitude: 36.8065,
      longitude: 10.1815,
      mapOffsetRatio: Offset(0.48, 0.44),
    ),
    MapLocationResult(
      address: 'Avenue Habib Bourguiba, near Theater',
      landmark: 'Grand Avenue',
      latitude: 36.8002,
      longitude: 10.1860,
      mapOffsetRatio: Offset(0.68, 0.32),
    ),
    MapLocationResult(
      address: 'Parc des Berges, North Gate',
      landmark: 'Parc des Berges',
      latitude: 36.8210,
      longitude: 10.1980,
      mapOffsetRatio: Offset(0.28, 0.28),
    ),
    MapLocationResult(
      address: 'Boulevard de l\'Environnement, Bin #42',
      landmark: 'Eco Station East',
      latitude: 36.8120,
      longitude: 10.2050,
      mapOffsetRatio: Offset(0.72, 0.65),
    ),
    MapLocationResult(
      address: 'Rue de Marseille, Station Ouest',
      landmark: 'West Station Plaza',
      latitude: 36.8015,
      longitude: 10.1710,
      mapOffsetRatio: Offset(0.25, 0.62),
    ),
  ];

  @override
  void initState() {
    super.initState();

    final init = widget.initialLocation ?? _presetLandmarks.first;
    _selectedRatio = init.mapOffsetRatio;
    _currentAddress = init.address;
    _currentLandmark = init.landmark;
    _currentLat = init.latitude;
    _currentLng = init.longitude;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onMapTapped(TapUpDetails details, Size mapSize) {
    final localX = (details.localPosition.dx / mapSize.width).clamp(0.05, 0.95);
    final localY = (details.localPosition.dy / mapSize.height).clamp(0.05, 0.95);

    _updateSelectedLocation(Offset(localX, localY));
  }

  void _updateSelectedLocation(Offset ratio) {
    // Determine closest landmark or derive street address from coordinates
    MapLocationResult? closest;
    double minDistance = double.infinity;

    for (final preset in _presetLandmarks) {
      final dx = preset.mapOffsetRatio.dx - ratio.dx;
      final dy = preset.mapOffsetRatio.dy - ratio.dy;
      final dist = dx * dx + dy * dy;
      if (dist < minDistance) {
        minDistance = dist;
        closest = preset;
      }
    }

    // Convert ratio to simulated latitude/longitude
    final lat = 36.8000 + (1.0 - ratio.dy) * 0.025;
    final lng = 10.1700 + ratio.dx * 0.035;

    setState(() {
      _selectedRatio = ratio;
      if (closest != null && minDistance < 0.015) {
        _currentAddress = closest.address;
        _currentLandmark = closest.landmark;
        _currentLat = closest.latitude;
        _currentLng = closest.longitude;
      } else {
        final zoneName = ratio.dy < 0.4
            ? (ratio.dx < 0.5 ? 'North District' : 'Northeast Sector')
            : (ratio.dx < 0.5 ? 'Southwest Quarter' : 'East Commercial Sector');
        _currentAddress = 'Pinpoint at $zoneName (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
        _currentLandmark = zoneName;
        _currentLat = lat;
        _currentLng = lng;
      }
    });
  }

  void _selectPreset(MapLocationResult preset) {
    setState(() {
      _selectedRatio = preset.mapOffsetRatio;
      _currentAddress = preset.address;
      _currentLandmark = preset.landmark;
      _currentLat = preset.latitude;
      _currentLng = preset.longitude;
    });
  }

  void _resetToCurrentLocation() {
    _selectPreset(_presetLandmarks.first);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Centered to current detected location'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _confirmSelection() {
    final result = MapLocationResult(
      address: _currentAddress,
      landmark: _currentLandmark,
      latitude: _currentLat,
      longitude: _currentLng,
      mapOffsetRatio: _selectedRatio,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Bar
            _buildTopBar(context),

            // 2. Preset Quick Selection Chips
            _buildPresetChips(),

            // 3. Map View Area with Interactive Pin
            Expanded(
              child: Stack(
                children: [
                  // Stylized Interactive Vector Map
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final mapSize = Size(constraints.maxWidth, constraints.maxHeight);

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _onMapTapped(details, mapSize),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              size: mapSize,
                              painter: _InteractiveStylizedMapPainter(),
                            ),

                            // Landmark marker dots on the map
                            ..._presetLandmarks.map((landmark) {
                              final isCurrent = landmark.address == _currentAddress;
                              return Positioned(
                                left: landmark.mapOffsetRatio.dx * mapSize.width - 14,
                                top: landmark.mapOffsetRatio.dy * mapSize.height - 14,
                                child: GestureDetector(
                                  onTap: () => _selectPreset(landmark),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? primaryGreen
                                          : const Color(0xFF0D6855).withValues(alpha: 0.18),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.location_city,
                                      size: 14,
                                      color: isCurrent ? Colors.white : primaryGreen,
                                    ),
                                  ),
                                ),
                              );
                            }),

                            // The Active Selected Pin
                            Positioned(
                              left: _selectedRatio.dx * mapSize.width - 24,
                              top: _selectedRatio.dy * mapSize.height - 52,
                              child: IgnorePointer(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Floating tooltip with landmark/street name
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: textDark,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _currentLandmark,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),

                                    // Pin Head & Stem
                                    AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _pulseAnimation.value,
                                          child: child,
                                        );
                                      },
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: primaryGreen,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryGreen.withValues(alpha: 0.45),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ),

                                    // Ground anchor shadow dot
                                    Container(
                                      width: 8,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Floating hint banner on top of map
                  Positioned(
                    top: 12,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDFE6E3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_outlined, size: 16, color: primaryGreen),
                            SizedBox(width: 8),
                            Text(
                              'Tap anywhere on map to drop report pin',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Floating Right Controls: My Location & Zoom
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFloatingCircleButton(
                          icon: Icons.my_location,
                          tooltip: 'Current location',
                          onTap: _resetToCurrentLocation,
                        ),
                        const SizedBox(height: 10),
                        _buildFloatingCircleButton(
                          icon: Icons.add,
                          tooltip: 'Zoom in',
                          onTap: () {
                            setState(() {
                              _zoomScale = (_zoomScale + 0.2).clamp(1.0, 2.5);
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        _buildFloatingCircleButton(
                          icon: Icons.remove,
                          tooltip: 'Zoom out',
                          onTap: () {
                            setState(() {
                              _zoomScale = (_zoomScale - 0.2).clamp(1.0, 2.5);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 4. Bottom Confirmation Panel
            _buildBottomPanel(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8ECEB), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: textDark),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose Trash Location',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                Text(
                  'Tap on map or pick landmark below',
                  style: TextStyle(
                    fontSize: 12,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _confirmSelection,
            style: TextButton.styleFrom(
              foregroundColor: primaryGreen,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _presetLandmarks.map((preset) {
            final isSelected = _currentLandmark == preset.landmark;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(preset.landmark),
                selected: isSelected,
                selectedColor: lightMintBackground,
                backgroundColor: const Color(0xFFF1F4F3),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? primaryGreen : const Color(0xFF4A5C57),
                ),
                side: BorderSide(
                  color: isSelected ? primaryGreen : const Color(0xFFDFE6E3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                onSelected: (_) => _selectPreset(preset),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFloatingCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(icon, color: primaryGreen, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: lightMintBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SELECTED LOCATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _currentAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'GPS: ${_currentLat.toStringAsFixed(4)}° N, ${_currentLng.toStringAsFixed(4)}° E',
                      style: const TextStyle(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _confirmSelection,
              icon: const Icon(Icons.check, size: 20),
              label: const Text(
                'Confirm Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter to generate an interactive stylized city map
class _InteractiveStylizedMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background
    final backgroundPaint = Paint()..color = const Color(0xFFEEF2F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // 2. Parks & Green areas
    final parkPaint = Paint()..color = const Color(0xFFE1EAE4);

    final park1 = Path()
      ..moveTo(0, size.height * 0.12)
      ..lineTo(size.width * 0.46, size.height * 0.24)
      ..lineTo(size.width * 0.38, size.height * 0.48)
      ..lineTo(0, size.height * 0.44)
      ..close();
    canvas.drawPath(park1, parkPaint);

    final park2 = Path()
      ..moveTo(size.width * 0.62, size.height * 0.16)
      ..lineTo(size.width, size.height * 0.08)
      ..lineTo(size.width, size.height * 0.42)
      ..lineTo(size.width * 0.70, size.height * 0.38)
      ..close();
    canvas.drawPath(park2, parkPaint);

    final park3 = Path()
      ..moveTo(0, size.height * 0.45)
      ..lineTo(size.width * 0.44, size.height * 0.50)
      ..lineTo(size.width * 0.36, size.height * 0.76)
      ..lineTo(0, size.height * 0.72)
      ..close();
    canvas.drawPath(park3, parkPaint);

    final park4 = Path()
      ..moveTo(size.width * 0.58, size.height * 0.56)
      ..lineTo(size.width, size.height * 0.48)
      ..lineTo(size.width, size.height * 0.85)
      ..lineTo(size.width * 0.66, size.height * 0.82)
      ..close();
    canvas.drawPath(park4, parkPaint);

    // 3. Roads
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

    final road3 = Path()
      ..moveTo(-30, size.height * 0.64)
      ..lineTo(size.width + 30, size.height * 0.52);

    final road4 = Path()
      ..moveTo(size.width * 0.45, size.height * 0.35)
      ..lineTo(size.width + 30, size.height * 0.65);

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
