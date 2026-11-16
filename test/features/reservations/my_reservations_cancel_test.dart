import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chargi/features/reservations/data/reservation_repository.dart';
import 'package:chargi/screens/pages/my_reservations_page.dart';

Map<String, dynamic> _res(
  String id, {
  Duration start = const Duration(days: 1),
  String status = 'confirmed',
  String station = 'Station One',
}) =>
    {
      'id': id,
      'stationName': station,
      'connectorName': 'CCS',
      'startDateTime': Timestamp.fromDate(DateTime.now().add(start)),
      'durationMinutes': 60,
      'amount': 26,
      'currency': 'TND',
      'reservationStatus': status,
    };

Map<String, Object?> _cancelledJson(String id) => {
      'id': id,
      'chargerId': 'ch1',
      'connectorId': 1,
      'stationName': 'Station One',
      'connectorName': 'CCS',
      'start': '2026-06-02T14:00:00.000Z',
      'end': '2026-06-02T15:00:00.000Z',
      'durationMinutes': 60,
      'amount': 26,
      'currency': 'TND',
      'status': 'cancelled',
    };

void main() {
  late List<String> calls;
  late Object Function(String id) onCancel;
  Completer<void>? hold;

  ReservationRepository repo() => ReservationRepository(invoker: (name, data) async {
        calls.add('$name:${data['reservationId']}');
        await hold?.future;
        final r = onCancel(data['reservationId'] as String);
        if (r is Exception) throw r;
        return r;
      });

  setUp(() {
    calls = [];
    hold = null;
    onCancel = _cancelledJson;
  });

  Future<void> open(WidgetTester tester, List<Map<String, dynamic>> items) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MyReservationsPage(
        reservationRepository: repo(),
        reservationsStream: Stream.value(items),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> confirmInDialog(WidgetTester tester) async {
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler et libérer la borne'));
    await tester.pumpAndSettle();
  }

  group('which reservations get an "Annuler" button', () {
    testWidgets('only an active one that has not started', (tester) async {
      await open(tester, [
        _res('upcoming', station: 'Upcoming'),
        _res('past', start: const Duration(days: -2), station: 'Past'),
        _res('gone', status: 'cancelled', station: 'Gone'),
      ]);

      expect(find.text('Annuler'), findsOneWidget); // only the upcoming one
      expect(find.text('Annulée'), findsOneWidget); // badge of the cancelled one
      expect(find.text('Expirée'), findsOneWidget);
    });

    testWidgets('a reservation that has already started cannot be cancelled', (tester) async {
      await open(tester, [_res('now', start: const Duration(minutes: -10))]);
      expect(find.text('Annuler'), findsNothing);
    });

    testWidgets('a cancelled reservation shows no cancel button', (tester) async {
      await open(tester, [_res('gone', status: 'cancelled')]);
      expect(find.text('Annulée'), findsOneWidget);
      expect(find.text('Annuler'), findsNothing);
    });
  });

  group('cancelling goes through the server', () {
    testWidgets('asks for confirmation first; "Garder ma réservation" calls nothing', (tester) async {
      await open(tester, [_res('r1')]);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Annuler la réservation ?'), findsOneWidget);

      await tester.tap(find.text('Garder ma réservation'));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
      expect(find.textContaining('Réservation annulée'), findsNothing);
    });

    testWidgets('confirming calls the server for that reservation and says so', (tester) async {
      await open(tester, [_res('r1'), _res('r2', station: 'Other')]);

      await tester.tap(find.text('Annuler').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler et libérer la borne'));
      await tester.pumpAndSettle();

      expect(calls, ['cancelReservation:r1']);
      expect(find.textContaining('Réservation annulée'), findsOneWidget);
    });

    testWidgets('if the server refuses, the error is shown and no success is announced', (tester) async {
      onCancel = (id) => FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'This reservation has already started.',
          );
      await open(tester, [_res('r1')]);
      await confirmInDialog(tester);

      expect(find.text('This reservation has already started.'), findsOneWidget);
      expect(find.textContaining('Réservation annulée'), findsNothing);
      expect(find.text('Annuler'), findsOneWidget); // the button is back
    });

    testWidgets('no connection: a friendly message, nothing claimed', (tester) async {
      onCancel = (id) => FirebaseFunctionsException(code: 'unavailable', message: 'x');
      await open(tester, [_res('r1')]);
      await confirmInDialog(tester);

      expect(find.textContaining('No connection'), findsOneWidget);
      expect(find.textContaining('Réservation annulée'), findsNothing);
    });

    testWidgets('while the request runs the button is disabled (no double cancel)', (tester) async {
      hold = Completer<void>();
      await open(tester, [_res('r1')]);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler et libérer la borne'));
      await tester.pump();

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);

      hold!.complete();
      await tester.pumpAndSettle();
      expect(calls, ['cancelReservation:r1']); // exactly one call
    });
  });

  testWidgets('tabs: a cancelled reservation is not under "Actives"', (tester) async {
    await open(tester, [_res('up', station: 'Upcoming'), _res('gone', status: 'cancelled', station: 'Gone')]);

    expect(find.text('Gone'), findsOneWidget); // "Toutes"

    await tester.tap(find.text('Actives'));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Gone'), findsNothing);
  });
}
