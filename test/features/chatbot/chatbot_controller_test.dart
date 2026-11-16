import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chargi/features/chatbot/data/chat_repository.dart';
import 'package:chargi/features/chatbot/domain/chat_models.dart';
import 'package:chargi/features/chatbot/logic/chatbot_controller.dart';
import 'package:chargi/features/reservations/data/reservation_repository.dart';

Map<String, Object?> reply(
  String text, {
  Map<String, Object?> state = const {},
  List<Object?> cards = const [],
  Map<String, Object?>? pending,
  List<String> quick = const [],
  bool needsLocation = false,
  String engine = 'rules',
}) =>
    {
      'reply': text,
      'state': state,
      'cards': cards,
      'pending': pending,
      'quickReplies': quick,
      'needsLocation': needsLocation,
      'engine': engine,
    };

Map<String, Object?> reservationJson({String status = 'confirmed'}) => {
      'id': 'r1abcdef',
      'chargerId': 'ch1',
      'connectorId': 1,
      'stationName': 'Station One',
      'connectorName': 'CCS',
      'start': '2026-06-02T14:00:00.000Z',
      'end': '2026-06-02T15:00:00.000Z',
      'durationMinutes': 60,
      'amount': 26,
      'currency': 'TND',
      'status': status,
    };

Map<String, Object?> createPending() => {
      'kind': 'create',
      'params': {
        'chargerId': 'ch1',
        'connectorId': 1,
        'start': '2026-06-02T14:00:00.000Z',
        'durationMinutes': 60,
      },
      'summary': [
        {'label': 'Station', 'value': 'Station One'},
      ],
      'amount': 26,
      'currency': 'TND',
    };

class Rig {
  Rig({this.positionProvider}) {
    controller = ChatbotController(
      chat: ChatRepository(invoker: _chatInvoker),
      reservations: ReservationRepository(invoker: _reservationInvoker),
      positionProvider: positionProvider,
      tzOffsetMinutes: () => 60,
    );
  }

  final PositionProvider? positionProvider;
  late final ChatbotController controller;

  final List<Map<String, Object?>> chatRequests = [];
  final List<String> reservationCalls = [];
  final List<Object> chatResponses = []; // Map or Exception
  Object reservationResult = reservationJson();
  Completer<void>? holdChat;

  Future<Object?> _chatInvoker(String name, Map<String, Object?> data) async {
    expect(name, 'chatAssistant');
    chatRequests.add(data);
    await holdChat?.future;
    final next = chatResponses.removeAt(0);
    if (next is Exception) throw next;
    return next;
  }

  Future<Object?> _reservationInvoker(
      String name, Map<String, Object?> data) async {
    reservationCalls.add(name);
    final r = reservationResult;
    if (r is Exception) throw r;
    return r;
  }
}

