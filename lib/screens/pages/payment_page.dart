import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:chargi/services/reward_service.dart';
import 'package:chargi/services/station_availability_service.dart';
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
  static const Color goldAccent = Color(0xFFD97706);

  bool _isProcessing = false;

  // Reward and Promo Code state
  final TextEditingController _promoController = TextEditingController();
  StreamSubscription<int>? _pointsSub;
  int _userPoints = 0;
  bool _isPromoApplied = false;
  String _appliedPromoCode = '';
  double _discountPercent = 0.0;
  double _discountAmount = 0.0;
  String? _promoError;

  @override
  void initState() {
    super.initState();
    _listenToUserPoints();
  }

  @override
  void dispose() {
    _promoController.dispose();
    _pointsSub?.cancel();
    super.dispose();
  }

  void _listenToUserPoints() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _pointsSub = RewardService.instance
          .getUserPointsStream(user.uid)
          .listen((pts) {
        if (mounted) {
          setState(() {
            _userPoints = pts;
          });
        }
      });
    }
  }

  double get _finalTotal {
    if (_isPromoApplied) {
      final discounted = widget.amount - _discountAmount;
      return discounted < 0 ? 0.0 : discounted;
    }
    return widget.amount;
  }

  String get _finalTotalString => '${_finalTotal.toStringAsFixed(2)} TND';
  String get _discountAmountString => '-${_discountAmount.toStringAsFixed(2)} TND';

  void _applyPromoCode({String? directCode}) {
    FocusScope.of(context).unfocus();
    final code = directCode ?? _promoController.text.trim();

    final validation = RewardService.instance.validatePromoCode(
      code: code,
      currentPoints: _userPoints,
    );

    setState(() {
      if (validation.isValid) {
        _isPromoApplied = true;
        _appliedPromoCode = validation.code;
        _discountPercent = validation.discountPercent;
        _discountAmount = widget.amount * (_discountPercent / 100.0);
        _promoError = null;
        _promoController.text = validation.code;
      } else {
        _isPromoApplied = false;
        _appliedPromoCode = '';
        _discountPercent = 0.0;
        _discountAmount = 0.0;
        _promoError = validation.errorMessage;
      }
    });
  }

  void _removePromoCode() {
    setState(() {
      _isPromoApplied = false;
      _appliedPromoCode = '';
      _discountPercent = 0.0;
      _discountAmount = 0.0;
      _promoError = null;
      _promoController.clear();
    });
  }

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
        'endDateTime': Timestamp.fromDate(
          widget.startDateTime.add(Duration(minutes: widget.durationMinutes)),
        ),
        'durationMinutes': widget.durationMinutes,
        'amount': _finalTotal,
        'originalAmount': widget.amount,
        'discountAmount': _isPromoApplied ? _discountAmount : 0.0,
        'discountPercent': _isPromoApplied ? _discountPercent : 0.0,
        'promoCode': _isPromoApplied ? _appliedPromoCode : null,
        'rewardPointsEarned': _isPromoApplied ? 0 : RewardService.pointsPerReservation,
        'currency': 'TND',
        'paymentMethod': 'bank_card',
        'paymentStatus': 'paid',
        'reservationStatus': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 1. Record under user's private reservations collection & award points immediately
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

        // Award reward points immediately
        try {
          if (_isPromoApplied) {
            await RewardService.instance.redeemPromoPoints(
              userId: user.uid,
              reservationId: reservationId,
              discountAmount: _discountAmount,
              promoCode: _appliedPromoCode,
            );
          } else {
            await RewardService.instance.awardPointsForReservation(
              userId: user.uid,
              reservationId: reservationId,
              stationName: widget.stationName,
            );
          }
        } catch (e) {
          debugPrint('Could not award reward points: $e');
        }
      }

      // 2. Update ev_chargers connector status to busy with reservation deadline
      try {
        await StationAvailabilityService.instance.setConnectorBusy(
          chargerId: widget.chargerId,
          connectorId: widget.connectorId,
          startDateTime: widget.startDateTime,
          durationMinutes: widget.durationMinutes,
          reservationId: reservationId,
        );
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

      // Show prominent acceptance feedback with reward notification
      final bool usedPromo = _isPromoApplied;
      final String passAmount = _finalTotalString;
      final String savedAmount = _discountAmountString;

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
                    Text(
                      usedPromo
                          ? 'Réservation acceptée · 30% économisés !'
                          : 'Reservation accepted',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      usedPromo
                          ? '🎉 Code promo 30% utilisé · Compteur remis à 0 pt'
                          : '🎉 +10 Points fidélité gagnés à ${widget.stationName}',
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
                    amount: passAmount,
                    pointsEarned: usedPromo ? 0 : RewardService.pointsPerReservation,
                    discountApplied: usedPromo,
                    discountAmount: usedPromo ? savedAmount : null,
                    chargerId: widget.chargerId,
                    connectorId: widget.connectorId,
                    endDateTime: widget.startDateTime.add(Duration(minutes: widget.durationMinutes)),
                    durationMinutes: widget.durationMinutes,
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
          content: Text('Reservation accepted! Spot reserved. +10 points gagnés.'),
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
    final hasEnoughPointsForPromo = _userPoints >= RewardService.promoThresholdPoints;

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
                  const SizedBox(height: 12),
                  _detailRow(
                    'Gain fidélité',
                    '+${RewardService.pointsPerReservation} points',
                    highlightColor: primaryGreen,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Promo Code & Rewards Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Code promo & Fidélité',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2EFEA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: goldAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_userPoints pts',
                        style: const TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isPromoApplied
                      ? primaryGreen
                      : (hasEnoughPointsForPromo ? Colors.amber.shade400 : Colors.grey.shade200),
                  width: _isPromoApplied || hasEnoughPointsForPromo ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // One-tap unlock banner if user has 100+ points and hasn't applied promo
                  if (hasEnoughPointsForPromo && !_isPromoApplied) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.card_giftcard,
                            color: goldAccent,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '30% de réduction disponible !',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF854D0E),
                                  ),
                                ),
                                Text(
                                  'Vous avez 100+ points. Utilisez le code PROMO30.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF78350F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _applyPromoCode(
                              directCode: RewardService.promoCodeName,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: goldAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Appliquer',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_isPromoApplied) ...[
                    // Success badge
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2EFEA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBCE3D6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: primaryGreen,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Code $_appliedPromoCode appliqué (-30%)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: primaryGreen,
                                  ),
                                ),
                                Text(
                                  'Économie de ${_discountAmount.toStringAsFixed(2)} TND (100 points échangés)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF436056),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _removePromoCode,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            tooltip: 'Retirer le code',
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promoController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'Saisir code (ex: PROMO30)',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: backgroundColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: primaryGreen,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => _applyPromoCode(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Appliquer',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (_promoError != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _promoError!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (!hasEnoughPointsForPromo) ...[
                      const SizedBox(height: 8),
                      Text(
                        '💡 Le code PROMO30 (30% de réduction) nécessite 100 points fidélité (vous en avez $_userPoints).',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
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
                  if (_isPromoApplied) ...[
                    const SizedBox(height: 12),
                    _priceRow(
                      'Réduction Code Promo (30%)',
                      _discountAmountString,
                      isDiscount: true,
                    ),
                  ],
                  const Divider(height: 28),
                  _priceRow('Total', _finalTotalString, bold: true),
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
                        'Confirm reservation · $_finalTotalString',
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

  Widget _detailRow(String label, String value, {Color? highlightColor}) {
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
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlightColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _priceRow(
    String label,
    String value, {
    bool bold = false,
    bool isDiscount = false,
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
              color: isDiscount ? primaryGreen : Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: isDiscount
                ? primaryGreen
                : (bold ? primaryGreen : Colors.black87),
            fontWeight: bold || isDiscount ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 17 : 14,
          ),
        ),
      ],
    );
  }
}
