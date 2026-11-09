import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PromoValidationResult {
  final bool isValid;
  final String? errorMessage;
  final double discountPercent; // e.g. 30.0 for 30%
  final String code;

  const PromoValidationResult({
    required this.isValid,
    this.errorMessage,
    this.discountPercent = 0.0,
    this.code = '',
  });

  factory PromoValidationResult.success({
    required String code,
    double discountPercent = 30.0,
  }) {
    return PromoValidationResult(
      isValid: true,
      code: code,
      discountPercent: discountPercent,
    );
  }

  factory PromoValidationResult.failure(String message) {
    return PromoValidationResult(
      isValid: false,
      errorMessage: message,
    );
  }
}

class RewardService {
  RewardService._();
  static final RewardService instance = RewardService._();

  static const int pointsPerReservation = 10;
  static const int promoThresholdPoints = 100;
  static const double promoDiscountRate = 0.30; // 30%
  static const String promoCodeName = 'PROMO30';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Pure function to calculate current cycle points from a list of reservations.
  /// When a promo is used, it is single-use and the counter resets to 0.
  /// Subsequent reservations collect points anew from 0 to 100.
  int calculatePointsFromReservations(List<Map<String, dynamic>> reservations) {
    if (reservations.isEmpty) return 0;

    // Sort ascending by creation time to process cycles chronologically
    final sorted = List<Map<String, dynamic>>.from(reservations);
    sorted.sort((a, b) {
      final tA = a['createdAt'] as Timestamp?;
      final tB = b['createdAt'] as Timestamp?;
      if (tA == null && tB == null) return 0;
      if (tA == null) return -1;
      if (tB == null) return 1;
      return tA.compareTo(tB);
    });

    int points = 0;
    for (final res in sorted) {
      final status = res['reservationStatus']?.toString().toLowerCase();
      final isCancelled = status == 'cancelled' || status == 'annulée';

      if (isCancelled) {
        // Cancelled reservation: any points obtained by this reservation disappear!
        continue;
      }

      final discount = res['discountAmount'];
      final promo = res['promoCode'];
      final usedPromo = (discount is num && discount > 0) ||
          (promo != null && promo.toString().trim().isNotEmpty);

      if (usedPromo) {
        // Single-use promo was consumed: points counter resets to 0!
        points = 0;
      } else {
        final earned = (res['rewardPointsEarned'] as num?)?.toInt() ?? pointsPerReservation;
        points += earned;
      }
    }
    return points < 0 ? 0 : points;
  }

  /// Calculates user points dynamically from confirmed reservations in Firestore.
  Future<int> calculateUserPointsFromReservations(String userId) async {
    if (userId.isEmpty || userId == 'guest_user') return 0;
    try {
      final userResSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('reservations')
          .get();

      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = userResSnap.docs;

      if (docs.isEmpty) {
        final topSnap = await _firestore
            .collection('reservations')
            .where('userId', isEqualTo: userId)
            .get();
        docs = topSnap.docs;
      }

      if (docs.isEmpty) return 0;

      final reservations = docs.map((d) => d.data()).toList();
      return calculatePointsFromReservations(reservations);
    } catch (e) {
      debugPrint('Error calculating points from reservations: $e');
      return 0;
    }
  }

