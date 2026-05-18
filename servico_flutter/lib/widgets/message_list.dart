// lib/widgets/message_list.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'message_bubble.dart';

class MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool sending;
  final ScrollController scrollController;

  const MessageList({
    super.key,
    required this.messages,
    required this.sending,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (sending ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        if (i == messages.length) {
          // Mesmo wrapper que _MessageRow para garantir alinhamento idêntico
          return _MessageRow(
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: TypingIndicator(),
            ),
          );
        }
        return _MessageRow(child: MessageBubble(message: messages[i]));
      },
    );
  }
}

class _MessageRow extends StatelessWidget {
  final Widget child;
  const _MessageRow({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: child,
        ),
      ),
    );
  }
}
