import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:chargi/services/reward_service.dart';

class StationAvailabilityService {
  StationAvailabilityService._();
  static final StationAvailabilityService instance = StationAvailabilityService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _cleanupTimer;

  /// Starts a periodic background check to release expired connectors.
  void startPeriodicCleanup({Duration interval = const Duration(seconds: 15)}) {
    _cleanupTimer?.cancel();
    releaseExpiredReservations();
    _cleanupTimer = Timer.periodic(interval, (_) {
      releaseExpiredReservations();
    });
  }

  void stopPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// Determines if a connector is currently free, accounting for reservation deadlines.
  bool isConnectorFree(Map<String, dynamic> connector) {
    final status = connector['status']?.toString().toLowerCase() ?? 'unknown';

    if (status == 'free') {
      return true;
    }

    if (status == 'busy') {
      final busyUntil = connector['busyUntil'];
      if (busyUntil is Timestamp) {
        final expirationDate = busyUntil.toDate();
        if (DateTime.now().isAfter(expirationDate)) {
          return true;
        }
      }
      return false;
    }

    return false;
  }

  /// Returns user-friendly status text for a connector, including remaining minutes.
  String getConnectorStatusText(Map<String, dynamic> connector) {
    final status = connector['status']?.toString().toLowerCase() ?? 'unknown';

    if (status == 'free') {
      return 'Free';
    }

    if (status == 'out_of_service') {
      return 'Out of service';
    }

    if (status == 'busy') {
      final busyUntil = connector['busyUntil'];
      if (busyUntil is Timestamp) {
        final expirationDate = busyUntil.toDate();
        final now = DateTime.now();

        if (now.isAfter(expirationDate)) {
          return 'Free';
        }

        final diff = expirationDate.difference(now);
        final minutesLeft = diff.inMinutes;
        final hour = expirationDate.hour.toString().padLeft(2, '0');
        final minute = expirationDate.minute.toString().padLeft(2, '0');

        if (minutesLeft <= 1) {
          return 'Libre dans < 1 min';
        }
        return 'Occupé (libre à $hour:$minute · dans  min)';
      }
      return 'Busy';
    }

    return 'Unavailable';
  }

