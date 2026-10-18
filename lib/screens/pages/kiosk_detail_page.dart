
 // ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class KioskDetailPage extends StatelessWidget {
  final String kioskName;
  final String address;
  final String distance;
  final String openingHoursText;
  final double? latitude;
  final double? longitude;

  const KioskDetailPage({
    super.key,
    this.kioskName = 'Central Square Kiosk',
    this.address = 'Rue de la Liberté',
    this.distance = '350 m',
    this.openingHoursText = 'Mon to Sun · 07:00 to 22:00',
    this.latitude,
    this.longitude,
  });

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);
  static const Color cardBorder = Color(0xFFE8ECEB);
  static const Color backgroundColor = Color(0xFFF7F9F8);

  Future<void> _getDirections(BuildContext context) async {
    if (latitude == null || longitude == null) {
      _showMessage(context, 'This kiosk has no valid GPS coordinates.');
      return;
    }

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage(
          context,
          'Please enable your device location and try again.',
        );
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage(context, 'Location permission was denied.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          context,
          'Enable location permission in your app settings.',
        );
        await Geolocator.openAppSettings();
        return;
      }

      // Get the device's real current position.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Open Google Maps with the actual origin and kiosk destination.
      final url = Uri.https(
        'www.google.com',
        '/maps/dir/',
        {
          'api': '1',
          'origin':
              '${position.latitude},${position.longitude}',
          'destination': '$latitude,$longitude',
          'travelmode': 'driving',
          'dir_action': 'navigate',
        },
      );

      final opened = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showMessage(context, 'Unable to open Google Maps.');
      }
    } catch (e) {
      _showMessage(
        context,
        'Could not get your location. Please try again.',
      );
      debugPrint('Directions error: $e');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
                        kioskName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$address · $distance',
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
                              openingHoursText,
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
                    color: Colors.black.withOpacity(0.06),
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
                          onPressed: () => _getDirections(context),
                          icon: const Icon(Icons.directions),
                          label: const Text(
                            'Get directions',
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
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      height: 50,
                      width: 90,
                      child: OutlinedButton(
                        onPressed: () {
                          _showMessage(
                            context,
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
                  color: primaryGreen.withOpacity(0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kiosk photo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textDark.withOpacity(0.7),
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
                        color: Colors.black.withOpacity(0.12),
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
