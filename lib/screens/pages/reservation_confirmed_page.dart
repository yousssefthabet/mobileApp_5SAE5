// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'charging_complete_page.dart';
import 'package:chargi/services/station_availability_service.dart';

const Color _primaryGreen = Color(0xFF086B5B);
const Color _lightMint = Color(0xFFD8EFE6);
const Color _textDark = Color(0xFF1E2926);
const Color _textMuted = Color(0xFF7A8B86);
const Color _cardBorder = Color(0xFFE8ECEB);
const Color _backgroundColor = Color(0xFFF7F9F8);
const Color _goldAccent = Color(0xFFD97706);

class ReservationConfirmedPage extends StatefulWidget {
  final String stationName;
  final String connectorInfo;
  final String timeSlot;
  final String heldFor;
  final String? reservationId;
  final String? amount;
  final String? qrData;
  final int pointsEarned;
  final bool discountApplied;
  final String? discountAmount;
  final String? chargerId;
  final int? connectorId;
  final DateTime? endDateTime;
  final int durationMinutes;

  const ReservationConfirmedPage({
    super.key,
    this.stationName = 'Central Square Hub',
    this.connectorInfo = '1 · CCS',
    this.timeSlot = 'Today 10:30, 1 hour',
    this.heldFor = 'Confirmed',
    this.reservationId,
    this.amount,
    this.qrData,
    this.pointsEarned = 10,
    this.discountApplied = false,
    this.discountAmount,
    this.chargerId,
    this.connectorId,
    this.endDateTime,
    this.durationMinutes = 30,
  });

  @override
  State<ReservationConfirmedPage> createState() => _ReservationConfirmedPageState();
}

class _ReservationConfirmedPageState extends State<ReservationConfirmedPage> {
  Timer? _countdownTimer;
  bool _isManuallyReleased = false;
  late DateTime _effectiveEndTime;

  @override
  void initState() {
    super.initState();
    _effectiveEndTime = widget.endDateTime ??
        DateTime.now().add(Duration(minutes: widget.durationMinutes));

    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      if (now.isAfter(_effectiveEndTime) && !_isManuallyReleased) {
        setState(() {
          _isManuallyReleased = true;
        });
        timer.cancel();

        // Trigger automatic connector release in Firestore
        if (widget.chargerId != null && widget.connectorId != null) {
          StationAvailabilityService.instance.releaseConnector(
            chargerId: widget.chargerId!,
            connectorId: widget.connectorId!,
          );
        }
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _manualReleaseStation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Libérer la borne ?'),
        content: const Text(
          'Voulez-vous libérer cette borne maintenant ? Elle redeviendra immédiatement disponible pour les autres utilisateurs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Garder réservé'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Libérer maintenant'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await StationAvailabilityService.instance.cancelReservationAndReleaseStation(
      reservationId: widget.reservationId ?? '',
      chargerId: widget.chargerId,
      connectorId: widget.connectorId,
    );

    if (mounted) {
      setState(() {
        _isManuallyReleased = true;
      });
      _countdownTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réservation annulée (-10 points) et borne libérée avec succès !'),
          backgroundColor: _primaryGreen,
        ),
      );
    }
  }

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
    if (widget.discountApplied && widget.discountAmount != null) {
      buffer.writeln('Promo 30% applied: -${widget.discountAmount}');
    }
    buffer.writeln('Reward: +${widget.pointsEarned} pts');
    buffer.writeln('Scan at charger to authenticate');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = _effectiveEndTime.difference(now);
    final isExpired = _isManuallyReleased || remaining.isNegative;

    final endHour = _effectiveEndTime.hour.toString().padLeft(2, '0');
    final endMinute = _effectiveEndTime.minute.toString().padLeft(2, '0');

    final remainingMinutes = remaining.inMinutes;
    final remainingSeconds = remaining.inSeconds % 60;

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

                    // 1. Success Mint Circle Checkmark
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

                    const SizedBox(height: 18),

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

                    const SizedBox(height: 18),

                    // 2. Reservation Duration & Live Expiration Countdown Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isExpired ? const Color(0xFFF0FDF4) : const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isExpired ? const Color(0xFF86EFAC) : const Color(0xFFBAE6FD),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isExpired
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFE0F2FE),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isExpired ? Icons.check_circle_outline : Icons.timer,
                                  color: isExpired ? _primaryGreen : const Color(0xFF0284C7),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isExpired
                                          ? 'Échéance terminée · Borne libre'
                                          : 'Échéance : ${widget.durationMinutes} minutes',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isExpired ? _primaryGreen : const Color(0xFF0369A1),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isExpired
                                          ? 'La réservation a expiré. La borne est à nouveau disponible.'
                                          : 'Libération automatique prévue à $endHour:$endMinute',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isExpired
                                            ? const Color(0xFF166534)
                                            : const Color(0xFF0284C7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (!isExpired) ...[
                            const Divider(height: 22),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Temps restant :',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF0369A1),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0C4A6E),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: _manualReleaseStation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF0284C7),
                                    side: const BorderSide(color: Color(0xFF38BDF8)),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.lock_open_rounded, size: 16),
                                  label: const Text(
                                    'Libérer maintenant',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. Reward badge (+10 Points earned)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE2EFEA), Color(0xFFF1F8F5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBCE3D6), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: _primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.stars_rounded,
                              color: Colors.amberAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '+${widget.pointsEarned} Points Fidélité Gagnés !',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: _primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Chaque 100 points débloquent un code promo de 30% de remise.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF436056),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (widget.discountApplied && widget.discountAmount != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5E9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.discount,
                              color: _goldAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Code promo appliqué : 30% de réduction (-${widget.discountAmount})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF854D0E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // 4. Real Scannable QR Code
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

                    // 5. Reservation Details Card
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
                          _buildDetailRow('Durée', '${widget.durationMinutes} min (Fin à $endHour:$endMinute)'),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Statut borne',
                            isExpired ? 'Libre (Expiré)' : 'Réservé (En cours)',
                            valueColor: isExpired ? _primaryGreen : const Color(0xFF0284C7),
                          ),
                          if (widget.discountApplied && widget.discountAmount != null) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Promo discount',
                              '-${widget.discountAmount}',
                              valueColor: _primaryGreen,
                            ),
                          ],
                          if (widget.amount != null && widget.amount!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow('Total', widget.amount!),
                          ],
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Reward points',
                            widget.pointsEarned > 0
                                ? '+${widget.pointsEarned} pts'
                                : '0 pt (Promo utilisée · Compteur à 0)',
                            valueColor: widget.pointsEarned > 0 ? _primaryGreen : _goldAccent,
                          ),
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
                              durationMin: '${widget.durationMinutes} min',
                              totalCost: widget.amount ?? '14.50 DT',
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

            // 6. Bottom Action Buttons: Navigate to map, Directions, Cancel
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
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await StationAvailabilityService.instance.cancelReservationAndReleaseStation(
                                          reservationId: widget.reservationId ?? '',
                                          chargerId: widget.chargerId,
                                          connectorId: widget.connectorId,
                                        );
                                        if (!context.mounted) return;
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

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? _textDark,
          ),
        ),
      ],
    );
  }
}