  /// Scans all EV chargers and releases connectors whose reservation deadline has expired.
  Future<void> releaseExpiredReservations() async {
    try {
      final now = DateTime.now();
      final chargersSnapshot = await _firestore.collection('ev_chargers').get();

      for (final doc in chargersSnapshot.docs) {
        final data = doc.data();
        final rawConnectors = data['connectors'];

        if (rawConnectors is! List || rawConnectors.isEmpty) continue;

        bool chargerChanged = false;
        final connectors = rawConnectors.map((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();

        for (int i = 0; i < connectors.length; i++) {
          final connector = connectors[i];
          final status = connector['status']?.toString().toLowerCase();

          if (status != 'busy') continue;

          final busyUntil = connector['busyUntil'];

          if (busyUntil is Timestamp) {
            final expirationDate = busyUntil.toDate();
            // Deadline expired: mark free
            if (now.isAfter(expirationDate)) {
              connectors[i]['status'] = 'free';
              connectors[i].remove('busyUntil');
              connectors[i].remove('busyFrom');
              connectors[i].remove('currentReservationId');
              chargerChanged = true;
              debugPrint('StationAvailabilityService: Released connector ${connector['connectorId'] ?? i + 1} on charger ${doc.id}');
            }
          } else {
            // Legacy busy connector without busyUntil:
            final connectorId = connector['connectorId'] ?? connector['id'] ?? (i + 1);
            final hasActiveReservation = await _hasActiveReservationForConnector(
              chargerId: doc.id,
              connectorId: connectorId is num ? connectorId.toInt() : int.tryParse(connectorId.toString()) ?? (i + 1),
              now: now,
            );

            if (!hasActiveReservation) {
              connectors[i]['status'] = 'free';
              connectors[i].remove('busyUntil');
              connectors[i].remove('busyFrom');
              connectors[i].remove('currentReservationId');
              chargerChanged = true;
              debugPrint('StationAvailabilityService: Released legacy busy connector $connectorId on charger ${doc.id}');
            }
          }
        }

        if (chargerChanged) {
          await doc.reference.update({'connectors': connectors});
        }
      }
    } catch (e) {
      debugPrint('StationAvailabilityService: Error releasing expired reservations: $e');
    }
  }

  /// Checks and releases a single charger document by ID.
  Future<void> checkAndReleaseCharger(String chargerId) async {
    if (chargerId.isEmpty) return;

    try {
      final docRef = _firestore.collection('ev_chargers').doc(chargerId);
      final doc = await docRef.get();

      if (!doc.exists) return;

      final data = doc.data();
      final rawConnectors = data?['connectors'];

      if (rawConnectors is! List || rawConnectors.isEmpty) return;

      final now = DateTime.now();
      bool changed = false;

      final connectors = rawConnectors.map((item) {
        return Map<String, dynamic>.from(item as Map);
      }).toList();

      for (int i = 0; i < connectors.length; i++) {
        final connector = connectors[i];
        final status = connector['status']?.toString().toLowerCase();

        if (status != 'busy') continue;

        final busyUntil = connector['busyUntil'];

        if (busyUntil is Timestamp) {
          final expiration = busyUntil.toDate();
          if (now.isAfter(expiration)) {
            connectors[i]['status'] = 'free';
            connectors[i].remove('busyUntil');
            connectors[i].remove('busyFrom');
            connectors[i].remove('currentReservationId');
            changed = true;
          }
        } else {
          final connectorId = connector['connectorId'] ?? connector['id'] ?? (i + 1);
          final hasActive = await _hasActiveReservationForConnector(
            chargerId: chargerId,
            connectorId: connectorId is num ? connectorId.toInt() : int.tryParse(connectorId.toString()) ?? (i + 1),
            now: now,
          );

          if (!hasActive) {
            connectors[i]['status'] = 'free';
            connectors[i].remove('busyUntil');
            connectors[i].remove('busyFrom');
            connectors[i].remove('currentReservationId');
            changed = true;
          }
        }
      }

      if (changed) {
        await docRef.update({'connectors': connectors});
        debugPrint('StationAvailabilityService: Updated charger $chargerId connectors');
      }
    } catch (e) {
      debugPrint('StationAvailabilityService: Error checking charger $chargerId: $e');
    }
  }

  /// Sets a connector as busy with its start time and expiration deadline.
  Future<void> setConnectorBusy({
    required String chargerId,
    required int connectorId,
    required DateTime startDateTime,
    required int durationMinutes,
    required String reservationId,
  }) async {
    try {
      final chargerRef = _firestore.collection('ev_chargers').doc(chargerId);
      final chargerDoc = await chargerRef.get();

      if (!chargerDoc.exists) return;

      final chargerData = chargerDoc.data();
      final rawConnectors = chargerData?['connectors'];

      if (rawConnectors is! List) return;

      final connectors = rawConnectors.map((item) {
        return Map<String, dynamic>.from(item as Map);
      }).toList();

      int targetIndex = connectors.indexWhere((c) {
        final raw = c['connectorId'] ?? c['id'] ?? c['connector_id'];
        final id = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
        return id != null && id == connectorId;
      });

      if (targetIndex == -1 && connectorId > 0 && connectorId <= connectors.length) {
        targetIndex = connectorId - 1;
      }

      if (targetIndex == -1 && connectorId >= 0 && connectorId < connectors.length) {
        targetIndex = connectorId;
      }

      if (targetIndex == -1) {
        targetIndex = connectors.indexWhere((c) =>
            c['status']?.toString().toLowerCase() == 'free');
      }

      if (targetIndex != -1) {
        final endDateTime = startDateTime.add(Duration(minutes: durationMinutes));
        connectors[targetIndex]['status'] = 'busy';
        connectors[targetIndex]['busyFrom'] = Timestamp.fromDate(startDateTime);
        connectors[targetIndex]['busyUntil'] = Timestamp.fromDate(endDateTime);
        connectors[targetIndex]['currentReservationId'] = reservationId;

        await chargerRef.update({'connectors': connectors});
        debugPrint('StationAvailabilityService: Connector $connectorId on charger $chargerId set to busy until $endDateTime');
      }
    } catch (e) {
      debugPrint('StationAvailabilityService: Error setting connector busy: $e');
    }
  }

  /// Cancels a reservation, updates its status in Firestore, and immediately frees the connector.
  Future<bool> cancelReservationAndReleaseStation({
    required String reservationId,
    String? chargerId,
    int? connectorId,
    String? userId,
  }) async {
    if (reservationId.isEmpty) return false;

    try {
      final currentUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;

      // 1. Fetch missing details from the reservation document
      Map<String, dynamic>? resData;
      if (chargerId == null || chargerId.isEmpty || connectorId == null) {
        if (currentUserId != null) {
          final userResDoc = await _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('reservations')
              .doc(reservationId)
              .get();
          if (userResDoc.exists) {
            resData = userResDoc.data();
          }
        }

        if (resData == null) {
          final topResDoc = await _firestore
              .collection('reservations')
              .doc(reservationId)
              .get();
          if (topResDoc.exists) {
            resData = topResDoc.data();
          }
        }

        if (resData != null) {
          chargerId ??= resData['chargerId']?.toString();
          final rawConn = resData['connectorId'];
          connectorId ??= rawConn is num
              ? rawConn.toInt()
              : int.tryParse(rawConn?.toString() ?? '');
        }
      }

      // 2. Mark reservation status as cancelled in both collections
      final cancelUpdates = {
        'reservationStatus': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      };

      if (currentUserId != null) {
        try {
          final userDocRef = _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('reservations')
              .doc(reservationId);
          await userDocRef.set(cancelUpdates, SetOptions(merge: true));

          final querySnap = await _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('reservations')
              .where('id', isEqualTo: reservationId)
              .get();
          for (final d in querySnap.docs) {
            await d.reference.set(cancelUpdates, SetOptions(merge: true));
          }
        } catch (e) {
          debugPrint('Error updating user reservation: $e');
        }
      }

      try {
        final topDocRef = _firestore.collection('reservations').doc(reservationId);
        await topDocRef.set(cancelUpdates, SetOptions(merge: true));

        final querySnap = await _firestore
            .collection('reservations')
            .where('id', isEqualTo: reservationId)
            .get();
        for (final d in querySnap.docs) {
          await d.reference.set(cancelUpdates, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('Error updating top reservation: $e');
      }

      // 3. Free the station connector
      if (chargerId != null && chargerId.isNotEmpty) {
        await releaseConnector(
          chargerId: chargerId,
          connectorId: connectorId ?? 1,
          reservationId: reservationId,
        );
      } else {
        await releaseConnectorByReservationId(reservationId);
      }

      // 4. Revoke points obtained from this reservation so they disappear
      if (currentUserId != null && currentUserId.isNotEmpty) {
        try {
          await RewardService.instance.handleReservationCancellation(
            userId: currentUserId,
            reservationId: reservationId,
            stationName: resData?['stationName']?.toString(),
          );
        } catch (e) {
          debugPrint('StationAvailabilityService: Error revoking points: $e');
        }
      }

      debugPrint('StationAvailabilityService: Cancelled reservation $reservationId, freed station and revoked points');
      return true;
    } catch (e) {
      debugPrint('StationAvailabilityService: Error cancelling reservation: $e');
      return false;
    }
  }

  /// Explicitly releases a connector back to free.
  Future<bool> releaseConnector({
    required String chargerId,
    required int connectorId,
    String? reservationId,
  }) async {
    if (chargerId.isEmpty) return false;

    try {
      final chargerRef = _firestore.collection('ev_chargers').doc(chargerId);
      final chargerDoc = await chargerRef.get();

      if (!chargerDoc.exists) return false;

      final data = chargerDoc.data();
      final rawConnectors = data?['connectors'];

      if (rawConnectors is! List) return false;

      final connectors = rawConnectors.map((item) {
        return Map<String, dynamic>.from(item as Map);
      }).toList();

      int targetIndex = -1;

      // 1. Try match by reservationId
      if (reservationId != null && reservationId.isNotEmpty) {
        targetIndex = connectors.indexWhere(
            (c) => c['currentReservationId']?.toString() == reservationId);
      }

      // 2. Match by connectorId / id / connector_id
      if (targetIndex == -1) {
        targetIndex = connectors.indexWhere((c) {
          final raw = c['connectorId'] ?? c['id'] ?? c['connector_id'];
          final id = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
          return id != null && id == connectorId;
        });
      }

      // 3. Match by 1-based index
      if (targetIndex == -1 && connectorId > 0 && connectorId <= connectors.length) {
        targetIndex = connectorId - 1;
      }

      // 4. Match by 0-based index
      if (targetIndex == -1 && connectorId >= 0 && connectorId < connectors.length) {
        targetIndex = connectorId;
      }

      // 5. Fallback: match first busy connector
      if (targetIndex == -1) {
        targetIndex = connectors.indexWhere((c) =>
            c['status']?.toString().toLowerCase() == 'busy');
      }

      if (targetIndex != -1) {
        connectors[targetIndex]['status'] = 'free';
        connectors[targetIndex].remove('busyUntil');
        connectors[targetIndex].remove('busyFrom');
        connectors[targetIndex].remove('currentReservationId');

        await chargerRef.update({'connectors': connectors});
        debugPrint('StationAvailabilityService: Connector $connectorId on charger $chargerId freed successfully.');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('StationAvailabilityService: Error releasing connector: $e');
      return false;
    }
  }

  /// Searches all chargers to free any connector matching this reservationId.
  Future<bool> releaseConnectorByReservationId(String reservationId) async {
    try {
      final snapshot = await _firestore.collection('ev_chargers').get();
      for (final doc in snapshot.docs) {
        final raw = doc.data()['connectors'];
        if (raw is! List) continue;

        bool changed = false;
        final connectors = raw.map((c) => Map<String, dynamic>.from(c as Map)).toList();

        for (int i = 0; i < connectors.length; i++) {
          if (connectors[i]['currentReservationId']?.toString() == reservationId) {
            connectors[i]['status'] = 'free';
            connectors[i].remove('busyUntil');
            connectors[i].remove('busyFrom');
            connectors[i].remove('currentReservationId');
            changed = true;
          }
        }

        if (changed) {
          await doc.reference.update({'connectors': connectors});
          debugPrint('StationAvailabilityService: Released connector by reservationId on charger ${doc.id}');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error releaseConnectorByReservationId: $e');
      return false;
    }
  }

  /// Forces all busy stations to be released immediately (utility to unblock everything).
  Future<int> forceReleaseAllBusyStations() async {
    int totalReleased = 0;
    try {
      final snapshot = await _firestore.collection('ev_chargers').get();

      for (final doc in snapshot.docs) {
        final rawConnectors = doc.data()['connectors'];
        if (rawConnectors is! List || rawConnectors.isEmpty) continue;

        bool changed = false;
        final connectors = rawConnectors.map((c) => Map<String, dynamic>.from(c as Map)).toList();

        for (int i = 0; i < connectors.length; i++) {
          if (connectors[i]['status']?.toString().toLowerCase() == 'busy') {
            connectors[i]['status'] = 'free';
            connectors[i].remove('busyUntil');
            connectors[i].remove('busyFrom');
            connectors[i].remove('currentReservationId');
            changed = true;
            totalReleased++;
          }
        }

        if (changed) {
          await doc.reference.update({'connectors': connectors});
        }
      }
      debugPrint('StationAvailabilityService: Force-released $totalReleased connectors across all stations.');
    } catch (e) {
      debugPrint('StationAvailabilityService: Error in force release: $e');
    }
    return totalReleased;
  }

  /// Internal helper to check if there is an active reservation right now for this connector.
  Future<bool> _hasActiveReservationForConnector({
    required String chargerId,
    required int connectorId,
    required DateTime now,
  }) async {
    try {
      final query = await _firestore
          .collection('reservations')
          .where('chargerId', isEqualTo: chargerId)
          .where('connectorId', isEqualTo: connectorId)
          .get();

      for (final doc in query.docs) {
        final data = doc.data();
        final status = (data['reservationStatus'] ?? '').toString().toLowerCase();

        if (status == 'cancelled' || status == 'completed') continue;

        final startVal = data['startDateTime'];
        final duration = (data['durationMinutes'] as num?)?.toInt() ?? 60;

        DateTime? start;
        if (startVal is Timestamp) {
          start = startVal.toDate();
        }

        if (start != null) {
          final end = start.add(Duration(minutes: duration));
          if (now.isAfter(start.subtract(const Duration(minutes: 15))) && now.isBefore(end)) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking active reservation for connector: $e');
      return false;
    }
  }
}
