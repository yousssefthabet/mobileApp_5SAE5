// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'reserve_spot_page.dart';
import 'report_trash_page.dart';

class ChargerDetailsPage extends StatelessWidget {
  final String stationName;
  final String address;
  final String distance;
  final String openingHours;
  final String pricePerKwh;
  final String maxPower;
  final String availableConnectors;

  const ChargerDetailsPage({
    super.key,
    this.stationName = 'Central Square Hub',
    this.address = 'Rue de la Liberté',
    this.distance = '350 m',
    this.openingHours = 'Open 24 hours',
    this.pricePerKwh = '[PRICE]/kWh',
    this.maxPower = '50 kW',
    this.availableConnectors = '2 of 4 free',
  });

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color badgeGreenBg = Color(0xFFE4F3EE);
  static const Color badgeGreenText = Color(0xFF0D6855);
  static const Color badgeOrangeBg = Color(0xFFFDEEE5);
  static const Color badgeOrangeText = Color(0xFFC05218);
  static const Color badgeRedBg = Color(0xFFFEECEB);
  static const Color badgeRedText = Color(0xFFD32F2F);
  static const Color backgroundColor = Color(0xFFF7F9F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Station Photo Header Area (Figure 1)
                _buildPhotoHeader(context),

                // 2. Details Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Station Title & Free Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              stationName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E2926),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: badgeGreenBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              availableConnectors,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: badgeGreenText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Location & Hours Subtitle
                      Text(
                        '$address · $distance · $openingHours',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7A8B86),
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Price and Max Power Tiles
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              label: 'PRICE',
                              value: pricePerKwh,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              label: 'MAX POWER',
                              value: maxPower,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Section Title: Connectors
                      const Text(
                        'Connectors',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E2926),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // List of Connectors (Figure 1)
                      _buildConnectorCard(
                        name: 'Connector 1',
                        typeAndPower: 'CCS · 50 kW',
                        status: 'Free',
                        statusBg: badgeGreenBg,
                        statusColor: badgeGreenText,
                        iconColor: primaryGreen,
                        iconBg: badgeGreenBg,
                      ),
                      const SizedBox(height: 10),
                      _buildConnectorCard(
                        name: 'Connector 2',
                        typeAndPower: 'CCS · 50 kW',
                        status: 'Free',
                        statusBg: badgeGreenBg,
                        statusColor: badgeGreenText,
                        iconColor: primaryGreen,
                        iconBg: badgeGreenBg,
                      ),
                      const SizedBox(height: 10),
                      _buildConnectorCard(
                        name: 'Connector 3',
                        typeAndPower: 'Type 2 · 22 kW',
                        status: 'Busy',
                        statusBg: badgeOrangeBg,
                        statusColor: badgeOrangeText,
                        iconColor: primaryGreen,
                        iconBg: badgeGreenBg,
                      ),
                      const SizedBox(height: 10),
                      _buildConnectorCard(
                        name: 'Connector 4',
                        typeAndPower: 'Type 2 · 22 kW',
                        status: 'Out of service',
                        statusBg: badgeRedBg,
                        statusColor: badgeRedText,
                        iconColor: const Color(0xFF9EA9A6),
                        iconBg: const Color(0xFFEEF2F0),
                        isOutOfService: true,
                      ),

                      const SizedBox(height: 24),

                      // Report a problem link
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReportTrashPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Report a problem with this station',
                            style: TextStyle(
                              color: primaryGreen,
                              fontSize: 14,
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

          // 3. Bottom Sticky Bar: Reserve a spot + Directions
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            'Reserve a spot',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 50,
                      height: 50,
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
                              content: Text('Opening GPS directions to Central Square Hub...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
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
      decoration: const BoxDecoration(
        color: Color(0xFFCCE4DC),
      ),
      child: Stack(
        children: [
          // Stylized placeholder graphic
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.ev_station,
                  size: 58,
                  color: primaryGreen.withOpacity(0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Station photo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E2926).withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // Top Back Button (<)
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
                    color: Color(0xFF1E2926),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECEB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF7E8F8B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E2926),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectorCard({
    required String name,
    required String typeAndPower,
    required String status,
    required Color statusBg,
    required Color statusColor,
    required Color iconColor,
    required Color iconBg,
    bool isOutOfService = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8ECEB),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bolt,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isOutOfService
                        ? const Color(0xFF869793)
                        : const Color(0xFF1E2926),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  typeAndPower,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A8B86),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
