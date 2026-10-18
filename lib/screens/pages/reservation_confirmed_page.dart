// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  final String? reservationId;
  final String? amount;
  final String? qrData;

  const ReservationConfirmedPage({
    super.key,
    this.stationName = 'Central Square Hub',
    this.connectorInfo = '1 · CCS',
    this.timeSlot = 'Today 10:30, 1 hour',
    this.heldFor = 'Confirmed',
    this.reservationId,
    this.amount,
    this.qrData,
  });

  @override
  State<ReservationConfirmedPage> createState() => _ReservationConfirmedPageState();
}

class _ReservationConfirmedPageState extends State<ReservationConfirmedPage> {
  String get _effectiveQrData {
    if (widget.qrData != null && widget.qrData!.trim().isNotEmpty) {
      return widget.qrData!;
    }
    final buffer = StringBuffer();
    buffer.writeln('=== CHARGI EV RESERVATION PASS ===');
    if (widget.reservationId != null && widget.reservationId!.isNotEmpty) {
      buffer.writeln('Pass ID: ${widget.reservationId}');
    }
    buffer.writeln('Station: ${widget.stationName}');
    buffer.writeln('Connector: ${widget.connectorInfo}');
    buffer.writeln('Time: ${widget.timeSlot}');
    buffer.writeln('Status: ${widget.heldFor}');
    if (widget.amount != null && widget.amount!.isNotEmpty) {
      buffer.writeln('Total: ${widget.amount}');
    }
    buffer.writeln('Scan at charger to authenticate');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        foregroundColor: _textDark,
        title: const Text(
          'Reservation Pass',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.map, size: 18, color: _primaryGreen),
            label: const Text(
              'Map',
              style: TextStyle(
                color: _primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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
                      'Reservation accepted',
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
                      'Spot reserved · Scan this code at the charger to start.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: _textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 2. Real Scannable QR Code
                    Container(
                      width: 190,
                      height: 190,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: QrImageView(
                          data: _effectiveQrData,
                          version: QrVersions.auto,
                          size: 166,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF16382F),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF16382F),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Scannable caption
                    const Text(
                      'Scan this QR code to view reservation details',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textMuted,
                        fontWeight: FontWeight.w500,
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
                          if (widget.reservationId != null && widget.reservationId!.isNotEmpty) ...[
                            _buildDetailRow(
                              'Pass ID',
                              '#${widget.reservationId!.substring(0, widget.reservationId!.length > 8 ? 8 : widget.reservationId!.length)}',
                            ),
                            const SizedBox(height: 12),
                          ],
                          _buildDetailRow('Station', widget.stationName),
                          const SizedBox(height: 12),
                          _buildDetailRow('Connector', widget.connectorInfo),
                          const SizedBox(height: 12),
                          _buildDetailRow('Time', widget.timeSlot),
                          const SizedBox(height: 12),
                          _buildDetailRow('Status', widget.heldFor),
                          if (widget.amount != null && widget.amount!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow('Total', widget.amount!),
                          ],
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

            // 4. Bottom Action Buttons: Navigate to map, Directions, Cancel
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text(
                        'Navigate to map',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Starting GPS navigation to ${widget.stationName}...'),
                                  backgroundColor: _primaryGreen,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.navigation_outlined, size: 18),
                            label: const Text(
                              'Directions',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _primaryGreen, width: 1.5),
                              foregroundColor: _primaryGreen,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 46,
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
                              side: BorderSide(color: Colors.grey.shade400, width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
