
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:chargi/widgets/BottomNavigationBar.dart';

import 'charger_details_page.dart';
import 'kiosk_detail_page.dart';
import 'report_details_page.dart';
import 'reserve_spot_page.dart';
import 'notifications_page.dart';

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
  int _selectedFilterIndex = 0;
  bool _isSatellite = false;

  late final MapController _mapController;

  static const LatLng _userCoord = LatLng(36.8040, 10.1790);
  static const LatLng _centralHubCoord = LatLng(36.8065, 10.1815);
  static const LatLng _trashReportCoord = LatLng(36.8035, 10.1860);

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color badgeGreenText = Color(0xFF0D6855);
  static const Color orangeTrashColor = Color(0xFFC35624);
  static const Color blueKioskColor = Color(0xFF1E63B8);

  // SAMPLE LOCATIONS around Tunis.
  // Replace these with verified station data when available.
  static const List<Map<String, dynamic>> _evStations = [
    {
      'name': 'Central Square Hub',
      'coord': LatLng(36.8065, 10.1815),
      'distance': '350 m',
    },
    {
      'name': 'EV Station - North',
      'coord': LatLng(36.8140, 10.1750),
      'distance': '1.2 km',
    },
    {
      'name': 'Avenue Habib Bourguiba',
      'coord': LatLng(36.8008, 10.1800),
      'distance': '800 m',
    },
    {
      'name': 'Lac Charging Point',
      'coord': LatLng(36.8330, 10.2350),
      'distance': '5.1 km',
    },
    {
      'name': 'Bardo EV Station',
      'coord': LatLng(36.8090, 10.1400),
      'distance': '4.0 km',
    },
    {
      'name': 'La Marsa Charging Hub',
      'coord': LatLng(36.8780, 10.3250),
      'distance': '15 km',
    },
    {
      'name': 'Manar EV Point',
      'coord': LatLng(36.8350, 10.1600),
      'distance': '4.2 km',
    },
    {
      'name': 'Montplaisir Charging',
      'coord': LatLng(36.8150, 10.1900),
      'distance': '1.5 km',
    },
    {
      'name': 'El Menzah EV Station',
      'coord': LatLng(36.8430, 10.1750),
      'distance': '5.0 km',
    },
    {
      'name': 'Lac 2 EV Station',
      'coord': LatLng(36.8500, 10.2650),
      'distance': '9.0 km',
    },
    {
      'name': 'Sidi Bou Said EV Point',
      'coord': LatLng(36.8700, 10.3470),
      'distance': '17 km',
    },
    {
      'name': 'Ben Arous Charging',
      'coord': LatLng(36.7530, 10.2300),
      'distance': '8.0 km',
    },
  ];

  // SAMPLE KIOSKS around Tunis.
  static const List<Map<String, dynamic>> _kiosks = [
    {
      'name': 'City Info Kiosk',
      'coord': LatLng(36.8090, 10.1880),
    },
    {
      'name': 'Grand Avenue Kiosk',
      'coord': LatLng(36.8015, 10.1840),
    },
    {
      'name': 'Medina Information Point',
      'coord': LatLng(36.7980, 10.1700),
    },
    {
      'name': 'Lac Tourist Kiosk',
      'coord': LatLng(36.8350, 10.2400),
    },
    {
      'name': 'Bardo City Kiosk',
      'coord': LatLng(36.8080, 10.1370),
    },
    {
      'name': 'Manar Service Kiosk',
      'coord': LatLng(36.8320, 10.1570),
    },
    {
      'name': 'Menzah Information Kiosk',
      'coord': LatLng(36.8450, 10.1770),
    },
    {
      'name': 'Marsa Tourist Kiosk',
      'coord': LatLng(36.8780, 10.3260),
    },
    {
      'name': 'Carthage Visitor Kiosk',
      'coord': LatLng(36.8530, 10.3230),
    },
    {
      'name': 'Montplaisir Service Kiosk',
      'coord': LatLng(36.8140, 10.1920),
    },
    {
      'name': 'Lac 2 Information Kiosk',
      'coord': LatLng(36.8500, 10.2600),
    },
    {
      'name': 'Ben Arous City Kiosk',
      'coord': LatLng(36.7520, 10.2300),
    },
  ];

  final List<Map<String, dynamic>> _filters = [
    {'label': 'EV', 'icon': Icons.bolt},
    {'label': 'Kiosks', 'icon': Icons.storefront_outlined},
    {'label': 'Reports', 'icon': Icons.delete_outline},
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String _avatarInitial() {
    final name = FirebaseAuth.instance.currentUser?.displayName ?? '';

    if (name.trim().isNotEmpty) {
      return name.trim()[0].toUpperCase();
    }

    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    if (email.trim().isNotEmpty) {
      return email.trim()[0].toUpperCase();
    }

    return 'U';
  }

  // Build all markers dynamically from the selected category.
  List<Marker> _buildMapMarkers() {
    final markers = <Marker>[];

    // User location indicator (sample position, not live GPS).
    markers.add(
      Marker(
        point: _userCoord,
        width: 32,
        height: 32,
        child: _buildUserLocationPin(),
      ),
    );

    // EV charging stations.
    if (_selectedFilterIndex == 0) {
      for (final station in _evStations) {
        final coord = station['coord'] as LatLng;
        final name = station['name'] as String;
        final distance = station['distance'] as String;
        final isHighlighted = name == 'Central Square Hub';

        markers.add(
          Marker(
            point: coord,
            width: isHighlighted ? 46 : 36,
            height: isHighlighted ? 46 : 36,
            child: _buildMapPin(
              color: primaryGreen,
              icon: Icons.bolt,
              isHighlighted: isHighlighted,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChargerDetailsPage(
                      stationName: name,
                      distance: distance,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    // Kiosks.
    if (_selectedFilterIndex == 1) {
      for (final kiosk in _kiosks) {
        final coord = kiosk['coord'] as LatLng;

        markers.add(
          Marker(
            point: coord,
            width: 36,
            height: 36,
            child: _buildMapPin(
              color: blueKioskColor,
              icon: Icons.storefront_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const KioskDetailPage(),
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    // Reports.
    if (_selectedFilterIndex == 2) {
      markers.add(
        Marker(
          point: _trashReportCoord,
          width: 44,
          height: 44,
          child: _buildMapPin(
            color: orangeTrashColor,
            icon: Icons.delete_outline,
            isHighlighted: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReportDetailsPage(),
                ),
              );
            },
          ),
        ),
      );
    }

    return markers;
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Interactive street and satellite map.
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _centralHubCoord,
                  initialZoom: 12.5,
                  minZoom: 3.0,
                  maxZoom: 19.0,
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
                    markers: _buildMapMarkers(),
                  ),
                ],
              ),
            ),

            // 2. Floating map controls.
            Positioned(
              bottom: 245,
              right: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFloatingMapButton(
                    icon: _isSatellite
                        ? Icons.map_outlined
                        : Icons.layers_outlined,
                    tooltip: _isSatellite
                        ? 'Street map'
                        : 'Satellite map',
                    color: _isSatellite
                        ? primaryGreen
                        : const Color(0xFF283230),
                    onTap: () {
                      setState(() {
                        _isSatellite = !_isSatellite;
                      });

                      _showMessage(
                        _isSatellite
                            ? 'Switched to Satellite View'
                            : 'Switched to Street Map',
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // Zoom in.
                  _buildFloatingMapButton(
                    icon: Icons.add,
                    tooltip: 'Zoom in',
                    onTap: () {
                      final zoom = _mapController.camera.zoom;

                      if (zoom < 18.5) {
                        _mapController.move(
                          _mapController.camera.center,
                          zoom + 1,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // Zoom out.
                  _buildFloatingMapButton(
                    icon: Icons.remove,
                    tooltip: 'Zoom out',
                    onTap: () {
                      final zoom = _mapController.camera.zoom;

                      if (zoom > 4) {
                        _mapController.move(
                          _mapController.camera.center,
                          zoom - 1,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // Recenter on the sample user position.
                  _buildFloatingMapButton(
                    icon: Icons.my_location,
                    tooltip: 'Center on my location',
                    onTap: () {
                      _mapController.move(_userCoord, 15.5);
                      _showMessage('Centered to saved map location');
                    },
                  ),
                ],
              ),
            ),

            // 3. Search bar and filters.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
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
                            IconButton(
                              icon: Stack(
                                children: [
                                  const Icon(
                                    Icons.notifications_none_outlined,
                                    color: Color(0xFF5A6B67),
                                    size: 24,
                                  ),
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: primaryGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const NotificationsPage(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 2),
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
                                child: Text(
                                  _avatarInitial(),
                                  style: const TextStyle(
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

                      // Category filters.
                      Row(
                        children: List.generate(_filters.length, (index) {
                          final isSelected =
                              _selectedFilterIndex == index;
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
                                duration:
                                    const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryGreen
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? primaryGreen
                                        : const Color(0xFFDEE5E2),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
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

            // 4. Nearest charger information card.
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
                      color: Colors.black.withValues(alpha: 0.09),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChargerDetailsPage(),
                          ),
                        );
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
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
                    ),

                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFCFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFECEFEF),
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

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ReserveSpotPage(
                                      stationName: 'Central Square Hub',
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
                              child: const Text(
                                'Reserve a spot',
                                style: TextStyle(
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
                              _mapController.move(
                                _centralHubCoord,
                                15.5,
                              );
                              _showMessage(
                                'Centered on Central Square Hub',
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

      // Bottom navigation.
      bottomNavigationBar: widget.showBottomNavBar
          ? CustomBottomNavigationBar(
              currentIndex: 0,
              onTap: (index) {
                if (index == 1 &&
                    widget.onNavigateToReport != null) {
                  widget.onNavigateToReport!();
                } else if (index == 2 &&
                    widget.onNavigateToMyReports != null) {
                  widget.onNavigateToMyReports!();
                } else if (index == 3 &&
                    widget.onNavigateToProfile != null) {
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
    final size = isHighlighted ? 46.0 : 36.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.38),
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
        color: const Color(0xFF2E6FF2).withValues(alpha: 0.22),
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
              color: const Color(0xFF2E6FF2).withValues(alpha: 0.4),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}
