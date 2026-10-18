// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KioskDetailPage extends StatefulWidget {
  final String kioskName;
  final String address;
  final String distance;
  final String openingHoursText;
  final double? latitude;
  final double? longitude;
  final List<Map<String, dynamic>>? allKiosks;

  const KioskDetailPage({
    super.key,
    this.kioskName = 'Central Square Kiosk',
    this.address = 'Rue de la Liberté',
    this.distance = '350 m',
    this.openingHoursText = 'Mon to Sun · 07:00 to 22:00',
    this.latitude,
    this.longitude,
    this.allKiosks,
  });

  @override
  State<KioskDetailPage> createState() => _KioskDetailPageState();
}

class _KioskDetailPageState extends State<KioskDetailPage> {
  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);
  static const Color cardBorder = Color(0xFFE8ECEB);
  static const Color backgroundColor = Color(0xFFF7F9F8);

  bool _isLocating = false;

  Future<void> _getDirectionsToNearestKiosk() async {
    if (_isLocating) return;

    setState(() => _isLocating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _showMessage('Please enable location services on your device.');
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        _showMessage('Location permission was denied.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showMessage('Please enable location permission in app settings.');
        await Geolocator.openAppSettings();
        return;
      }

      // Get real device position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Collect all kiosks from widget prop or Firestore
      List<Map<String, dynamic>> kioskList = [];

      if (widget.allKiosks != null && widget.allKiosks!.isNotEmpty) {
        kioskList = List<Map<String, dynamic>>.from(widget.allKiosks!);
      } else {
        try {
          final snapshot =
              await FirebaseFirestore.instance.collection('kiosk').get();
          kioskList = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        } catch (e) {
          debugPrint('Error fetching kiosks: $e');
        }
      }

      // Find the nearest kiosk based on user location
      Map<String, dynamic>? nearestKiosk;
      double minDistance = double.infinity;

      for (final k in kioskList) {
        final lat = k['latitude'];
        final lng = k['longitude'];
        if (lat is num && lng is num) {
          final dist = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            lat.toDouble(),
            lng.toDouble(),
          );
          if (dist < minDistance) {
            minDistance = dist;
            nearestKiosk = k;
          }
        }
      }

      final double destLat;
      final double destLng;
      final String destName;

      if (nearestKiosk != null) {
        destLat = (nearestKiosk['latitude'] as num).toDouble();
        destLng = (nearestKiosk['longitude'] as num).toDouble();
        destName = nearestKiosk['name']?.toString() ??
            nearestKiosk['kioskName']?.toString() ??
            nearestKiosk['title']?.toString() ??
            'Nearest Kiosk';
      } else if (widget.latitude != null && widget.longitude != null) {
        destLat = widget.latitude!;
        destLng = widget.longitude!;
        destName = widget.kioskName;
        minDistance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          destLat,
          destLng,
        );
      } else {
        if (!mounted) return;
        _showMessage('No kiosk coordinates found.');
        return;
      }

      final distLabel = minDistance < 1000
          ? '${minDistance.round()} m'
          : '${(minDistance / 1000).toStringAsFixed(1)} km';

      if (!mounted) return;
      _showMessage('Navigating to nearest kiosk: $destName ($distLabel)');

      // Open Google Maps navigation with origin and nearest kiosk destination
      final nativeNavUrl = Uri.parse(
        'google.navigation:q=$destLat,$destLng&mode=d',
      );

      bool opened = false;
      try {
        if (await canLaunchUrl(nativeNavUrl)) {
          opened = await launchUrl(
            nativeNavUrl,
            mode: LaunchMode.externalApplication,
          );
        }
      } catch (_) {}

      if (!opened) {
        final webUrl = Uri.https(
          'www.google.com',
          '/maps/dir/',
          {
            'api': '1',
            'origin': '${position.latitude},${position.longitude}',
            'destination': '$destLat,$destLng',
            'travelmode': 'driving',
            'dir_action': 'navigate',
          },
        );

        opened = await launchUrl(
          webUrl,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!opened && mounted) {
        _showMessage('Unable to open navigation application.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Could not get your location. Please try again.');
      }
      debugPrint('Directions error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhotoHeader(context),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.kioskName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.address} · ${widget.distance}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Services',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textDark,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildServiceRow(
                              'Drinks and snacks',
                              'Available',
                            ),
                            const Divider(height: 25),
                            _buildServiceRow(
                              'Transport tickets',
                              'Available',
                            ),
                            const Divider(height: 25),
                            _buildServiceRow(
                              'Phone charging',
                              'Available',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Opening hours',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textDark,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.openingHoursText,
                              style: const TextStyle(
                                fontSize: 14,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isLocating ? null : _getDirectionsToNearestKiosk,
                          icon: _isLocating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.directions),
                          label: Text(
                            _isLocating ? 'Locating...' : 'Get directions',
                            style: const TextStyle(
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
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      height: 50,
                      width: 90,
                      child: OutlinedButton(
                        onPressed: () {
                          _showMessage(
                            'Add the kiosk phone number to enable calling.',
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: primaryGreen,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Call',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoHeader(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      color: const Color(0xFFCCE4DC),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 58,
                  color: primaryGreen.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kiosk photo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textDark.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: textDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceRow(String name, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF33423E),
          ),
        ),
        Text(
          status,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textMuted,
          ),
        ),
      ],
    );
  }
}
