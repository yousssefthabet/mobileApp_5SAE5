import 'package:flutter/material.dart';

import 'package:chargi/features/chatbot/domain/chat_models.dart';

const Color kChatGreen = Color(0xFF086B5B);
const Color kChatBackground = Color(0xFFF7F9F8);

String chatTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String chatDateTime(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year} '
    '${chatTime(t)}';

/// Round avatar used for the assistant.
class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFDDF1EB),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.bolt, size: size * 0.6, color: kChatGreen),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final bubbleColor = isUser
        ? kChatGreen
        : (message.isError ? const Color(0xFFFDECEA) : Colors.white);
    final textColor = isUser
        ? Colors.white
        : (message.isError ? const Color(0xFF8A1C12) : const Color(0xFF10201D));

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.74,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
        border: isUser ? null : Border.all(color: const Color(0xFFE3E9E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              message.text,
              style: TextStyle(fontSize: 14.5, height: 1.4, color: textColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            chatTime(message.time),
            style: TextStyle(
              fontSize: 10.5,
              color: textColor.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[const AssistantAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: Semantics(
              label: '${isUser ? 'You' : 'Assistant'}: ${message.text}',
              child: bubble,
            ),
          ),
        ],
      ),
    );
  }
}
