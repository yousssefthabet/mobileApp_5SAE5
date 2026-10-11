// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'charging_complete_page.dart';

const Color _primaryGreen = Color(0xFF086B5B);
const Color _lightMint = Color(0xFFD8EFE6);
const Color _textDark = Color(0xFF1E2926);
const Color _textMuted = Color(0xFF7A8B86);
const Color _cardBorder = Color(0xFFE8ECEB);
const Color _backgroundColor = Color(0xFFF7F9F8);

class ReservationConfirmedPage extends StatefulWidget {
  final String stationName;
  final String connectorInfo;
  final String timeSlot;
  final String heldFor;

  const ReservationConfirmedPage({
    super.key,
    this.stationName = 'Central Square Hub',
    this.connectorInfo = '1 · CCS',
    this.timeSlot = 'Today 10:30, 1 hour',
    this.heldFor = '14:52',
  });

  @override
  State<ReservationConfirmedPage> createState() => _ReservationConfirmedPageState();
}

class _ReservationConfirmedPageState extends State<ReservationConfirmedPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),

                    // 1. Success Mint Circle Checkmark (Figure 8)
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: _lightMint,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.check,
                        size: 38,
                        color: _primaryGreen,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'Spot reserved',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                        letterSpacing: -0.4,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Subtitle
                    const Text(
                      'Scan this code at the charger to start.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: _textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 2. Stylized QR Code (Figure 8)
                    Container(
                      width: 170,
                      height: 170,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        painter: _StylizedQrPainter(color: const Color(0xFF16382F)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Sample code caption
                    const Text(
                      'Sample code, not a real QR',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textMuted,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 3. Reservation Details Card (Figure 8)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _cardBorder, width: 1),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Station', widget.stationName),
                          const SizedBox(height: 12),
                          _buildDetailRow('Connector', widget.connectorInfo),
                          const SizedBox(height: 12),
                          _buildDetailRow('Time', widget.timeSlot),
                          const SizedBox(height: 12),
                          _buildDetailRow('Held for', widget.heldFor),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Demo Shortcut to complete charging
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChargingCompletePage(
                              stationName: widget.stationName,
                              connectorName: 'Connector 1',
                              energyKwh: '32 kWh',
                              durationMin: '45 min',
                              totalCost: '14.50 DT',
                              batteryRange: '20% to 80%',
                              co2SavedKg: '6.8',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.flash_on, size: 16, color: _primaryGreen),
                      label: const Text(
                        'Simulate Session Complete',
                        style: TextStyle(
                          color: _primaryGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Bottom Action Buttons: Directions + Cancel (Figure 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Starting GPS navigation to ${widget.stationName}...'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Directions',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Cancel Reservation?'),
                              content: const Text(
                                'Are you sure you want to cancel your held spot?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Keep Spot'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    Navigator.of(context).popUntil((route) => route.isFirst);
                                  },
                                  child: const Text(
                                    'Cancel Reservation',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _primaryGreen, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _primaryGreen,
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: _textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
      ],
    );
  }
}

/// Stylized pixel-matrix QR code matching Figure 8
class _StylizedQrPainter extends CustomPainter {
  final Color color;

  _StylizedQrPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final double block = size.width / 11;

    // Pattern matrix matching the sample QR in figure 8
    final matrix = [
      [1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1],
      [1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1],
      [1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1],
      [0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0],
      [1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0],
      [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1],
      [1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1],
      [0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0],
      [1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1],
      [1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1],
      [1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1],
    ];

    for (int r = 0; r < matrix.length; r++) {
      for (int c = 0; c < matrix[r].length; c++) {
        if (matrix[r][c] == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * block + 1, r * block + 1, block - 2, block - 2),
              const Radius.circular(2),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
