import 'package:cloud_functions/cloud_functions.dart';

import 'package:chargi/features/chatbot/domain/chat_models.dart';
import 'package:chargi/features/reservations/data/reservation_repository.dart';

class ChatException implements Exception {
  const ChatException(this.message, {this.isNetwork = false});

  /// Safe, user-facing text.
  final String message;
  final bool isNetwork;

  @override
  String toString() => 'ChatException($message)';
}

/// Talks to the `chatAssistant` Cloud Function. The function only understands
/// the message and reads data; it never changes anything by itself.
class ChatRepository {
  ChatRepository({CallableInvoker? invoker})
      : _invoke = invoker ?? firebaseCallableInvoker;

  final CallableInvoker _invoke;

  Future<ChatReply> send({
    String? text,
    Map<String, Object?>? action,
    required Map<String, dynamic> state,
    required int tzOffsetMinutes,
    double? lat,
    double? lng,
  }) async {
    final request = <String, Object?>{
      'text': ?text,
      'action': ?action,
      'state': state,
      'context': {
        'tzOffsetMinutes': tzOffsetMinutes,
        'lat': ?lat,
        'lng': ?lng,
      },
    };

    try {
      final data = await _invoke('chatAssistant', request);
      if (data is! Map) {
        throw const ChatException('Unexpected response from the assistant.');
      }
      return ChatReply.fromMap(data);
    } on ChatException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'unauthenticated':
          throw const ChatException('Please sign in to use the assistant.');
        case 'unavailable':
        case 'deadline-exceeded':
          throw const ChatException(
            'No connection to the server. Check your internet and try again.',
            isNetwork: true,
          );
        default:
          throw const ChatException(
            'The assistant is unavailable right now. Please try again.',
          );
      }
    } catch (_) {
      throw const ChatException(
        'The assistant is unavailable right now. Please try again.',
      );
    }
  }
}
