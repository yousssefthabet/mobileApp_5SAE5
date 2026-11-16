import 'package:flutter/material.dart';

import 'package:chargi/features/chatbot/data/position_provider.dart';
import 'package:chargi/features/chatbot/domain/chat_models.dart';
import 'package:chargi/features/chatbot/logic/chatbot_controller.dart';
import 'package:chargi/features/chatbot/presentation/widgets/charger_card.dart';
import 'package:chargi/features/chatbot/presentation/widgets/chat_bubble.dart';
import 'package:chargi/features/chatbot/presentation/widgets/chat_input.dart';
import 'package:chargi/features/chatbot/presentation/widgets/confirmation_card.dart';
import 'package:chargi/features/chatbot/presentation/widgets/reservation_card.dart';
import 'package:chargi/features/chatbot/presentation/widgets/typing_indicator.dart';

/// "Chargi AI Assistant": conversational access to charger search and
/// reservations. Intended for citizens.
class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key, this.controller, this.isActive = true});

  /// Injectable for tests.
  final ChatbotController? controller;

  /// Whether this tab is currently visible. The conversation (and its first
  /// request to the server) starts only once the tab is shown, not at app
  /// launch: the navigation keeps every tab alive in an IndexedStack.
  final bool isActive;

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  late final ChatbotController _controller =
      widget.controller ?? ChatbotController(positionProvider: geolocatorPosition);
  final ScrollController _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    if (widget.isActive) _controller.start();
  }

  @override
  void didUpdateWidget(covariant ChatbotPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _controller.start();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (widget.controller == null) _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    final count = _controller.messages.length + (_controller.busy ? 1 : 0);
    if (count != _lastCount) {
      _lastCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _controller.messages;
    final busy = _controller.busy;
    final fr = _controller.isFrench;
    final engine = _controller.engine;

    return Scaffold(
      backgroundColor: kChatBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            const AssistantAvatar(size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chargi AI Assistant',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (engine != null)
                    Text(
                      engine == 'llm'
                          ? (fr ? 'Assistant intelligent' : 'AI-powered')
                          : (fr ? 'Mode basique (règles)' : 'Basic mode (rule-based)'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5F6D69),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: fr ? 'Nouvelle conversation' : 'New conversation',
            onPressed: busy ? null : _controller.newConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: messages.length + (busy ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == messages.length) return const TypingIndicator();
                return _buildMessage(messages[i], isLast: i == messages.length - 1);
              },
            ),
          ),
          ChatInput(
            enabled: !busy,
            hint: fr
                ? 'Posez une question sur les bornes ou réservations...'
                : 'Ask about chargers or reservations...',
            onSend: _controller.send,
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage m, {required bool isLast}) {
    final busy = _controller.busy;
    final live = isLast && !busy; // only the latest question is actionable

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatBubble(message: m),
        for (final card in m.cards)
          switch (card) {
            ChargersCard() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in card.items)
                    ChargerCard(
                      charger: c,
                      onSelect: (live && card.selectable)
                          ? (id) => _controller.selectConnector(c.id, id)
                          : null,
                    ),
                ],
              ),
            ReservationsCard() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in card.items)
                    ReservationCard(
                      reservation: r,
                      onTap: (live && card.selectable != null)
                          ? () => _controller.selectReservation(r.id)
                          : null,
                    ),
                ],
              ),
          },
        if (m.pending != null)
          ConfirmationCard(
            pending: m.pending!,
            status: m.pendingStatus ?? PendingStatus.open,
            french: _controller.isFrench,
            onConfirm: () => _controller.confirm(m.id),
            onCancel: () => _controller.dismiss(m.id),
          ),
        if (m.reservation != null) ConfirmedReservationCard(reservation: m.reservation!),
        if (live && m.quickReplies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in m.quickReplies)
                  ActionChip(
                    label: Text(q),
                    onPressed: () => _controller.send(q),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: kChatGreen),
                    labelStyle: const TextStyle(
                      color: kChatGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}
