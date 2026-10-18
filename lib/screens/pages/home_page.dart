
 // ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:chargi/widgets/BottomNavigationBar.dart';

import 'charger_details_page.dart';
import 'kiosk_detail_page.dart';
import 'report_trash_page.dart';
import 'notifications_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onNavigateToReport;
  final VoidCallback? onNavigateToMyReports;
  final bool showBottomNavBar;
  final LatLng? focusCoord;
  final int? initialFilterIndex;
  final Map<String, dynamic>? pendingTrashReport;

  const HomePage({
    super.key,
    this.onNavigateToProfile,
    this.onNavigateToReport,
    this.onNavigateToMyReports,
    this.showBottomNavBar = true,
    this.focusCoord,
    this.initialFilterIndex,
    this.pendingTrashReport,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color blueKioskColor = Color(0xFF1E63B8);
  static const Color orangeTrashColor = Color(0xFFC35624);

  static const LatLng _userCoord = LatLng(36.8040, 10.1790);
  static const LatLng _centralHubCoord = LatLng(36.8065, 10.1815);

  late final MapController _mapController;

  int _selectedFilterIndex = 0;
  bool _isSatellite = false;

  List<Map<String, dynamic>> _chargers = [];
  List<Map<String, dynamic>> _kiosks = [];
  List<Map<String, dynamic>> _reports = [];

  String? _selectedChargerId;
  String? _selectedKioskId;
  Map<String, dynamic>? _selectedReport;

  String? _chargerError;
  String? _kioskError;

  @override
  void initState() {
    super.initState();

    _mapController = MapController();
    _selectedFilterIndex =
        widget.initialFilterIndex ?? (widget.focusCoord != null ? 2 : 0);
    _selectedReport = widget.pendingTrashReport;

    _listenToChargers();
    _listenToKiosks();
    _listenToReports();

    if (widget.focusCoord != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(widget.focusCoord!, 16);
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _listenToChargers() {
    FirebaseFirestore.instance
        .collection('ev_chargers')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;

        setState(() {
          _chargers = snapshot.docs.map((doc) {
            return {
              ...doc.data(),
              'id': doc.id,
            };
          }).where((charger) {
            return charger['latitude'] is num &&
                charger['longitude'] is num;
          }).toList();

          _chargerError = null;
        });
      },
      onError: (Object error) {
        debugPrint('Error loading chargers: $error');
        if (mounted) {
          setState(() {
            _chargerError = 'Unable to load EV chargers from Firebase.';
          });
        }
      },
    );
  }

  void _listenToKiosks() {
    FirebaseFirestore.instance
        .collection('kiosk')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;

        setState(() {
          _kiosks = snapshot.docs.map((doc) {
            return {
              ...doc.data(),
              'id': doc.id,
            };
          }).where((kiosk) {
            return kiosk['latitude'] is num &&
                kiosk['longitude'] is num;
          }).toList();

          _kioskError = null;
        });
      },
      onError: (Object error) {
        debugPrint('Error loading kiosks: $error');
        if (mounted) {
          setState(() {
            _kioskError = 'Unable to load kiosks from Firebase.';
          });
        }
      },
    );
  }

  void _listenToReports() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('reports')
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;

        setState(() {
          _reports = snapshot.docs.map((doc) {
            return {
              ...doc.data(),
              'docId': doc.id,
            };
          }).where((report) {
            return report['latitude'] is num &&
                report['longitude'] is num;
          }).toList();
        });
      },
      onError: (Object error) {
        debugPrint('Error loading reports: $error');
      },
    );
  }

  String _name(Map<String, dynamic> item) =>
      item['name']?.toString() ?? 'Unnamed station';

  String _price(Map<String, dynamic> charger) {
    final price = charger['price'];
    return price is num ? '${price.toStringAsFixed(3)} / kWh' : 'Unavailable';
  }

  String _power(Map<String, dynamic> charger) {
    final power = charger['maxPower'];
    return power is num ? '${power.toStringAsFixed(0)} kW' : 'N/A';
  }

  int _freeConnectors(Map<String, dynamic> charger) {
    final connectors = charger['connectors'];

    if (connectors is List) {
      return connectors.where((item) {
        if (item is! Map) return false;
        return item['status']?.toString().toLowerCase() == 'free';
      }).length;
    }

    return 0;
  }

  double _distance(LatLng point) {
    return const Distance().as(LengthUnit.Meter, _userCoord, point);
  }

  String _distanceLabel(LatLng point) {
    final meters = _distance(point);
    return meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Map<String, dynamic>? get _selectedCharger {
    for (final charger in _chargers) {
      if (charger['id'] == _selectedChargerId) return charger;
    }
    return _chargers.isEmpty ? null : _chargers.first;
  }

  Map<String, dynamic>? get _selectedKiosk {
    for (final kiosk in _kiosks) {
      if (kiosk['id'] == _selectedKioskId) return kiosk;
    }
    return _kiosks.isEmpty ? null : _kiosks.first;
  }

  void _openCharger(Map<String, dynamic> charger) {
    final coord = LatLng(
      (charger['latitude'] as num).toDouble(),
      (charger['longitude'] as num).toDouble(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChargerDetailsPage(
          // Important: use the actual Firestore document ID.
          chargerId: charger['id'] as String,
          stationName: _name(charger),
          distance: _distanceLabel(coord),
          pricePerKwh: _price(charger),
          maxPower: _power(charger),
          availableConnectors: '${_freeConnectors(charger)} free',
          stationPhoto: charger['stationPhoto'] as String?,
        ),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[
      Marker(
        point: _userCoord,
        width: 32,
        height: 32,
        child: const Icon(
          Icons.my_location,
          color: Colors.blue,
          size: 28,
        ),
      ),
    ];

    if (_selectedFilterIndex == 0) {
      for (final charger in _chargers) {
        final coord = LatLng(
          (charger['latitude'] as num).toDouble(),
          (charger['longitude'] as num).toDouble(),
        );

        markers.add(
          Marker(
            point: coord,
            width: 46,
            height: 46,
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedChargerId = charger['id'] as String);
                _mapController.move(coord, 15.5);
                _openCharger(charger);
              },
              child: const Icon(
                Icons.ev_station,
                color: primaryGreen,
                size: 38,
              ),
            ),
          ),
        );
      }
    } else if (_selectedFilterIndex == 1) {
      for (final kiosk in _kiosks) {
        final coord = LatLng(
          (kiosk['latitude'] as num).toDouble(),
          (kiosk['longitude'] as num).toDouble(),
        );

        markers.add(
          Marker(
            point: coord,
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedKioskId = kiosk['id'] as String);
                _mapController.move(coord, 15.5);
              },
              child: const Icon(
                Icons.storefront,
                color: blueKioskColor,
                size: 36,
              ),
            ),
          ),
        );
      }
    } else {
      for (final report in _reports) {
        final coord = LatLng(
          (report['latitude'] as num).toDouble(),
          (report['longitude'] as num).toDouble(),
        );

        markers.add(
          Marker(
            point: coord,
            width: 42,
            height: 42,
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedReport = report);
                _mapController.move(coord, 16);
              },
              child: const Icon(
                Icons.delete_outline,
                color: orangeTrashColor,
                size: 34,
              ),
            ),
          ),
        );
      }

      final focus = widget.focusCoord;
      if (focus != null) {
        markers.add(
          Marker(
            point: focus,
            width: 42,
            height: 42,
            child: const Icon(
              Icons.delete_outline,
              color: orangeTrashColor,
              size: 36,
            ),
          ),
        );
      }
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('EV', Icons.bolt),
      ('Kiosks', Icons.storefront_outlined),
      ('Reports', Icons.delete_outline),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.focusCoord ?? _centralHubCoord,
              initialZoom: widget.focusCoord != null ? 16 : 12.5,
              minZoom: 3,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.chargi',
                maxZoom: 19,
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search chargers, kiosks, reports',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.notifications_none),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsPage(),
                              ),
                            );
                          },
                        ),
                        GestureDetector(
                          onTap: widget.onNavigateToProfile,
                          child: CircleAvatar(
                            backgroundColor: primaryGreen,
                            child: Text(
                              (FirebaseAuth.instance.currentUser?.displayName ??
                                      FirebaseAuth.instance.currentUser?.email ??
                                      'U')[0]
                                  .toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(filters.length, (index) {
                      final selected = index == _selectedFilterIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filters[index].$1),
                          avatar: Icon(
                            filters[index].$2,
                            size: 17,
                            color: selected ? Colors.white : Colors.black87,
                          ),
                          selected: selected,
                          selectedColor: index == 2
                              ? orangeTrashColor
                              : primaryGreen,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedFilterIndex = index);
                          },
                        ),
                      );
                    }),
                  ),
                  if (_selectedFilterIndex == 0)
                    _banner(
                      _chargerError ??
                          '${_chargers.length} active EV charger(s) loaded',
                      primaryGreen,
                    ),
                  if (_selectedFilterIndex == 1)
                    _banner(
                      _kioskError ?? '${_kiosks.length} active kiosk(s) loaded',
                      blueKioskColor,
                    ),
                ],
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              children: [
                _mapButton(
                  _isSatellite ? Icons.map_outlined : Icons.layers_outlined,
                  () => setState(() => _isSatellite = !_isSatellite),
                ),
                const SizedBox(height: 8),
                _mapButton(Icons.add, () {
                  final camera = _mapController.camera;
                  _mapController.move(camera.center, camera.zoom + 1);
                }),
                const SizedBox(height: 8),
                _mapButton(Icons.remove, () {
                  final camera = _mapController.camera;
                  _mapController.move(camera.center, camera.zoom - 1);
                }),
                const SizedBox(height: 8),
                _mapButton(Icons.my_location, () {
                  _mapController.move(_userCoord, 15);
                }),
              ],
            ),
          ),

          if (_selectedFilterIndex == 0 && _selectedCharger != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: _chargerCard(_selectedCharger!),
            ),

          if (_selectedFilterIndex == 1 && _selectedKiosk != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: _kioskCard(_selectedKiosk!),
            ),

          if (_selectedFilterIndex == 2)
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: _reportCard(),
            ),
        ],
      ),
      bottomNavigationBar: widget.showBottomNavBar
          ? CustomBottomNavigationBar(
              currentIndex: 0,
              onTap: (index) {
                if (index == 1) widget.onNavigateToReport?.call();
                if (index == 2) widget.onNavigateToMyReports?.call();
                if (index == 3) widget.onNavigateToProfile?.call();
              },
            )
          : null,
    );
  }

  Widget _banner(String message, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _mapButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: const Color(0xFF283230)),
      ),
    );
  }

  Widget _chargerCard(Map<String, dynamic> charger) {
    final coord = LatLng(
      (charger['latitude'] as num).toDouble(),
      (charger['longitude'] as num).toDouble(),
    );
    final photo = charger['stationPhoto']?.toString() ?? '';

    return _bottomCard(
      title: _name(charger),
      subtitle:
          '${_distanceLabel(coord)} • ${_freeConnectors(charger)} free connector(s)',
      leading: photo.isNotEmpty
          ? Image.network(
              photo,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.ev_station, size: 45),
            )
          : const Icon(Icons.ev_station, size: 45, color: primaryGreen),
      details: '${_power(charger)} • ${_price(charger)}',
      buttonLabel: 'View charger details',
      onPressed: () => _openCharger(charger),
    );
  }

  Widget _kioskCard(Map<String, dynamic> kiosk) {
    final coord = LatLng(
      (kiosk['latitude'] as num).toDouble(),
      (kiosk['longitude'] as num).toDouble(),
    );

    return _bottomCard(
      title: _name(kiosk),
      subtitle: kiosk['address']?.toString() ?? _distanceLabel(coord),
      leading: const Icon(
        Icons.storefront,
        size: 45,
        color: blueKioskColor,
      ),
      details: kiosk['openingHoursText']?.toString() ?? 'Hours unavailable',
      buttonLabel: 'View kiosk details',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => KioskDetailPage(
              kioskName: _name(kiosk),
              address: kiosk['address']?.toString() ?? 'Address unavailable',
              distance: _distanceLabel(coord),
              openingHoursText:
                  kiosk['openingHoursText']?.toString() ?? 'Hours unavailable',
              latitude: coord.latitude,
              longitude: coord.longitude,
              allKiosks: _kiosks,
            ),
          ),
        );
      },
    );
  }

  Widget _reportCard() {
    final report = _selectedReport ??
        (widget.pendingTrashReport ?? (_reports.isNotEmpty ? _reports.first : null));

    if (report == null) {
      return _bottomCard(
        title: 'Trash reports',
        subtitle: 'Select a report on the map',
        leading: const Icon(
          Icons.delete_outline,
          size: 45,
          color: orangeTrashColor,
        ),
        details: 'Help keep your area clean.',
        buttonLabel: 'Report trash',
        onPressed: () {
          if (widget.onNavigateToReport != null) {
            widget.onNavigateToReport!();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportTrashPage()),
            );
          }
        },
      );
    }

    return _bottomCard(
      title: report['problemTitle']?.toString() ?? 'Trash report',
      subtitle: report['location']?.toString() ?? 'Selected location',
      leading: const Icon(
        Icons.delete_outline,
        size: 45,
        color: orangeTrashColor,
      ),
      details: report['status']?.toString() ?? 'Report selected',
      buttonLabel: 'Report trash',
      onPressed: () {
        if (widget.onNavigateToReport != null) {
          widget.onNavigateToReport!();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportTrashPage()),
          );
        }
      },
    );
  }

  Widget _bottomCard({
    required String title,
    required String subtitle,
    required Widget leading,
    required String details,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(width: 64, height: 64, child: leading),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
