import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargi/features/reservations/data/reservation_repository.dart';
import 'package:chargi/features/reservations/domain/reservation_list_rules.dart';
import 'reservation_confirmed_page.dart';

class MyReservationsPage extends StatefulWidget {
  final VoidCallback? onNavigateToMap;

  /// Injectable for tests; default: the real server-side booking functions.
  final ReservationRepository? reservationRepository;

  /// Injectable for tests; default: the signed-in user's reservations.
  final Stream<List<Map<String, dynamic>>>? reservationsStream;

  const MyReservationsPage({
    super.key,
    this.onNavigateToMap,
    this.reservationRepository,
    this.reservationsStream,
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

  int _selectedTab = 0; // 0: All, 1: Active, 2: Completed

  late final ReservationRepository _reservations =
      widget.reservationRepository ?? ReservationRepository();

  /// Reservations whose cancellation is in progress (disables their button).
  final Set<String> _cancelling = {};

  /// Asks for confirmation, then cancels through the server (which re-checks
  /// ownership and that the reservation has not started).
  Future<void> _confirmAndCancel(Map<String, dynamic> res) async {
    final id = res['id']?.toString();
    if (id == null || _cancelling.contains(id)) return;

    final station = res['stationName']?.toString() ?? 'this charging station';
    final when = _formatDateTime(res['startDateTime'], res['durationMinutes']);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this reservation?'),
        content: Text('$station\n$when\n\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Cancel reservation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling.add(id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _reservations.cancelReservation(id);
      // The list updates by itself: it listens to the user's reservations.
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Reservation cancelled.'),
          backgroundColor: primaryGreen,
        ),
      );
    } on ReservationException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _cancelling.remove(id));
    }
  }

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
    return 'Confirmed slot';
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
    final timeStr = _formatDateTime(res['startDateTime'], res['durationMinutes']);
    final amount = res['amount'] != null
        ? '${res['amount']} ${res['currency'] ?? 'TND'}'
        : '';
    final qrData = _buildQrPayload(res);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReservationConfirmedPage(
          stationName: station,
          connectorInfo: connector,
          timeSlot: timeStr,
          heldFor: 'Confirmed',
          reservationId: res['id']?.toString(),
          amount: amount,
          qrData: qrData,
        ),
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _getReservationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    // Reservations are private: without a signed-in user there is nothing to
    // show (the security rules no longer allow listing the whole collection).
    if (user == null) {
      return Stream.value(const <Map<String, dynamic>>[]);
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
          'My Reservations',
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
                    _buildTabButton('All', 0),
                    _buildTabButton('Active', 1),
                    _buildTabButton('Completed', 2),
                  ],
                ),
              ),
            ),

            // Reservations List
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: widget.reservationsStream ?? _getReservationsStream(),
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
                          'Could not load reservations: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: textMuted),
                        ),
                      ),
                    );
                  }

                  final allReservations = snapshot.data ?? [];
                  final now = DateTime.now();

                  // Cancelled reservations show up under "All" only.
                  final filteredReservations = allReservations
                      .where((res) => reservationMatchesTab(res, _selectedTab, now))
                      .toList();

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
    final stationName = res['stationName']?.toString() ?? 'Charging Station';
    final connectorName = res['connectorName']?.toString() ?? 'Standard Connector';
    final timeStr = _formatDateTime(res['startDateTime'], res['durationMinutes']);
    final amount = res['amount'] != null
        ? '${res['amount']} ${res['currency'] ?? 'TND'}'
        : 'Paid';

    final cancelled = reservationIsCancelled(res);
    final canCancel = reservationCanBeCancelled(res, DateTime.now());
    final resId = res['id']?.toString();
    final cancelling = resId != null && _cancelling.contains(resId);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        // A cancelled reservation has no valid pass to show.
        onTap: cancelled ? null : () => _openQrPass(res),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Station name + Status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: lightMint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.ev_station,
                      color: primaryGreen,
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
                      color: cancelled
                          ? const Color(0xFFFDECEA)
                          : const Color(0xFFE4F3EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cancelled ? 'Cancelled' : 'Confirmed',
                      style: TextStyle(
                        color: cancelled
                            ? const Color(0xFF8A1C12)
                            : primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 24, color: Color(0xFFF0F4F2)),

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

              if (!cancelled) ...[
                const SizedBox(height: 14),

                // View QR Code button
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () => _openQrPass(res),
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: const Text(
                      'View QR Pass',
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
              ],

              // Cancel button: only for a confirmed reservation that has not
              // started yet.
              if (canCancel) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: cancelling ? null : () => _confirmAndCancel(res),
                    icon: cancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined, size: 18),
                    label: Text(
                      cancelling ? 'Cancelling...' : 'Cancel reservation',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
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
              'No reservations yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reserve an EV charging station on the map to see your bookings and QR passes here.',
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
                'Explore Charging Stations',
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
