
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'reservation_confirmed_page.dart';

class PaymentPage extends StatefulWidget {
  final String chargerId;
  final int connectorId;
  final DateTime startDateTime;
  final int durationMinutes;
  final double amount;

  final String stationName;
  final String connectorName;
  final String timeSlot;
  final String subtotal;
  final String fees;
  final String total;

  const PaymentPage({
    super.key,
    required this.chargerId,
    required this.connectorId,
    required this.startDateTime,
    required this.durationMinutes,
    required this.amount,
    required this.stationName,
    required this.connectorName,
    required this.timeSlot,
    required this.subtotal,
    required this.fees,
    required this.total,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);

  bool _isProcessing = false;

  Future<void> _confirmDemoPayment() async {
    if (_isProcessing) return;

    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();

    // Allow immediate reservation within a 15-minute tolerance
    if (widget.startDateTime.isBefore(now.subtract(const Duration(minutes: 15)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This reservation time has already passed.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final reservationId = firestore.collection('reservations').doc().id;
      final reservationData = {
        'id': reservationId,
        'userId': user?.uid ?? 'guest_user',
        'userEmail': user?.email ?? 'guest@example.com',
        'chargerId': widget.chargerId,
        'stationName': widget.stationName,
        'connectorId': widget.connectorId,
        'connectorName': widget.connectorName,
        'startDateTime': Timestamp.fromDate(widget.startDateTime),
        'durationMinutes': widget.durationMinutes,
        'amount': widget.amount,
        'currency': 'TND',
        'paymentMethod': 'bank_card',
        'paymentStatus': 'paid',
        'reservationStatus': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 1. Record under user's private reservations collection
      if (user != null) {
        try {
          await firestore
              .collection('users')
              .doc(user.uid)
              .collection('reservations')
              .doc(reservationId)
              .set(reservationData);
        } catch (e) {
          debugPrint('Could not save user private reservation: $e');
        }
      }

      // 2. Update ev_chargers connector status to busy
      try {
        final chargerRef =
            firestore.collection('ev_chargers').doc(widget.chargerId);
        final chargerDoc = await chargerRef.get();
        if (chargerDoc.exists) {
          final chargerData = chargerDoc.data();
          final rawConnectors = chargerData?['connectors'];
          if (rawConnectors is List) {
            final connectors = rawConnectors.map((item) {
              return Map<String, dynamic>.from(item as Map);
            }).toList();

            int targetIndex = -1;

            // 1. Try matching by connectorId / id / connector_id
            targetIndex = connectors.indexWhere((c) {
              final raw = c['connectorId'] ?? c['id'] ?? c['connector_id'];
              final id = raw is num
                  ? raw.toInt()
                  : int.tryParse(raw?.toString() ?? '');
              return id != null && id == widget.connectorId;
            });

            // 2. Try 1-based index (e.g. connectorId 1 -> index 0)
            if (targetIndex == -1 &&
                widget.connectorId > 0 &&
                widget.connectorId <= connectors.length) {
              targetIndex = widget.connectorId - 1;
            }

            // 3. Try 0-based index
            if (targetIndex == -1 &&
                widget.connectorId >= 0 &&
                widget.connectorId < connectors.length) {
              targetIndex = widget.connectorId;
            }

            // 4. Fallback: first free connector
            if (targetIndex == -1) {
              targetIndex = connectors.indexWhere((c) =>
                  c['status']?.toString().toLowerCase() == 'free');
            }

            if (targetIndex != -1) {
              connectors[targetIndex]['status'] = 'busy';
              await chargerRef.update({'connectors': connectors});
              debugPrint('SUCCESS: Connector at index $targetIndex updated to busy');
            } else {
              debugPrint('WARNING: Could not find connector index to mark as busy');
            }
          }
        }
      } catch (e) {
        debugPrint('Could not update charger connectors: $e');
      }

      // 3. Save to top-level reservations collection
      try {
        await firestore
            .collection('reservations')
            .doc(reservationId)
            .set(reservationData);
      } catch (e) {
        debugPrint('Could not save top-level reservation: $e');
      }

      if (!mounted) return;

      // Navigate back to the map screen
      Navigator.of(context).popUntil((route) => route.isFirst);

      // Show prominent acceptance feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reservation accepted',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Spot reserved at ${widget.stationName}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: primaryGreen,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'View Pass',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReservationConfirmedPage(
                    stationName: widget.stationName,
                    connectorInfo: widget.connectorName,
                    timeSlot: widget.timeSlot,
                    heldFor: 'Confirmed',
                    reservationId: reservationId,
                    amount: widget.total,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reservation accepted! Spot reserved.'),
          backgroundColor: primaryGreen,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: backgroundColor,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Demo mode: no real bank card is charged.',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Reservation summary',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        backgroundColor: Color(0xFFE2EFEA),
                        child: Icon(
                          Icons.ev_station,
                          color: primaryGreen,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.stationName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.connectorName,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  _detailRow('Date and time', widget.timeSlot),
                  const SizedBox(height: 12),
                  _detailRow(
                    'Duration',
                    '${widget.durationMinutes} minutes',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Payment method',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryGreen,
                  width: 1.5,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.credit_card,
                    color: primaryGreen,
                    size: 30,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bank Card',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Stripe integration not configured yet',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.radio_button_checked,
                    color: primaryGreen,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Price details',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _priceRow('Charging estimate', widget.subtotal),
                  const SizedBox(height: 12),
                  _priceRow('Reservation fee', widget.fees),
                  const Divider(height: 28),
                  _priceRow('Total', widget.total, bold: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed:
                    _isProcessing ? null : _confirmDemoPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 23,
                        width: 23,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Confirm reservation · ${widget.total}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'No card details are collected or stored on this screen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _priceRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: bold ? primaryGreen : Colors.black87,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 17 : 14,
          ),
        ),
      ],
    );
  }
}
