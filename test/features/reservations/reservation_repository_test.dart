import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chargi/features/reservations/data/reservation_repository.dart';

Map<String, Object?> _reservationJson({String status = 'confirmed'}) => {
      'id': 'r1',
      'chargerId': 'ch1',
      'connectorId': 2,
      'stationName': 'Station One',
      'connectorName': 'CCS',
      'start': '2026-06-02T10:00:00.000Z',
      'end': '2026-06-02T11:00:00.000Z',
      'durationMinutes': 60,
      'amount': 26,
      'currency': 'TND',
      'status': status,
    };

Future<ReservationFailure?> _failureOf(Future<Object?> Function() run) async {
  try {
    await run();
    return null;
  } on ReservationException catch (e) {
    return e.failure;
  }
}

void main() {
  test('createReservation sends UTC ISO start and parses the result', () async {
    String? name;
    Map<String, Object?>? sent;
    final repo = ReservationRepository(invoker: (n, d) async {
      name = n;
      sent = d;
      return _reservationJson();
    });

    final r = await repo.createReservation(
      chargerId: 'ch1',
      connectorId: 2,
      start: DateTime.utc(2026, 6, 2, 10),
      durationMinutes: 60,
    );

    expect(name, 'createReservation');
    expect(sent!['chargerId'], 'ch1');
    expect(sent!['connectorId'], 2);
    expect(sent!['start'], '2026-06-02T10:00:00.000Z');
    expect(sent!['durationMinutes'], 60);
    expect(sent!.containsKey('amount'), isFalse); // price is server-side
    expect(r.id, 'r1');
    expect(r.amount, 26.0);
    expect(r.isConfirmed, isTrue);
    expect(r.end.difference(r.start), const Duration(hours: 1));
  });

  test('cancel and reschedule call the right functions', () async {
    final calls = <String>[];
    final repo = ReservationRepository(invoker: (n, d) async {
      calls.add('$n:${d['reservationId']}');
      return _reservationJson(status: n == 'cancelReservation' ? 'cancelled' : 'confirmed');
    });

    expect((await repo.cancelReservation('r1')).status, 'cancelled');
    await repo.rescheduleReservation(
      reservationId: 'r1',
      start: DateTime.utc(2026, 6, 3, 9),
    );
    expect(calls, ['cancelReservation:r1', 'rescheduleReservation:r1']);
  });

  test('maps server errors to safe failures', () async {
    Future<ReservationFailure?> failWith(String code, [String? message]) {
      final repo = ReservationRepository(
        invoker: (_, _) =>
            throw FirebaseFunctionsException(code: code, message: message ?? 'x'),
      );
      return _failureOf(() => repo.cancelReservation('r1'));
    }

    expect(await failWith('unauthenticated'), ReservationFailure.notSignedIn);
    expect(await failWith('already-exists'), ReservationFailure.slotUnavailable);
    expect(await failWith('not-found'), ReservationFailure.notFound);
    expect(await failWith('failed-precondition'), ReservationFailure.rejected);
    expect(await failWith('invalid-argument'), ReservationFailure.rejected);
    expect(await failWith('unavailable'), ReservationFailure.network);
    expect(await failWith('internal'), ReservationFailure.unknown);
  });

  test('unknown errors never leak raw text', () async {
    final repo = ReservationRepository(
      invoker: (_, _) =>
          throw FirebaseFunctionsException(code: 'internal', message: 'secret stack'),
    );
    try {
      await repo.cancelReservation('r1');
      fail('should throw');
    } on ReservationException catch (e) {
      expect(e.message, isNot(contains('secret')));
    }
  });

  test('a malformed response is an error, not a crash', () async {
    final repo = ReservationRepository(invoker: (_, _) async => 'oops');
    expect(await _failureOf(() => repo.cancelReservation('r1')),
        ReservationFailure.unknown);
  });
}
