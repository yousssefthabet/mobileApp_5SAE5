import 'package:flutter/foundation.dart';

import 'package:chargi/features/chatbot/data/chat_repository.dart';
import 'package:chargi/features/chatbot/domain/chat_models.dart';
import 'package:chargi/features/reservations/data/reservation_repository.dart';

/// Returns the user's position, or null. With `request: true` it may show the
/// system permission dialog.
typedef PositionProvider = Future<({double lat, double lng})?> Function({
  required bool request,
});

/// Conversation logic for the AI assistant.
///
/// The assistant only proposes actions. A reservation is created, cancelled or
/// changed ONLY after the user taps "Confirm", through the secure server
/// functions, and the success message is shown only once the server answered.
class ChatbotController extends ChangeNotifier {
  ChatbotController({
    ChatRepository? chat,
    ReservationRepository? reservations,
    PositionProvider? positionProvider,
    int Function()? tzOffsetMinutes,
  })  : _chat = chat ?? ChatRepository(),
        _reservations = reservations ?? ReservationRepository(),
        _position = positionProvider,
        _tzOffset =
            tzOffsetMinutes ?? (() => DateTime.now().timeZoneOffset.inMinutes);

  final ChatRepository _chat;
  final ReservationRepository _reservations;
  final PositionProvider? _position;
  final int Function() _tzOffset;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  Map<String, dynamic> _state = {};
  ({double lat, double lng})? _knownPosition;
  int _nextId = 0;

  bool _busy = false;
  bool get busy => _busy;

  /// 'llm', 'rules', or null before the first answer.
  String? _engine;
  String? get engine => _engine;

  bool _disposed = false;

  String get _lang => (_state['lang'] as String?) ?? 'en';
  bool get _fr => _lang == 'fr';

  /// Whether the conversation is currently in French (UI labels follow it).
  bool get isFrench => _fr;

  String _id() => 'm${_nextId++}';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Starts (or restarts) the conversation with the assistant's welcome.
  Future<void> start() async {
    if (_messages.isNotEmpty || _busy) return;
    await _exchange(text: null, showUser: false);
  }

