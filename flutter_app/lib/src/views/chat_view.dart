import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/composer_bar.dart';
import '../widgets/message_list.dart';
import '../widgets/suggestion_strip.dart';

class ChatView extends StatelessWidget {
  const ChatView({
    required this.messages,
    required this.inputController,
    required this.isSending,
    required this.compactMessages,
    required this.onSuggestionSelected,
    required this.onSend,
    super.key,
  });

  final List<ChatMessage> messages;
  final TextEditingController inputController;
  final bool isSending;
  final bool compactMessages;
  final ValueChanged<String> onSuggestionSelected;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: MessageList(messages: messages, compact: compactMessages),
        ),
        SuggestionStrip(onSelected: onSuggestionSelected),
        ComposerBar(
          controller: inputController,
          isSending: isSending,
          onSend: onSend,
        ),
      ],
    );
  }
}