  /// Stream user's reward points with real-time updates and synchronization.
  Stream<int> getUserPointsStream(String userId) {
    if (userId.isEmpty || userId == 'guest_user') {
      return Stream.value(0);
    }

    final controller = StreamController<int>();
    StreamSubscription? userSub;
    StreamSubscription? resSub;

    // 1. Listen to user document
    userSub = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final pts = doc.data()?['rewardPoints'];
        if (pts is num) {
          if (!controller.isClosed) {
            controller.add(pts.toInt());
          }
        }
      }
    }, onError: (e) {
      debugPrint('Error listening to user doc in RewardService: $e');
    });

    // 2. Listen to reservations subcollection in real time to guarantee sync
    resSub = _firestore
        .collection('users')
        .doc(userId)
        .collection('reservations')
        .snapshots()
        .listen((snap) {
      final reservations = snap.docs.map((d) => d.data()).toList();
      final computedPoints = calculatePointsFromReservations(reservations);

      if (!controller.isClosed) {
        controller.add(computedPoints);
      }

      // Keep user document synchronized
      _firestore.collection('users').doc(userId).set({
        'rewardPoints': computedPoints,
        'totalReservations': snap.docs.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((e) {
        debugPrint('Could not auto-sync rewardPoints: $e');
      });
    }, onError: (e) {
      debugPrint('Error listening to reservations in RewardService: $e');
    });

    controller.onCancel = () {
      userSub?.cancel();
      resSub?.cancel();
    };

    return controller.stream;
  }

  /// Fetch user points once with fallback calculation
  Future<int> getUserPoints(String userId) async {
    if (userId.isEmpty || userId == 'guest_user') return 0;
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final pts = doc.data()?['rewardPoints'];
        if (pts is num) return pts.toInt();
      }

      final resPoints = await calculateUserPointsFromReservations(userId);
      await _firestore.collection('users').doc(userId).set({
        'rewardPoints': resPoints,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return resPoints;
    } catch (e) {
      debugPrint('Error getting user points: $e');
      return 0;
    }
  }

  /// Check if user has at least 100 points
  Future<bool> canRedeemPromo(String userId) async {
    final points = await getUserPoints(userId);
    return points >= promoThresholdPoints;
  }

  /// Validate promo code input.
  /// The promo code is SINGLE USE per 100 points collected.
  PromoValidationResult validatePromoCode({
    required String code,
    required int currentPoints,
  }) {
    final cleanCode = code.trim().toUpperCase();

    if (cleanCode.isEmpty) {
      return PromoValidationResult.failure('Veuillez saisir un code promo.');
    }

    if (cleanCode == promoCodeName) {
      if (currentPoints < promoThresholdPoints) {
        if (currentPoints <= 0) {
          return PromoValidationResult.failure(
            'Ce code est à usage unique et a déjà été utilisé.\n'
            'Votre compteur est à 0 pt. Faites 10 réservations (100 pts) pour débloquer un nouveau code.',
          );
        }
        final missing = promoThresholdPoints - currentPoints;
        final resNeeded = (missing / pointsPerReservation).ceil();
        return PromoValidationResult.failure(
          'Code promo non débloqué : $currentPoints / 100 points.\n'
          'Encore $resNeeded réservation${resNeeded > 1 ? 's' : ''} ($missing pts) pour en bénéficier.',
        );
      }
      return PromoValidationResult.success(
        code: cleanCode,
        discountPercent: 30.0,
      );
    }

    return PromoValidationResult.failure('Code promo inexistant ou expiré.');
  }

  /// Awards 10 points to the user for completing a standard reservation.
  Future<void> awardPointsForReservation({
    required String userId,
    required String reservationId,
    required String stationName,
  }) async {
    if (userId.isEmpty || userId == 'guest_user') return;

    final userRef = _firestore.collection('users').doc(userId);

    // 1. Direct update on user doc
    try {
      await userRef.set(
        {
          'rewardPoints': FieldValue.increment(pointsPerReservation),
          'totalPointsEarned': FieldValue.increment(pointsPerReservation),
          'totalReservations': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint('RewardService: +$pointsPerReservation pts directly applied to user $userId');
    } catch (e) {
      debugPrint('RewardService: Error updating user points: $e');
    }

    // 2. Logging in reward_history
    try {
      final historyRef = userRef.collection('reward_history').doc();
      await historyRef.set({
        'id': historyRef.id,
        'type': 'earned',
        'points': pointsPerReservation,
        'title': 'Réservation de borne',
        'description': 'Gain de $pointsPerReservation points pour la réservation à $stationName',
        'stationName': stationName,
        'reservationId': reservationId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('RewardService: Note: reward_history write: $e');
    }
  }

  /// Consumes the promo code (SINGLE USE) and resets the counter to 0!
  /// User collects 100 points again from 0 to obtain a new code.
  Future<bool> redeemPromoPoints({
    required String userId,
    required String reservationId,
    required double discountAmount,
    String promoCode = promoCodeName,
  }) async {
    if (userId.isEmpty || userId == 'guest_user') return false;

    final userRef = _firestore.collection('users').doc(userId);

    // 1. Reset points counter strictly to 0
    try {
      await userRef.set({
        'rewardPoints': 0, // Reset counter to 0 after single-use promo redemption!
        'totalPointsRedeemed': FieldValue.increment(promoThresholdPoints),
        'lastPromoRedeemedAt': FieldValue.serverTimestamp(),
        'lastPromoCode': promoCode,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('RewardService: Promo redeemed. Counter reset to 0 for user $userId');
    } catch (e) {
      debugPrint('RewardService: Error resetting points: $e');
    }

    // 2. Logging in reward_history
    try {
      final historyRef = userRef.collection('reward_history').doc();
      await historyRef.set({
        'id': historyRef.id,
        'type': 'redeemed',
        'points': -promoThresholdPoints,
        'title': 'Code promo 30% utilisé (usage unique)',
        'description': 'Réduction de 30% (-${discountAmount.toStringAsFixed(2)} TND) appliquée. Compteur remis à 0.',
        'promoCode': promoCode,
        'discountAmount': discountAmount,
        'reservationId': reservationId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('RewardService: Note: history log write: $e');
    }

    return true;
  }

  /// When a reservation is cancelled, revoke any points obtained and synchronize balance.
  Future<int> handleReservationCancellation({
    required String userId,
    required String reservationId,
    String? stationName,
  }) async {
    if (userId.isEmpty || userId == 'guest_user') return 0;

    try {
      // 1. Get current doc points
      final userDoc = await _firestore.collection('users').doc(userId).get();
      int currentPoints = 0;
      if (userDoc.exists) {
        final p = userDoc.data()?['rewardPoints'];
        if (p is num) currentPoints = p.toInt();
      }

      // 2. Recalculate true active points from reservations (excluding cancelled ones)
      final calculatedPoints = await calculateUserPointsFromReservations(userId);

      // 3. Ensure points are reduced by at least 10 (or clamped to 0)
      int newPoints = calculatedPoints;
      if (currentPoints > 0 && newPoints >= currentPoints) {
        newPoints = (currentPoints - pointsPerReservation).clamp(0, 999999);
      }
      if (newPoints < 0) newPoints = 0;

      // 4. Update user doc with new deducted balance immediately
      await _firestore.collection('users').doc(userId).set({
        'rewardPoints': newPoints,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 5. Log points deduction in reward_history
      final historyRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('reward_history')
          .doc();

      await historyRef.set({
        'id': historyRef.id,
        'type': 'revoked',
        'points': -pointsPerReservation,
        'title': 'Réservation annulée (-10 pts)',
        'description': 'Annulation de réservation : les 10 points obtenus ont été retirés.',
        'stationName': stationName ?? '',
        'reservationId': reservationId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('RewardService: Points revoked for cancelled reservation $reservationId. New balance: $newPoints pts');
      return newPoints;
    } catch (e) {
      debugPrint('RewardService: Error handling reservation cancellation points: $e');
      return 0;
    }
  }

  /// Stream of user reward points history with fallback from reservations.
  Stream<List<Map<String, dynamic>>> getRewardHistoryStream(String userId) {
    if (userId.isEmpty || userId == 'guest_user') {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('reservations')
        .snapshots()
        .asyncMap((resSnap) async {
      List<Map<String, dynamic>> items = [];

      // Try reading explicit reward_history first
      try {
        final histSnap = await _firestore
            .collection('users')
            .doc(userId)
            .collection('reward_history')
            .orderBy('createdAt', descending: true)
            .get();

        if (histSnap.docs.isNotEmpty) {
          return histSnap.docs.map((d) => d.data()).toList();
        }
      } catch (_) {}

      // Fallback: Build history items directly from reservations!
      for (final doc in resSnap.docs) {
        final data = doc.data();
        final status = data['reservationStatus']?.toString().toLowerCase();
        final isCancelled = status == 'cancelled' || status == 'annulée';

        final station = data['stationName'] ?? 'Station de recharge';
        final points = (data['rewardPointsEarned'] as num?)?.toInt() ?? pointsPerReservation;
        final discount = data['discountAmount'];
        final usedPromo = (discount is num && discount > 0) || (data['promoCode'] != null);

        if (isCancelled) {
          items.add({
            'id': '${doc.id}_cancelled',
            'type': 'revoked',
            'points': -points,
            'title': 'Réservation annulée',
            'description': 'Réservation à $station annulée (points retirés)',
            'stationName': station,
            'createdAt': data['cancelledAt'] ?? data['createdAt'],
          });
          continue;
        }

        if (points > 0) {
          items.add({
            'id': doc.id,
            'type': 'earned',
            'points': points,
            'title': 'Réservation de borne',
            'description': 'Gain de $points points pour la réservation à $station',
            'stationName': station,
            'createdAt': data['createdAt'],
          });
        }

        if (usedPromo) {
          items.add({
            'id': '${doc.id}_promo',
            'type': 'redeemed',
            'points': -promoThresholdPoints,
            'title': 'Code promo 30% utilisé (usage unique)',
            'description': 'Réduction de 30% appliquée sur la réservation à $station. Compteur remis à 0.',
            'stationName': station,
            'createdAt': data['createdAt'],
          });
        }
      }

      return items;
    });
  }
}
