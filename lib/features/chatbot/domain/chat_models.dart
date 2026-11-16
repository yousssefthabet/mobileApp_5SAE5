import 'package:chargi/features/reservations/domain/reservation_model.dart';

enum ChatRole { user, assistant }

/// A connector shown on a charger card.
class ChatConnector {
  const ChatConnector({
    required this.connectorId,
    required this.type,
    required this.powerKw,
    required this.available,
  });

  final int connectorId;
  final String? type;
  final double powerKw;
  final bool available;

  factory ChatConnector.fromMap(Map<dynamic, dynamic> m) => ChatConnector(
        connectorId: (m['connectorId'] as num).toInt(),
        type: m['type'] as String?,
        powerKw: (m['powerKw'] as num?)?.toDouble() ?? 0,
        available: m['available'] == true,
      );
}

class ChatCharger {
  const ChatCharger({
    required this.id,
    required this.name,
    required this.address,
    required this.distanceKm,
    required this.pricePerKwh,
    required this.connectors,
  });

  final String id;
  final String name;
  final String? address;
  final double? distanceKm;
  final double pricePerKwh;
  final List<ChatConnector> connectors;

  factory ChatCharger.fromMap(Map<dynamic, dynamic> m) => ChatCharger(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? 'Charging station',
        address: m['address'] as String?,
        distanceKm: (m['distanceKm'] as num?)?.toDouble(),
        pricePerKwh: (m['pricePerKwh'] as num?)?.toDouble() ?? 0,
        connectors: [
          for (final c in (m['connectors'] as List? ?? const []))
            ChatConnector.fromMap(c as Map),
        ],
      );
}

sealed class ChatCard {
  const ChatCard();

  static ChatCard? fromMap(Map<dynamic, dynamic> m) {
    switch (m['type']) {
      case 'chargers':
        return ChargersCard(
          items: [
            for (final i in (m['items'] as List? ?? const []))
              ChatCharger.fromMap(i as Map),
          ],
          selectable: m['selectable'] == true,
        );
      case 'reservations':
        return ReservationsCard(
          items: [
            for (final i in (m['items'] as List? ?? const []))
              ReservationModel.fromMap(i as Map),
          ],
          selectable: m['selectable'] as String?,
        );
    }
    return null; // unknown card types from a newer server are ignored
  }
}

class ChargersCard extends ChatCard {
  const ChargersCard({required this.items, required this.selectable});
  final List<ChatCharger> items;
  final bool selectable;
}

class ReservationsCard extends ChatCard {
  const ReservationsCard({required this.items, this.selectable});
  final List<ReservationModel> items;

  /// 'cancel' or 'reschedule' when the user can pick one, otherwise null.
  final String? selectable;
}

enum PendingKind { create, cancel, reschedule }

/// An action the assistant proposes. Nothing happens until the user confirms.
class PendingAction {
  const PendingAction({
    required this.kind,
    required this.params,
    required this.summary,
    this.amount,
    this.currency,
  });

  final PendingKind kind;
  final Map<String, dynamic> params;
  final List<MapEntry<String, String>> summary;
  final double? amount;
  final String? currency;

  factory PendingAction.fromMap(Map<dynamic, dynamic> m) {
    final kind = switch (m['kind']) {
      'create' => PendingKind.create,
      'cancel' => PendingKind.cancel,
      'reschedule' => PendingKind.reschedule,
      _ => throw FormatException('Unknown pending kind ${m['kind']}'),
    };
    return PendingAction(
      kind: kind,
      params: Map<String, dynamic>.from(m['params'] as Map),
      summary: [
        for (final row in (m['summary'] as List? ?? const []))
          MapEntry(
            (row as Map)['label'] as String,
            row['value'] as String,
          ),
      ],
      amount: (m['amount'] as num?)?.toDouble(),
      currency: m['currency'] as String?,
    );
  }
}

enum PendingStatus { open, confirming, confirmed, dismissed, failed }

/// One turn from the `chatAssistant` function.
class ChatReply {
  const ChatReply({
    required this.reply,
    required this.state,
    required this.cards,
    required this.quickReplies,
    required this.engine,
    this.pending,
    this.needsLocation = false,
  });

  final String reply;
  final Map<String, dynamic> state;
  final List<ChatCard> cards;
  final List<String> quickReplies;
  final PendingAction? pending;
  final bool needsLocation;

  /// 'llm' or 'rules': which engine understood the message.
  final String engine;

  factory ChatReply.fromMap(Map<dynamic, dynamic> m) => ChatReply(
        reply: m['reply'] as String,
        state: Map<String, dynamic>.from((m['state'] as Map?) ?? const {}),
        cards: [
          for (final c in (m['cards'] as List? ?? const []))
            ?ChatCard.fromMap(c as Map),
        ],
        quickReplies: [
          for (final q in (m['quickReplies'] as List? ?? const [])) q as String,
        ],
        pending: m['pending'] == null
            ? null
            : PendingAction.fromMap(m['pending'] as Map),
        needsLocation: m['needsLocation'] == true,
        engine: (m['engine'] as String?) ?? 'rules',
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    DateTime? time,
    this.cards = const [],
    this.pending,
    this.quickReplies = const [],
    this.isError = false,
    this.reservation,
  })  : time = time ?? DateTime.now(),
        pendingStatus = pending == null ? null : PendingStatus.open;

  final String id;
  final ChatRole role;
  final String text;
  final DateTime time;
  final List<ChatCard> cards;
  final PendingAction? pending;
  final List<String> quickReplies;
  final bool isError;

  /// Set on the message announcing a reservation the SERVER has confirmed.
  final ReservationModel? reservation;

  PendingStatus? pendingStatus;
}
