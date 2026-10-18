
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'reserve_spot_page.dart';

class ChargerDetailsPage extends StatelessWidget {
  final String? chargerId;
  final String stationName;
  final String address;
  final String distance;
  final String openingHours;
  final String pricePerKwh;
  final String maxPower;
  final String availableConnectors;
  final String? stationPhoto;

  const ChargerDetailsPage({
    super.key,
    this.chargerId,
    required this.stationName,
    this.address = 'Address unavailable',
    this.distance = '—',
    this.openingHours = 'Open 24/7',
    this.pricePerKwh = '—',
    this.maxPower = '—',
    this.availableConnectors = '—',
    this.stationPhoto,
  });

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color badgeGreenBg = Color(0xFFE2F3EB);
  static const Color badgeGreenText = Color(0xFF0D6855);
  static const Color badgeOrangeBg = Color(0xFFFFF0DF);
  static const Color badgeOrangeText = Color(0xFFB85D0B);
  static const Color badgeRedBg = Color(0xFFFFE8E6);
  static const Color badgeRedText = Color(0xFFB42318);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: const Color(0xFF1E2926),
        title: const Text(
          'Charger details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 190,
              child: stationPhoto != null && stationPhoto!.trim().isNotEmpty
                  ? Image.network(
                      stationPhoto!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _photoPlaceholder(),
                    )
                  : _photoPlaceholder(),
            ),
          ),
          const SizedBox(height: 18),

          Text(
            stationName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2926),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$address\n$distance',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF71817C),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _infoCard(
                  icon: Icons.bolt,
                  label: 'MAX POWER',
                  value: maxPower,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoCard(
                  icon: Icons.payments_outlined,
                  label: 'PRICE',
                  value: pricePerKwh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.access_time,
            label: 'OPENING HOURS',
            value: openingHours,
          ),
          const SizedBox(height: 24),

          const Text(
            'Available connectors',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2926),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Connector availability is loaded directly from Firebase.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF71817C),
            ),
          ),
          const SizedBox(height: 14),

          _buildConnectors(),

          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Directions can be added to your in-app map.'),
                  ),
                );
              },
              icon: const Icon(Icons.near_me_outlined),
              label: const Text('Get directions'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryGreen,
                side: const BorderSide(color: primaryGreen),
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

  Widget _buildConnectors() {
    if (chargerId == null || chargerId!.isEmpty) {
      return _messageCard(
        'Charger ID is missing. Open this page from a charger in the map.',
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ev_chargers')
          .doc(chargerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _messageCard(
            'Could not load connectors. Check your Firebase rules and connection.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data();

        if (data == null) {
          return _messageCard('This charger was not found in Firebase.');
        }

        final rawConnectors = data['connectors'];

        if (rawConnectors is! List || rawConnectors.isEmpty) {
          return _messageCard('No connectors have been added to this charger.');
        }

        final connectors = rawConnectors
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        if (connectors.isEmpty) {
          return _messageCard('No valid connector records were found.');
        }

        return Column(
          children: connectors.asMap().entries.map((entry) {
            final index = entry.key;
            final connector = entry.value;

            final id =
                (connector['connectorId'] as num?)?.toInt() ?? index + 1;
            final type = connector['type']?.toString() ?? 'Unknown type';
            final power = connector['power'] is num
                ? (connector['power'] as num).toStringAsFixed(0)
                : '—';
            final status =
                (connector['status']?.toString() ?? 'unknown').toLowerCase();

            final isFree = status == 'free';
            final isOutOfService = status == 'out_of_service';

            final statusText = switch (status) {
              'free' => 'Free',
              'busy' => 'Busy',
              'out_of_service' => 'Out of service',
              _ => 'Unavailable',
            };

            final statusBackground = isFree
                ? badgeGreenBg
                : isOutOfService
                    ? badgeRedBg
                    : badgeOrangeBg;

            final statusForeground = isFree
                ? badgeGreenText
                : isOutOfService
                    ? badgeRedText
                    : badgeOrangeText;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFE5EBE8)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isOutOfService
                          ? const Color(0xFFEEF2F0)
                          : badgeGreenBg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.ev_station,
                      color: isOutOfService
                          ? const Color(0xFF9EA9A6)
                          : primaryGreen,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connector $id',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E2926),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$type · $power kW',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF71817C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusBackground,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusForeground,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isFree)
                    SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ReserveSpotPage(
        chargerId: chargerId!,
        stationName: stationName,
        initialConnectorIndex: index,
      ),
    ),
  );
},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Reserve',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF9EA9A6),
                      size: 20,
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: const Color(0xFFE2EFEA),
      alignment: Alignment.center,
      child: const Icon(
        Icons.ev_station,
        color: primaryGreen,
        size: 70,
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EBE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryGreen, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF71817C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2926),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE5EBE8)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF52635D)),
      ),
    );
  }
}