  void newConversation() {
    _messages.clear();
    _state = {};
    _engine = null;
    _knownPosition = null; // a new conversation does not inherit the location
    _notify();
    start();
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _busy) return;
    await _exchange(text: trimmed, showUser: true);
  }

  Future<void> selectConnector(String chargerId, int connectorId) {
    return _exchange(action: {
      'type': 'select_connector',
      'chargerId': chargerId,
      'connectorId': connectorId,
    });
  }

  Future<void> selectReservation(String reservationId) {
    return _exchange(action: {
      'type': 'select_reservation',
      'reservationId': reservationId,
    });
  }

  Future<void> _exchange({
    String? text,
    Map<String, Object?>? action,
    bool showUser = false,
    bool retryWithLocation = true,
  }) async {
    if (_busy) return;
    if (showUser && text != null) {
      _messages.add(ChatMessage(id: _id(), role: ChatRole.user, text: text));
    }
    _busy = true;
    _notify();

    try {
      // The position is never looked up on its own: it is only fetched (and
      // sent) after the assistant asked for it, then reused for the rest of
      // this conversation. Ordinary messages carry no location.
      final reply = await _chat.send(
        text: text,
        action: action,
        state: _state,
        tzOffsetMinutes: _tzOffset(),
        lat: _knownPosition?.lat,
        lng: _knownPosition?.lng,
      );
      _state = reply.state;
      _engine = reply.engine;

      if (reply.needsLocation && retryWithLocation && text != null) {
        // Reuse an existing permission silently; only prompt if needed.
        final pos = await _position?.call(request: false) ??
            await _position?.call(request: true);
        if (pos != null) {
          _knownPosition = pos;
          _busy = false;
          await _exchange(text: text, retryWithLocation: false);
          return;
        }
      }

      _messages.add(ChatMessage(
        id: _id(),
        role: ChatRole.assistant,
        text: reply.needsLocation && _knownPosition == null
            ? (_fr
                ? "Je n'ai pas pu obtenir votre position. Autorisez la localisation dans les réglages pour trouver les bornes proches."
                : "I couldn't get your location. Allow location access in settings to find nearby stations.")
            : reply.reply,
        cards: reply.cards,
        pending: reply.pending,
        quickReplies: reply.quickReplies,
      ));
    } on ChatException catch (e) {
      _messages.add(ChatMessage(
        id: _id(),
        role: ChatRole.assistant,
        text: e.message,
        isError: true,
      ));
    } finally {
      _busy = false;
      _notify();
    }
  }

  // -------------------------------------------------------------------------
  // Confirmation
  // -------------------------------------------------------------------------

  ChatMessage? _find(String id) {
    for (final m in _messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// The user tapped "Confirm" on a proposed action.
  Future<void> confirm(String messageId) async {
    final message = _find(messageId);
    final pending = message?.pending;
    if (message == null ||
        pending == null ||
        message.pendingStatus != PendingStatus.open ||
        _busy) {
      return;
    }

    message.pendingStatus = PendingStatus.confirming;
    _busy = true;
    _notify();

    try {
      final reservation = switch (pending.kind) {
        PendingKind.create => await _reservations.createReservation(
            chargerId: pending.params['chargerId'] as String,
            connectorId: (pending.params['connectorId'] as num).toInt(),
            start: DateTime.parse(pending.params['start'] as String),
            durationMinutes: (pending.params['durationMinutes'] as num).toInt(),
          ),
        PendingKind.cancel => await _reservations
            .cancelReservation(pending.params['reservationId'] as String),
        PendingKind.reschedule => await _reservations.rescheduleReservation(
            reservationId: pending.params['reservationId'] as String,
            start: DateTime.parse(pending.params['start'] as String),
            durationMinutes: (pending.params['durationMinutes'] as num).toInt(),
          ),
      };

      message.pendingStatus = PendingStatus.confirmed;
      // The conversation topic is finished: start the next one clean.
      _state = {'lang': _lang};
      _messages.add(ChatMessage(
        id: _id(),
        role: ChatRole.assistant,
        text: _successText(pending.kind),
        reservation:
            pending.kind == PendingKind.cancel ? null : reservation,
        quickReplies: _fr
            ? ['Voir mes réservations', 'Réserver une borne']
            : ['Show my reservations', 'Book a charging station'],
      ));
    } on ReservationException catch (e) {
      message.pendingStatus = PendingStatus.failed;
      _messages.add(ChatMessage(
        id: _id(),
        role: ChatRole.assistant,
        text: e.message,
        isError: true,
        quickReplies: e.failure == ReservationFailure.slotUnavailable
            ? [_fr ? 'Réserver une borne' : 'Book a charging station']
            : const [],
      ));
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// The user tapped "Cancel" on a proposed action.
  void dismiss(String messageId) {
    final message = _find(messageId);
    if (message == null || message.pendingStatus != PendingStatus.open) return;
    message.pendingStatus = PendingStatus.dismissed;
    _state = {'lang': _lang};
    _messages.add(ChatMessage(
      id: _id(),
      role: ChatRole.assistant,
      text: _fr
          ? "D'accord, je ne fais rien. Que puis-je faire d'autre ?"
          : "Okay, I won't do that. What else can I do for you?",
    ));
    _notify();
  }

  String _successText(PendingKind kind) {
    switch (kind) {
      case PendingKind.create:
        return _fr
            ? 'Votre réservation est confirmée ! Voici votre QR code.'
            : 'Your reservation is confirmed! Here is your QR code.';
      case PendingKind.cancel:
        return _fr
            ? 'Votre réservation a été annulée.'
            : 'Your reservation has been cancelled.';
      case PendingKind.reschedule:
        return _fr
            ? 'Votre réservation a été modifiée. Voici le nouveau QR code.'
            : 'Your reservation has been updated. Here is your QR code.';
    }
  }
}
