// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

class ChargingCompletePage extends StatelessWidget {
  final String stationName;
  final String connectorName;
  final String energyKwh;
  final String durationMin;
  final String totalCost;
  final String batteryRange;
  final String co2SavedKg;

  const ChargingCompletePage({
    super.key,
    this.stationName = 'Central Square Hub',
    this.connectorName = 'Connector 1',
    this.energyKwh = '[XX] kWh',
    this.durationMin = '[XX] min',
    this.totalCost = '[PRICE]',
    this.batteryRange = '20% to 80%',
    this.co2SavedKg = '[XX]',
  });

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color lightMint = Color(0xFFD8EFE6);
  static const Color mintBadgeBg = Color(0xFFE4F3EE);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);
  static const Color backgroundColor = Color(0xFFF7F9F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with back button (optional, but convenient for testing)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 12),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: textDark),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),

                    // Mint Circle with Checkmark (Figure 2)
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: lightMint,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.check,
                        size: 36,
                        color: primaryGreen,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Charging complete',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                        letterSpacing: -0.4,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Subtitle: Central Square Hub · Connector 1
                    Text(
                      '$stationName · $connectorName',
                      style: const TextStyle(
                        fontSize: 14,
                        color: textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 2x2 Metric Cards Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'ENERGY',
                            value: energyKwh,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'TIME',
                            value: durationMin,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'TOTAL COST',
                            value: totalCost,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'BATTERY',
                            value: batteryRange,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Eco banner: Leaf icon + CO2 saved
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: mintBadgeBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.eco_outlined,
                            color: primaryGreen,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You saved $co2SavedKg kg of CO2 compared to petrol',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D6855),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Bottom Buttons: Download receipt + Done (Figure 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Receipt downloaded successfully (PDF)'),
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
                          'Download receipt',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
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
                          'Done',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }

  Widget _buildMetricTile({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              color: textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }
}
