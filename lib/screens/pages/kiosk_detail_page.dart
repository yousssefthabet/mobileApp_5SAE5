// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

class KioskDetailPage extends StatelessWidget {
  final String kioskName;
  final String address;
  final String distance;
  final String openingHoursText;

  const KioskDetailPage({
    super.key,
    this.kioskName = 'Central Square Kiosk',
    this.address = 'Rue de la Liberté',
    this.distance = '350 m',
    this.openingHoursText = 'Mon to Sun · 07:00 to 22:00',
  });

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);
  static const Color cardBorder = Color(0xFFE8ECEB);
  static const Color backgroundColor = Color(0xFFF7F9F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Kiosk Photo Header Area (Figure 3)
                _buildPhotoHeader(context),

                // 2. Info Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
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

                      // Location & Hours
                      Text(
                        '$address · $distance · Open until 22:00',
                        style: const TextStyle(
                          fontSize: 13,
                          color: textMuted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Services Card (Figure 3)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cardBorder, width: 1),
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
                            _buildServiceRow('Drinks and snacks', 'Available'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: Color(0xFFF0F4F2), height: 1),
                            ),
                            _buildServiceRow('Transport tickets', 'Available'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: Color(0xFFF0F4F2), height: 1),
                            ),
                            _buildServiceRow('Phone charging', 'Available'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Opening Hours Card (Figure 3)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cardBorder, width: 1),
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
                                fontWeight: FontWeight.w500,
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

          // 3. Bottom Sticky Bar: Get directions + Call (Figure 3)
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Opening directions to $kioskName...'),
                                duration: const Duration(seconds: 2),
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
                            'Get directions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Calling kiosk: +216 71 123 456'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: primaryGreen, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          backgroundColor: Colors.white,
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
      decoration: const BoxDecoration(
        color: Color(0xFFCCE4DC),
      ),
      child: Stack(
        children: [
          // Illustration / Label
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
