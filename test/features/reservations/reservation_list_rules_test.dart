import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chargi/features/reservations/domain/reservation_list_rules.dart';

void main() {
  final now = DateTime(2026, 6, 1, 12);
  Timestamp at(Duration d) => Timestamp.fromDate(now.add(d));

  Map<String, dynamic> res({
    Duration start = const Duration(days: 1),
    int minutes = 60,
    String? status = 'confirmed',
  }) =>
      {
        'id': 'r1',
        'startDateTime': at(start),
        'durationMinutes': minutes,
        'status': ?status,
      };

  group('status', () {
    test('uses status, then the legacy reservationStatus, else confirmed', () {
      expect(reservationStatusOf({'status': 'Cancelled'}), 'cancelled');
      expect(reservationStatusOf({'reservationStatus': 'confirmed'}), 'confirmed');
      expect(reservationStatusOf({'status': 'cancelled', 'reservationStatus': 'confirmed'}), 'cancelled');
      expect(reservationStatusOf({}), 'confirmed');
      expect(reservationStatusOf({'status': ''}), 'confirmed');
      expect(reservationStatusOf({'status': 5}), 'confirmed');
    });
  });

  group('reservationCanBeCancelled', () {
    test('a confirmed reservation that has not started', () {
      expect(reservationCanBeCancelled(res(), now), isTrue);
      expect(reservationCanBeCancelled(res(start: const Duration(minutes: 1)), now), isTrue);
    });

    test('not once it has started or ended', () {
      expect(reservationCanBeCancelled(res(start: const Duration(minutes: -1)), now), isFalse);
      expect(reservationCanBeCancelled(res(start: const Duration(days: -2)), now), isFalse);
    });

    test('not if already cancelled or in another state', () {
      expect(reservationCanBeCancelled(res(status: 'cancelled'), now), isFalse);
      expect(reservationCanBeCancelled(res(status: 'completed'), now), isFalse);
    });

    test('older documents (reservationStatus only) can be cancelled too', () {
      final legacy = {
        'startDateTime': at(const Duration(days: 1)),
        'durationMinutes': 30,
        'reservationStatus': 'confirmed',
      };
      expect(reservationCanBeCancelled(legacy, now), isTrue);
    });

    test('without a readable start, nothing is offered', () {
      expect(reservationCanBeCancelled({'status': 'confirmed'}, now), isFalse);
      expect(reservationCanBeCancelled({'startDateTime': 'soon', 'status': 'confirmed'}, now), isFalse);
    });
  });
}
