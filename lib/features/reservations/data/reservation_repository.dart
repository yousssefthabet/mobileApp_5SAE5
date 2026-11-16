import 'package:cloud_functions/cloud_functions.dart';

import 'package:chargi/features/reservations/domain/reservation_model.dart';

/// Why a booking operation failed, in terms the UI can react to.
enum ReservationFailure {
  notSignedIn,
  slotUnavailable,
  notFound,
  rejected,
  network,
  unknown,
}

class ReservationException implements Exception {
  const ReservationException(this.failure, this.message);

  final ReservationFailure failure;

  /// Safe, user-facing text.
  final String message;

  @override
  String toString() => 'ReservationException(${failure.name})';
}

/// Calls a Cloud Function by [name] with [data] and returns its JSON result.
/// Abstracted so the repository can be tested without Firebase.
typedef CallableInvoker = Future<Object?> Function(
  String name,
  Map<String, Object?> data,
);

Future<Object?> firebaseCallableInvoker(String name, Map<String, Object?> data) async {
  final result = await FirebaseFunctions.instance.httpsCallable(name).call(data);
  return result.data;
}

/// Client for the server-side reservation logic.
///
/// Availability, overlap checks, pricing and writes all happen in Cloud
/// Functions (inside Firestore transactions). The app never writes the
/// `reservations` collection directly.
class ReservationRepository {
  ReservationRepository({CallableInvoker? invoker})
      : _invoke = invoker ?? firebaseCallableInvoker;

  final CallableInvoker _invoke;

  Future<ReservationModel> createReservation({
    required String chargerId,
    required int connectorId,
    required DateTime start,
    required int durationMinutes,
  }) async {
    final data = await _call('createReservation', {
      'chargerId': chargerId,
      'connectorId': connectorId,
      'start': start.toUtc().toIso8601String(),
      'durationMinutes': durationMinutes,
    });
    return ReservationModel.fromMap(data);
  }

  Future<ReservationModel> cancelReservation(String reservationId) async {
    final data = await _call('cancelReservation', {
      'reservationId': reservationId,
    });
    return ReservationModel.fromMap(data);
  }

  Future<ReservationModel> rescheduleReservation({
    required String reservationId,
    required DateTime start,
    int? durationMinutes,
  }) async {
    final data = await _call('rescheduleReservation', {
      'reservationId': reservationId,
      'start': start.toUtc().toIso8601String(),
      'durationMinutes': ?durationMinutes,
    });
    return ReservationModel.fromMap(data);
  }

  Future<Map<dynamic, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      final result = await _invoke(name, data);
      if (result is Map) return result;
      throw const ReservationException(
        ReservationFailure.unknown,
        'Unexpected response from the server.',
      );
    } on ReservationException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw _translate(e);
    } catch (_) {
      throw const ReservationException(
        ReservationFailure.unknown,
        'Something went wrong. Please try again.',
      );
    }
  }

  /// Maps a Functions error to a [ReservationException]. Server messages for
  /// business rules are written for end users, so they are passed through;
  /// everything else gets a generic message.
  static ReservationException _translate(FirebaseFunctionsException e) {
    String serverMessage(String fallback) {
      final m = e.message;
      return (m == null || m.isEmpty || m == 'INTERNAL') ? fallback : m;
    }

    switch (e.code) {
      case 'unauthenticated':
        return const ReservationException(
          ReservationFailure.notSignedIn,
          'Please sign in to continue.',
        );
      case 'already-exists':
        return ReservationException(
          ReservationFailure.slotUnavailable,
          serverMessage('This time slot is no longer available.'),
        );
      case 'not-found':
        return ReservationException(
          ReservationFailure.notFound,
          serverMessage('Reservation not found.'),
        );
      case 'invalid-argument':
      case 'failed-precondition':
        return ReservationException(
          ReservationFailure.rejected,
          serverMessage('This request could not be processed.'),
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return const ReservationException(
          ReservationFailure.network,
          'No connection to the server. Check your internet and try again.',
        );
      default:
        return const ReservationException(
          ReservationFailure.unknown,
          'Something went wrong. Please try again.',
        );
    }
  }
}
