import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'reservation_confirmed_page.dart';
import 'package:chargi/services/station_availability_service.dart';

class MyReservationsPage extends StatefulWidget {
  final VoidCallback? onNavigateToMap;

  const MyReservationsPage({
    super.key,
    this.onNavigateToMap,
  });

  @override
  State<MyReservationsPage> createState() => _MyReservationsPageState();
}

class _MyReservationsPageState extends State<MyReservationsPage> {
  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color lightMint = Color(0xFFE2EFEA);
  static const Color cardBorderColor = Color(0xFFE8ECEB);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);
  static const Color goldAccent = Color(0xFFD97706);

  int _selectedTab = 0; // 0: All, 1: Active, 2: Completed / Expired

  String _formatDateTime(dynamic startVal, int? durationMin) {
    if (startVal is Timestamp) {
      final dt = startVal.toDate();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      final dur = durationMin != null ? ' · $durationMin min' : '';
      return '$day/$month/$year $hour:$minute$dur';
    }
    return 'Créneau réservé';
  }

  String _formatTimeOnly(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  DateTime? _extractEndDateTime(Map<String, dynamic> res) {
    if (res['endDateTime'] is Timestamp) {
      return (res['endDateTime'] as Timestamp).toDate();
    }
    if (res['startDateTime'] is Timestamp) {
      final start = (res['startDateTime'] as Timestamp).toDate();
      final durationMin = (res['durationMinutes'] as num?)?.toInt() ?? 30;
      return start.add(Duration(minutes: durationMin));
    }
    return null;
  }

  bool _isReservationCancelled(Map<String, dynamic> res) {
    final status = res['reservationStatus']?.toString().toLowerCase();
    return status == 'cancelled' || status == 'annulée';
  }

  bool _isReservationExpired(Map<String, dynamic> res) {
    if (_isReservationCancelled(res)) return false;
    final endTime = _extractEndDateTime(res);
    if (endTime == null) return false;
    return DateTime.now().isAfter(endTime);
  }

  bool _isReservationActive(Map<String, dynamic> res) {
    if (_isReservationCancelled(res)) return false;
    if (_isReservationExpired(res)) return false;
    return true;
  }

  String _buildQrPayload(Map<String, dynamic> res) {
    final id = res['id'] ?? 'RES';
    final station = res['stationName'] ?? 'EV Charging Station';
    final connector = res['connectorName'] ?? 'Connector';
    final amount = res['amount'] != null
        ? '${res['amount']} ${res['currency'] ?? 'TND'}'
        : '';
    final timeStr = _formatDateTime(res['startDateTime'], res['durationMinutes']);

    return '''=== CHARGI EV RESERVATION PASS ===
Pass ID: $id
Station: $station
Connector: $connector
Time: $timeStr
Total: $amount
Status: CONFIRMED
Scan at charger to authenticate''';
  }

  void _openQrPass(Map<String, dynamic> res) {
    final station = res['stationName']?.toString() ?? 'Charging Station';
    final connector = res['connectorName']?.toString() ?? 'Connector';
    final durationMin = (res['durationMinutes'] as num?)?.toInt() ?? 30;
    final timeStr = _formatDateTime(res['startDateTime'], durationMin);
    final amount = res['amount'] != null
        ? '${res['amount']} ${res['currency'] ?? 'TND'}'
        : '';
    final qrData = _buildQrPayload(res);

    final discountAmount = res['discountAmount'] != null && (res['discountAmount'] as num) > 0
        ? '${res['discountAmount']} ${res['currency'] ?? 'TND'}'
        : null;
    final discountApplied = discountAmount != null;
    final pointsEarned = (res['rewardPointsEarned'] as num?)?.toInt() ?? 10;

    final endTime = _extractEndDateTime(res);
    final rawConnId = res['connectorId'];
    final connectorId = rawConnId is num ? rawConnId.toInt() : int.tryParse(rawConnId?.toString() ?? '');
    final chargerId = res['chargerId']?.toString();

    String heldFor = 'Confirmed';
    if (_isReservationCancelled(res)) {
      heldFor = 'Cancelled';
    } else if (_isReservationExpired(res)) {
      heldFor = 'Expired';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReservationConfirmedPage(
          stationName: station,
          connectorInfo: connector,
          timeSlot: timeStr,
          heldFor: heldFor,
          reservationId: res['id']?.toString(),
          amount: amount,
          qrData: qrData,
          pointsEarned: pointsEarned,
          discountApplied: discountApplied,
          discountAmount: discountAmount,
          chargerId: chargerId,
          connectorId: connectorId,
          endDateTime: endTime,
          durationMinutes: durationMin,
        ),
      ),
    );
  }

  Future<void> _cancelReservation(Map<String, dynamic> res) async {
    final stationName = res['stationName']?.toString() ?? 'cette station';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content: Text(
          'Voulez-vous vraiment annuler votre réservation pour $stationName ?\n\n'
          'La borne sera immédiatement libérée et redeviendra disponible pour les autres conducteurs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Garder ma réservation'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Annuler et libérer la borne'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final reservationId = res['id']?.toString() ?? '';
    final chargerId = res['chargerId']?.toString();
    final rawConnId = res['connectorId'];
    final connectorId = rawConnId is num ? rawConnId.toInt() : int.tryParse(rawConnId?.toString() ?? '');

    final success = await StationAvailabilityService.instance.cancelReservationAndReleaseStation(
      reservationId: reservationId,
      chargerId: chargerId,
      connectorId: connectorId,
      userId: res['userId']?.toString(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Réservation annulée (-10 points fidélité) et borne libérée avec succès !'
                : 'Erreur lors de l\'annulation de la réservation.',
          ),
          backgroundColor: success ? primaryGreen : Colors.red,
        ),
      );
      setState(() {});
    }
  }

  Stream<List<Map<String, dynamic>>> _getReservationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    if (user == null) {
      return firestore
          .collection('reservations')
          .snapshots()
          .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
    }

    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('reservations')
        .snapshots()
        .asyncMap((userSnap) async {
      final userDocs = userSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (userDocs.isNotEmpty) {
        userDocs.sort((a, b) {
          final tA = a['createdAt'] as Timestamp?;
          final tB = b['createdAt'] as Timestamp?;
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });
        return userDocs;
      }

      // Fallback to top-level collection if user subcollection is empty
      try {
        final topSnap = await firestore
            .collection('reservations')
            .where('userId', isEqualTo: user.uid)
            .get();
        final topDocs = topSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        topDocs.sort((a, b) {
          final tA = a['createdAt'] as Timestamp?;
          final tB = b['createdAt'] as Timestamp?;
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });
        return topDocs;
      } catch (_) {
        return userDocs;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textDark,
        elevation: 0,
        title: const Text(
          'Mes Réservations',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Segmented Filter Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Container(
                height: 42,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EDE9),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    _buildTabButton('Toutes', 0),
                    _buildTabButton('Actives', 1),
                    _buildTabButton('Terminées', 2),
                  ],
                ),
              ),
            ),

            // Reservations List
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getReservationsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryGreen),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Impossible de charger les réservations: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: textMuted),
                        ),
                      ),
                    );
                  }

                  final allReservations = snapshot.data ?? [];

                  final filteredReservations = allReservations.where((res) {
                    final isActive = _isReservationActive(res);
                    if (_selectedTab == 0) return true;
                    if (_selectedTab == 1) return isActive; // Actives
                    return !isActive; // Terminées ou annulées
                  }).toList();

                  if (filteredReservations.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: filteredReservations.length,
                    itemBuilder: (context, index) {
                      return _buildReservationCard(filteredReservations[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? textDark : textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReservationCard(Map<String, dynamic> res) {
    final stationName = res['stationName']?.toString() ?? 'Borne de recharge';
    final connectorName = res['connectorName']?.toString() ?? 'Connecteur standard';
    final timeStr = _formatDateTime(res['startDateTime'], res['durationMinutes']);
    final amount = res['amount'] != null
        ? '${res['amount']} ${res['currency'] ?? 'TND'}'
        : 'Payé';
    final hasPromo = res['discountAmount'] != null && (res['discountAmount'] as num) > 0;
    final pointsEarned = (res['rewardPointsEarned'] as num?)?.toInt() ?? 10;

    final isCancelled = _isReservationCancelled(res);
    final isExpired = _isReservationExpired(res);
    final isActive = _isReservationActive(res);

    final endTime = _extractEndDateTime(res);
    final now = DateTime.now();
    final remainingMinutes = (endTime != null && isActive)
        ? endTime.difference(now).inMinutes.clamp(0, 9999)
        : 0;
    final formattedEnd = endTime != null ? _formatTimeOnly(endTime) : null;

    // Status badge configurations
    final Color badgeBg;
    final Color badgeText;
    final String badgeLabel;

    if (isCancelled) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFDC2626);
      badgeLabel = 'Annulée';
    } else if (isExpired) {
      badgeBg = const Color(0xFFF3F4F6);
      badgeText = const Color(0xFF6B7280);
      badgeLabel = 'Expirée';
    } else {
      badgeBg = const Color(0xFFE4F3EE);
      badgeText = primaryGreen;
      badgeLabel = 'Active';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? primaryGreen.withValues(alpha: 0.25) : cardBorderColor,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openQrPass(res),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Station icon + Names + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? const Color(0xFFFEE2E2)
                          : (isActive ? lightMint : const Color(0xFFF3F4F6)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.ev_station,
                      color: isCancelled
                          ? const Color(0xFFDC2626)
                          : (isActive ? primaryGreen : const Color(0xFF9CA3AF)),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stationName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          connectorName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        color: badgeText,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Expiration deadline banner
              if (isActive && formattedEnd != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: primaryGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Expire à $formattedEnd (dans $remainingMinutes min) · Libération auto',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isCancelled)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Réservation annulée · Borne libérée',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isExpired && formattedEnd != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Échéance dépassée ($formattedEnd) · Borne libérée',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const Divider(height: 22, color: Color(0xFFF0F4F2)),

              // Info rows: Time & Price
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 13,
                        color: textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Rewards & Promo tags
              Row(
                children: [
                  if (isCancelled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            color: Color(0xFFDC2626),
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '0 pt (Réservation annulée)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (pointsEarned > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2EFEA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            color: goldAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+$pointsEarned pts gagnés',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasPromo) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.discount,
                            color: goldAccent,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '-30% Promo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF854D0E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 14),

              // Action buttons: QR Pass + Annuler if active
              if (isActive)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: () => _openQrPass(res),
                          icon: const Icon(Icons.qr_code, size: 18),
                          label: const Text(
                            'Voir Pass QR',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelReservation(res),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text(
                            'Annuler',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () => _openQrPass(res),
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: const Text(
                      'Voir Détails & QR Pass',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textDark,
                      side: const BorderSide(color: cardBorderColor),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: lightMint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                color: primaryGreen,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucune réservation trouvée',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Réservez une borne de recharge sur la carte pour voir vos créneaux et passes QR ici.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                if (widget.onNavigateToMap != null) {
                  widget.onNavigateToMap!();
                }
              },
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text(
                'Explorer les bornes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
