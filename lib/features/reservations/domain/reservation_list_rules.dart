import 'package:cloud_firestore/cloud_firestore.dart';

/// Rule used by "My Reservations" to decide whether the Cancel button is
/// shown. Works for current documents (start, status) and for older ones
/// (startDateTime, reservationStatus).

/// Normalised status: confirmed, cancelled, ... (a missing status means confirmed).
String reservationStatusOf(Map<String, dynamic> res) {
  final raw = res['status'] ?? res['reservationStatus'];
  if (raw is String && raw.trim().isNotEmpty) return raw.trim().toLowerCase();
  return 'confirmed';
}

DateTime? reservationStart(Map<String, dynamic> res) {
  final v = res['startDateTime'] ?? res['start'];
  return v is Timestamp ? v.toDate() : null;
}

/// Only a confirmed reservation that has not started yet can be cancelled
/// (the server enforces the same rule).
bool reservationCanBeCancelled(Map<String, dynamic> res, DateTime now) {
  final start = reservationStart(res);
  return reservationStatusOf(res) == 'confirmed' &&
      start != null &&
      start.isAfter(now);
}
