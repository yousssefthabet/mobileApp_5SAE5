import 'package:cloud_firestore/cloud_firestore.dart';

/// Rules for how a reservation document is shown in "My Reservations".
/// Works for current documents (start, end, status) and for older ones
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

/// Start + duration (60 minutes when the duration is missing).
DateTime? reservationEnd(Map<String, dynamic> res) {
  final start = reservationStart(res);
  if (start == null) return null;
  final minutes =
      res['durationMinutes'] is num ? (res['durationMinutes'] as num).toInt() : 60;
  return start.add(Duration(minutes: minutes));
}

bool reservationIsCancelled(Map<String, dynamic> res) =>
    reservationStatusOf(res) == 'cancelled';

bool reservationHasEnded(Map<String, dynamic> res, DateTime now) =>
    reservationEnd(res)?.isBefore(now) ?? false;

/// Only a confirmed reservation that has not started yet can be cancelled
/// (the server enforces the same rule).
bool reservationCanBeCancelled(Map<String, dynamic> res, DateTime now) {
  final start = reservationStart(res);
  return reservationStatusOf(res) == 'confirmed' &&
      start != null &&
      start.isAfter(now);
}

/// Tabs: 0 = All, 1 = Active, 2 = Completed. Cancelled reservations appear in
/// "All" only, never as active or completed.
bool reservationMatchesTab(Map<String, dynamic> res, int tab, DateTime now) {
  if (tab == 0) return true;
  if (reservationIsCancelled(res)) return false;
  final ended = reservationHasEnded(res, now);
  return tab == 1 ? !ended : ended;
}
