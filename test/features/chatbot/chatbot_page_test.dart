import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chargi/features/chatbot/data/chat_repository.dart';
import 'package:chargi/features/chatbot/logic/chatbot_controller.dart';
import 'package:chargi/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:chargi/features/chatbot/presentation/widgets/typing_indicator.dart';
import 'package:chargi/features/reservations/data/reservation_repository.dart';

Map<String, Object?> _reply(
  String text, {
  List<Object?> cards = const [],
  Map<String, Object?>? pending,
  List<String> quick = const [],
  String engine = 'rules',
}) =>
    {
      'reply': text,
      'state': <String, Object?>{},
      'cards': cards,
      'pending': pending,
      'quickReplies': quick,
      'engine': engine,
    };

void main() {
  late List<Object> responses;
  late List<Map<String, Object?>> requests;
  late List<String> reservationCalls;
  Completer<void>? hold;

  ChatbotController makeController() => ChatbotController(
        chat: ChatRepository(invoker: (name, data) async {
          requests.add(data);
          await hold?.future;
          return responses.removeAt(0);
        }),
        reservations: ReservationRepository(invoker: (name, data) async {
          reservationCalls.add(name);
          return {
            'id': 'abc123def',
            'chargerId': 'ch1',
            'connectorId': 1,
            'stationName': 'Station One',
            'connectorName': 'CCS',
            'start': '2026-06-02T14:00:00.000Z',
            'end': '2026-06-02T15:00:00.000Z',
            'durationMinutes': 60,
            'amount': 26,
            'currency': 'TND',
            'status': 'confirmed',
          };
        }),
        tzOffsetMinutes: () => 0,
      );

  setUp(() {
    responses = [];
    requests = [];
    reservationCalls = [];
    hold = null;
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ChatbotPage(controller: makeController())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the welcome, the mode and the quick suggestions', (tester) async {
    responses.add(_reply('Hi! I am the assistant.', quick: ['Find available chargers', 'Show my reservations']));
    await open(tester);

    expect(find.text('Chargi AI Assistant'), findsOneWidget);
    expect(find.text('Hi! I am the assistant.'), findsOneWidget);
    expect(find.text('Basic mode (rule-based)'), findsOneWidget);
    expect(find.text('Find available chargers'), findsOneWidget);
    expect(find.byTooltip('New conversation'), findsOneWidget);
  });

  testWidgets('typing a message sends it and shows the typing indicator while waiting', (tester) async {
    responses..add(_reply('Welcome'))..add(_reply('You have no upcoming reservations.'));
    await open(tester);

    hold = Completer<void>();
    await tester.enterText(find.byType(TextField), 'show my reservations');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(find.text('show my reservations'), findsOneWidget);
    expect(find.byType(TypingIndicator), findsOneWidget);

    hold!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(TypingIndicator), findsNothing);
    expect(find.text('You have no upcoming reservations.'), findsOneWidget);
    expect(requests.last['text'], 'show my reservations');
  });

  testWidgets('tapping a suggestion sends it', (tester) async {
    responses..add(_reply('Welcome', quick: ['Show my reservations']))..add(_reply('Nothing yet.'));
    await open(tester);

    await tester.tap(find.text('Show my reservations'));
    await tester.pumpAndSettle();

    expect(requests.last['text'], 'Show my reservations');
    expect(find.text('Nothing yet.'), findsOneWidget);
  });

  testWidgets('charger card: free connector is selectable and sends a structured action', (tester) async {
    responses
      ..add(_reply('Welcome'))
      ..add(_reply('Pick a connector', cards: [
        {
          'type': 'chargers',
          'selectable': true,
          'items': [
            {
              'id': 'ch1',
              'name': 'Station One',
              'address': 'Rue 1',
              'distanceKm': 1.5,
              'pricePerKwh': 0.5,
              'connectors': [
                {'connectorId': 1, 'type': 'CCS', 'powerKw': 50, 'available': true},
                {'connectorId': 2, 'type': 'Type 2', 'powerKw': 22, 'available': false},
              ],
            },
          ],
        },
      ]))
      ..add(_reply('Please confirm', pending: {
        'kind': 'create',
        'params': {'chargerId': 'ch1', 'connectorId': 1, 'start': '2026-06-02T14:00:00.000Z', 'durationMinutes': 60},
        'summary': [
          {'label': 'Station', 'value': 'Station One'},
          {'label': 'Estimated price', 'value': '26.00 TND'},
        ],
        'amount': 26,
        'currency': 'TND',
      }));
    await open(tester);
    await tester.enterText(find.byType(TextField), 'book');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Station One'), findsOneWidget);
    expect(find.text('1.5 km'), findsOneWidget);
    expect(find.textContaining('CCS - 50 kW'), findsOneWidget);

    await tester.tap(find.textContaining('CCS - 50 kW'));
    await tester.pumpAndSettle();

    expect((requests.last['action'] as Map)['connectorId'], 1);
    expect(find.text('Confirm booking'), findsOneWidget);
    expect(reservationCalls, isEmpty); // proposed only
  });

  testWidgets('confirm button books, then shows the QR code and the success message', (tester) async {
    responses
      ..add(_reply('Welcome'))
      ..add(_reply('Please confirm', pending: {
        'kind': 'create',
        'params': {'chargerId': 'ch1', 'connectorId': 1, 'start': '2026-06-02T14:00:00.000Z', 'durationMinutes': 60},
        'summary': [
          {'label': 'Station', 'value': 'Station One'},
        ],
        'amount': 26,
        'currency': 'TND',
      }));
    await open(tester);
    await tester.enterText(find.byType(TextField), 'book');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Your reservation is confirmed! Here is your QR code.'), findsNothing);
    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();

    expect(reservationCalls, ['createReservation']);
    expect(find.text('Your reservation is confirmed! Here is your QR code.'), findsOneWidget);
    expect(find.text('View pass'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('declining a proposal disables the buttons', (tester) async {
    responses
      ..add(_reply('Welcome'))
      ..add(_reply('Please confirm', pending: {
        'kind': 'cancel',
        'params': {'reservationId': 'abc123def'},
        'summary': [
          {'label': 'Station', 'value': 'Station One'},
        ],
      }));
    await open(tester);
    await tester.enterText(find.byType(TextField), 'cancel');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(reservationCalls, isEmpty);
    expect(find.text('Dismissed'), findsOneWidget);
    expect(find.text('Confirm cancellation'), findsNothing);
  });
}
