import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'reservation_confirmed_page.dart';

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

  int _selectedTab = 0; // 0: All, 1: Active, 2: Completed

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
                          'Could not load reservations: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: textMuted),
                        ),
                      ),
                    );
                  }

                  final allReservations = snapshot.data ?? [];
                  final now = DateTime.now();

                  final filteredReservations = allReservations.where((res) {
                    if (_selectedTab == 0) return true;

                    DateTime? startTime;
                    if (res['startDateTime'] is Timestamp) {
                      startTime = (res['startDateTime'] as Timestamp).toDate();
                    }
                    final durationMin = res['durationMinutes'] is num
                        ? (res['durationMinutes'] as num).toInt()
                        : 60;
                    final endTime = startTime?.add(Duration(minutes: durationMin));
                    final isPast = endTime?.isBefore(now) ?? false;

                    if (_selectedTab == 1) return !isPast; // Active
                    return isPast; // Completed
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
    final stationName = res['stationName']?.toString() ?? 'Charging Station';
    final connectorName = res['connectorName']?.toString() ?? 'Standard Connector';
    final timeStr = _formatDateTime(res['startDateTime'], res['durationMinutes']);
    final amount = res['amount'] != null
        ? '${res['amount']} ${res['currency'] ?? 'TND'}'
        : 'Paid';

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
        onTap: () => _openQrPass(res),
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
                      color: const Color(0xFFE4F3EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Confirmed',
                      style: TextStyle(
                        color: primaryGreen,
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
