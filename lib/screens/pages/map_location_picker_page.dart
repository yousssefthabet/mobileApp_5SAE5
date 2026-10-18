import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

class MapLocationResult {
  final String address;
  final String landmark;
  final double latitude;
  final double longitude;
  final Offset mapOffsetRatio;
  final bool viewOnHomeMap;

  const MapLocationResult({
    required this.address,
    required this.landmark,
    required this.latitude,
    required this.longitude,
    this.mapOffsetRatio = const Offset(0.5, 0.5),
    this.viewOnHomeMap = false,
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
  static const Color orangeTrashColor = Color(0xFFC35624);

  late final MapController _mapController;
  bool _isSatellite = false;

  late LatLng _currentCoord;
  late String _currentAddress;
  late String _currentLandmark;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Real landmarks in Tunis matching HomePage
  final List<MapLocationResult> _presetLandmarks = const [
    MapLocationResult(
      address: 'Rue de la Liberté, near Central Square',
      landmark: 'Central Square Hub',
      latitude: 36.8065,
      longitude: 10.1815,
    ),
    MapLocationResult(
      address: 'Avenue Habib Bourguiba, near Theater',
      landmark: 'Avenue Habib Bourguiba',
      latitude: 36.8008,
      longitude: 10.1800,
    ),
    MapLocationResult(
      address: 'Montplaisir District, North Sector',
      landmark: 'Montplaisir Charging',
      latitude: 36.8150,
      longitude: 10.1900,
    ),
    MapLocationResult(
      address: 'Parc des Berges, North Gate',
      landmark: 'Parc des Berges',
      latitude: 36.8210,
      longitude: 10.1980,
    ),
    MapLocationResult(
      address: 'Lac Charging Area, Route du Lac',
      landmark: 'Lac Charging Point',
      latitude: 36.8330,
      longitude: 10.2350,
    ),
    MapLocationResult(
      address: 'Bardo City Center, Place du Bardo',
      landmark: 'Bardo EV Station',
      latitude: 36.8090,
      longitude: 10.1400,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    final init = widget.initialLocation ?? _presetLandmarks.first;
    _currentCoord = LatLng(init.latitude, init.longitude);
    _currentAddress = init.address;
    _currentLandmark = init.landmark;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapTapped(TapPosition tapPosition, LatLng latLng) {
    _updateSelectedLocation(latLng);
  }

  void _updateSelectedLocation(LatLng coord) {
    MapLocationResult? closest;
    double minDistance = double.infinity;

    const distanceCalc = Distance();
    for (final preset in _presetLandmarks) {
      final d = distanceCalc.as(
        LengthUnit.Meter,
        coord,
        LatLng(preset.latitude, preset.longitude),
      );
      if (d < minDistance) {
        minDistance = d;
        closest = preset;
      }
    }

    setState(() {
      _currentCoord = coord;
      if (closest != null && minDistance < 250) {
        _currentAddress = closest.address;
        _currentLandmark = closest.landmark;
      } else {
        final latStr = coord.latitude.toStringAsFixed(4);
        final lngStr = coord.longitude.toStringAsFixed(4);
        _currentLandmark = 'Custom Pinpoint ($latStr, $lngStr)';
        _currentAddress = 'Pinpoint near Tunis ($latStr° N, $lngStr° E)';
      }
    });
  }

  void _selectPreset(MapLocationResult preset) {
    final target = LatLng(preset.latitude, preset.longitude);
    setState(() {
      _currentCoord = target;
      _currentAddress = preset.address;
      _currentLandmark = preset.landmark;
    });
    _mapController.move(target, 15.5);
  }

  void _resetToCurrentLocation() {
    _selectPreset(_presetLandmarks.first);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Centered to central detected location'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _confirmSelection({bool viewOnHomeMap = false}) {
    final result = MapLocationResult(
      address: _currentAddress,
      landmark: _currentLandmark,
      latitude: _currentCoord.latitude,
      longitude: _currentCoord.longitude,
      viewOnHomeMap: viewOnHomeMap,
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

            // 3. Real Interactive Map View (like HomePage)
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentCoord,
                      initialZoom: 15.0,
                      minZoom: 3.0,
                      maxZoom: 19.0,
                      onTap: _onMapTapped,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _isSatellite
                            ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.chargi',
                        maxZoom: 19,
                      ),
                      MarkerLayer(
                        markers: [
                          // Preset landmark hints
                          ..._presetLandmarks.map((landmark) {
                            final isCurrent = landmark.landmark == _currentLandmark;
                            if (isCurrent) return null;
                            return Marker(
                              point: LatLng(landmark.latitude, landmark.longitude),
                              width: 30,
                              height: 30,
                              child: GestureDetector(
                                onTap: () => _selectPreset(landmark),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: primaryGreen, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.place,
                                    size: 16,
                                    color: primaryGreen,
                                  ),
                                ),
                              ),
                            );
                          }).whereType<Marker>(),

                          // Active Selected Trash Pin
                          Marker(
                            point: _currentCoord,
                            width: 60,
                            height: 60,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: child,
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: orangeTrashColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: orangeTrashColor.withValues(alpha: 0.45),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDFE6E3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_outlined, size: 16, color: orangeTrashColor),
                            SizedBox(width: 8),
                            Text(
                              'Tap anywhere on map to position the trash pin',
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

                  // Floating Map Controls (satellite, zoom, recenter - matching HomePage)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFloatingMapButton(
                          icon: _isSatellite ? Icons.map_outlined : Icons.layers_outlined,
                          tooltip: _isSatellite ? 'Street map' : 'Satellite map',
                          color: _isSatellite ? primaryGreen : const Color(0xFF283230),
                          onTap: () {
                            setState(() {
                              _isSatellite = !_isSatellite;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildFloatingMapButton(
                          icon: Icons.add,
                          tooltip: 'Zoom in',
                          onTap: () {
                            final zoom = _mapController.camera.zoom;
                            if (zoom < 18.5) {
                              _mapController.move(_mapController.camera.center, zoom + 1);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildFloatingMapButton(
                          icon: Icons.remove,
                          tooltip: 'Zoom out',
                          onTap: () {
                            final zoom = _mapController.camera.zoom;
                            if (zoom > 4) {
                              _mapController.move(_mapController.camera.center, zoom - 1);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildFloatingMapButton(
                          icon: Icons.my_location,
                          tooltip: 'Recenter pin',
                          onTap: () {
                            _mapController.move(_currentCoord, 16.0);
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
            onPressed: () => _confirmSelection(),
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

  Widget _buildFloatingMapButton({
    required IconData icon,
    required String tooltip,
    Color color = const Color(0xFF283230),
    required VoidCallback onTap,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
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
        tooltip: tooltip,
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
                  color: Color(0xFFFDEEE5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: orangeTrashColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SELECTED TRASH LOCATION',
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
                      'GPS: ${_currentCoord.latitude.toStringAsFixed(4)}° N, ${_currentCoord.longitude.toStringAsFixed(4)}° E',
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

          const SizedBox(height: 14),

          // Confirm button & View on Home map button
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmSelection(),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(
                      'Confirm Location',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmSelection(viewOnHomeMap: true),
                  icon: const Icon(Icons.map_outlined, size: 18, color: orangeTrashColor),
                  label: const Text(
                    'View on Home Map',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: orangeTrashColor,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: orangeTrashColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    backgroundColor: const Color(0xFFFDEEE5).withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
