import 'package:flutter/material.dart';

import '../models/chat_message.dart';

/// Φυσαλίδα μηνύματος. Η απάντηση του AI έχει κουμπί για να ακουστεί ξανά.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.hideAi,
    required this.onSpeak,
  });

  final ChatMessage message;
  final bool hideAi;
  final void Function(String text) onSpeak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hidden = !message.isUser && hideAi;
    final textColor = message.isUser ? scheme.onPrimary : scheme.onSurface;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
      decoration: BoxDecoration(
        color: message.isUser ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              hidden ? '•••••' : message.text,
              style: TextStyle(color: textColor),
            ),
          ),
          if (!message.isUser)
            IconButton(
              icon: const Icon(Icons.volume_up, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'Άκουσε ξανά',
              onPressed: () => onSpeak(message.text),
            ),
        ],
      ),
    );
  }
}
