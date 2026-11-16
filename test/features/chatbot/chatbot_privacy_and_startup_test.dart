import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chargi/features/chatbot/data/chat_repository.dart';
import 'package:chargi/features/chatbot/logic/chatbot_controller.dart';
import 'package:chargi/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:chargi/features/reservations/data/reservation_repository.dart';

import 'chatbot_controller_test.dart' show Rig, reply;

void main() {
  group('location privacy', () {
    test('ordinary messages never look up or send the location', () async {
      final asked = <bool>[];
      final rig = Rig(positionProvider: ({required bool request}) async {
        asked.add(request);
        return (lat: 36.8, lng: 10.18);
      })
        ..chatResponses.add(reply('Hi'))
        ..chatResponses.add(reply('Which day?'))
        ..chatResponses.add(reply('Nothing'));

      await rig.controller.start();
      await rig.controller.send('book a station');
      await rig.controller.send('show my reservations');

      expect(asked, isEmpty);
      for (final request in rig.chatRequests) {
        expect((request['context'] as Map).containsKey('lat'), isFalse);
        expect((request['context'] as Map).containsKey('lng'), isFalse);
      }
    });

    test('after the assistant asks, an already-granted permission is used without a prompt', () async {
      final asked = <bool>[];
      final rig = Rig(positionProvider: ({required bool request}) async {
        asked.add(request);
        return (lat: 36.8, lng: 10.18); // permission already granted
      })
        ..chatResponses.add(reply('Allow location', needsLocation: true))
        ..chatResponses.add(reply('Found 3'));

      await rig.controller.send('find the nearest charger');

      expect(asked, [false]); // never had to prompt
      expect((rig.chatRequests[1]['context'] as Map)['lat'], 36.8);
    });

    test('the shared location is reused in that conversation, then forgotten on a new one', () async {
      final rig = Rig(positionProvider: ({required bool request}) async => (lat: 1.0, lng: 2.0))
        ..chatResponses.add(reply('Allow location', needsLocation: true))
        ..chatResponses.add(reply('Found'))
        ..chatResponses.add(reply('Which day?'))
        ..chatResponses.add(reply('Welcome again'));

      await rig.controller.send('find the nearest charger');
      await rig.controller.send('book a station');
      expect((rig.chatRequests[2]['context'] as Map)['lat'], 1.0);

      rig.controller.newConversation();
      await pumpEventQueue();
      expect((rig.chatRequests[3]['context'] as Map).containsKey('lat'), isFalse);
    });
  });

  group('lazy start', () {
    late List<String> calls;

    ChatbotController makeController() => ChatbotController(
          chat: ChatRepository(invoker: (name, data) async {
            calls.add(name);
            return {
              'reply': 'Hello!',
              'state': <String, Object?>{},
              'cards': <Object?>[],
              'quickReplies': <String>[],
              'engine': 'rules',
            };
          }),
          reservations: ReservationRepository(invoker: (n, d) async => {}),
          tzOffsetMinutes: () => 0,
        );

    setUp(() => calls = []);

    testWidgets('a hidden Assistant tab does not call the server until it is shown', (tester) async {
      final controller = makeController();
      Widget app(bool active) => MaterialApp(
            home: ChatbotPage(controller: controller, isActive: active),
          );

      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.text('Hello!'), findsNothing);

      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expect(calls, ['chatAssistant']);
      expect(find.text('Hello!'), findsOneWidget);

      // switching away and back does not start a second conversation
      await tester.pumpWidget(app(false));
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expect(calls, ['chatAssistant']);
    });

    testWidgets('a visible tab starts right away', (tester) async {
      final controller = makeController();
      await tester.pumpWidget(MaterialApp(home: ChatbotPage(controller: controller)));
      await tester.pumpAndSettle();
      expect(calls, ['chatAssistant']);
    });
  });
}