void main() {
  test('start shows the welcome and the engine in use', () async {
    final rig = Rig()..chatResponses.add(reply('Hi!', quick: ['A', 'B'], engine: 'rules'));
    await rig.controller.start();

    expect(rig.controller.messages.single.text, 'Hi!');
    expect(rig.controller.messages.single.quickReplies, ['A', 'B']);
    expect(rig.controller.engine, 'rules');
    expect(rig.chatRequests.single.containsKey('text'), isFalse);
    expect((rig.chatRequests.single['context'] as Map)['tzOffsetMinutes'], 60);
  });

  test('conversation state is sent back every turn', () async {
    final rig = Rig()
      ..chatResponses.add(reply('Which day?', state: {'intent': 'book', 'lang': 'en'}))
      ..chatResponses.add(reply('What time?', state: {'intent': 'book', 'date': '2026-06-02'}));

    await rig.controller.send('book a station');
    await rig.controller.send('tomorrow');

    expect(rig.chatRequests[1]['state'], {'intent': 'book', 'lang': 'en'});
    final roles = rig.controller.messages.map((m) => m.role).toList();
    expect(roles, [ChatRole.user, ChatRole.assistant, ChatRole.user, ChatRole.assistant]);
  });

  test('nothing is created until the user confirms, and success is announced only after the server answers', () async {
    final rig = Rig()..chatResponses.add(reply('Please confirm', pending: createPending()));
    await rig.controller.send('book');

    expect(rig.reservationCalls, isEmpty);
    final proposal = rig.controller.messages.last;
    expect(proposal.pendingStatus, PendingStatus.open);

    await rig.controller.confirm(proposal.id);

    expect(rig.reservationCalls, ['createReservation']);
    expect(proposal.pendingStatus, PendingStatus.confirmed);
    final done = rig.controller.messages.last;
    expect(done.text, contains('confirmed'));
    expect(done.reservation?.id, 'r1abcdef');
    expect(rig.controller.messages.last.isError, isFalse);
  });

  test('if the server refuses, there is no success message', () async {
    final rig = Rig()..chatResponses.add(reply('Please confirm', pending: createPending()));
    rig.reservationResult = FirebaseFunctionsException(
      code: 'already-exists',
      message: 'This time slot is no longer available.',
    );
    await rig.controller.send('book');
    final proposal = rig.controller.messages.last;

    await rig.controller.confirm(proposal.id);

    expect(proposal.pendingStatus, PendingStatus.failed);
    final last = rig.controller.messages.last;
    expect(last.isError, isTrue);
    expect(last.text, 'This time slot is no longer available.');
    expect(last.reservation, isNull);
    expect(rig.controller.messages.where((m) => m.text.contains('is confirmed')), isEmpty);
  });

  test('declining does not call the backend', () async {
    final rig = Rig()..chatResponses.add(reply('Please confirm', pending: createPending()));
    await rig.controller.send('book');
    final proposal = rig.controller.messages.last;

    rig.controller.dismiss(proposal.id);

    expect(rig.reservationCalls, isEmpty);
    expect(proposal.pendingStatus, PendingStatus.dismissed);
    await rig.controller.confirm(proposal.id); // too late: ignored
    expect(rig.reservationCalls, isEmpty);
  });

  test('a double tap on Confirm books only once', () async {
    final rig = Rig()..chatResponses.add(reply('Please confirm', pending: createPending()));
    await rig.controller.send('book');
    final id = rig.controller.messages.last.id;

    await Future.wait([rig.controller.confirm(id), rig.controller.confirm(id)]);

    expect(rig.reservationCalls, ['createReservation']);
  });

  test('cancel and reschedule proposals call the matching functions', () async {
    final rig = Rig()
      ..chatResponses.add(reply('Confirm cancel', pending: {
        'kind': 'cancel',
        'params': {'reservationId': 'r1abcdef'},
        'summary': <Object>[],
      }));
    rig.reservationResult = reservationJson(status: 'cancelled');
    await rig.controller.send('cancel my reservation');
    await rig.controller.confirm(rig.controller.messages.last.id);
    expect(rig.reservationCalls, ['cancelReservation']);
    expect(rig.controller.messages.last.reservation, isNull);

    rig.chatResponses.add(reply('Confirm change', pending: {
      'kind': 'reschedule',
      'params': {
        'reservationId': 'r1abcdef',
        'start': '2026-06-02T16:00:00.000Z',
        'durationMinutes': 60,
      },
      'summary': <Object>[],
    }));
    rig.reservationResult = reservationJson();
    await rig.controller.send('change to 16:00');
    await rig.controller.confirm(rig.controller.messages.last.id);
    expect(rig.reservationCalls, ['cancelReservation', 'rescheduleReservation']);
  });

  test('selecting a connector sends a structured action', () async {
    final rig = Rig()..chatResponses.add(reply('Confirm', pending: createPending()));
    await rig.controller.selectConnector('ch1', 2);
    expect(rig.chatRequests.single['action'], {
      'type': 'select_connector',
      'chargerId': 'ch1',
      'connectorId': 2,
    });
    expect(rig.chatRequests.single.containsKey('text'), isFalse);
  });

  test('location: asks permission when the assistant needs it, then retries with it', () async {
    final asked = <bool>[];
    final rig = Rig(positionProvider: ({required bool request}) async {
      asked.add(request);
      return request ? (lat: 36.8, lng: 10.18) : null;
    })
      ..chatResponses.add(reply('Allow location', needsLocation: true))
      ..chatResponses.add(reply('Found 1 station'));

    await rig.controller.send('find the nearest charger');

    expect(rig.chatRequests, hasLength(2));
    expect((rig.chatRequests[0]['context'] as Map).containsKey('lat'), isFalse);
    expect((rig.chatRequests[1]['context'] as Map)['lat'], 36.8);
    expect(asked.contains(true), isTrue);
    expect(rig.controller.messages.last.text, 'Found 1 station');
  });

  test('location denied: explains instead of failing silently', () async {
    final rig = Rig(positionProvider: ({required bool request}) async => null)
      ..chatResponses.add(reply('Allow location', needsLocation: true));
    await rig.controller.send('find the nearest charger');
    expect(rig.controller.messages.last.text, contains('location'));
  });

  test('network error: friendly message and the chat is usable again', () async {
    final rig = Rig()
      ..chatResponses.add(FirebaseFunctionsException(code: 'unavailable', message: 'x'))
      ..chatResponses.add(reply('Back online'));

    await rig.controller.send('hello');
    expect(rig.controller.busy, isFalse);
    expect(rig.controller.messages.last.isError, isTrue);
    expect(rig.controller.messages.last.text, contains('No connection'));

    await rig.controller.send('hello again');
    expect(rig.controller.messages.last.text, 'Back online');
  });

  test('unauthenticated: asks the user to sign in, without raw errors', () async {
    final rig = Rig()
      ..chatResponses.add(FirebaseFunctionsException(code: 'unauthenticated', message: 'raw'));
    await rig.controller.send('hello');
    expect(rig.controller.messages.last.text, 'Please sign in to use the assistant.');
  });

  test('busy: a second message while waiting is ignored', () async {
    final rig = Rig()
      ..holdChat = Completer<void>()
      ..chatResponses.add(reply('One'));
    final first = rig.controller.send('first');
    await rig.controller.send('second'); // ignored: still busy
    rig.holdChat!.complete();
    await first;
    expect(rig.chatRequests, hasLength(1));
  });

  test('new conversation clears messages and state, then greets again', () async {
    final rig = Rig()
      ..chatResponses.add(reply('One', state: {'intent': 'book'}))
      ..chatResponses.add(reply('Welcome again'));
    await rig.controller.send('book');
    rig.controller.newConversation();
    await pumpEventQueue();
    expect(rig.chatRequests[1]['state'], <String, Object?>{});
    expect(rig.controller.messages.map((m) => m.text), ['Welcome again']);
  });

  test('French replies switch the confirmation wording', () async {
    final rig = Rig()
      ..chatResponses.add(reply('Merci de confirmer', state: {'lang': 'fr'}, pending: createPending()));
    await rig.controller.send('je veux réserver');
    await rig.controller.confirm(rig.controller.messages.last.id);
    expect(rig.controller.messages.last.text, contains('confirmée'));
  });
}
