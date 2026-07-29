import 'package:flutter/material.dart';

import '../models.dart';
import '../voice_controller.dart';
import '../widgets/composer_bar.dart';
import '../widgets/message_list.dart';
import '../widgets/suggestion_strip.dart';
import '../widgets/voice_listening_overlay.dart';

class ChatView extends StatelessWidget {
  const ChatView({
    required this.messages,
    required this.inputController,
    required this.messageScrollController,
    required this.isSending,
    required this.compactMessages,
    required this.onSuggestionSelected,
    required this.onSend,
    this.onStop,
    this.streaming,
    this.voice,
    this.onComponentAction,
    super.key,
  });

  final List<ChatMessage> messages;
  final TextEditingController inputController;
  final ScrollController messageScrollController;
  final bool isSending;
  final bool compactMessages;
  final ValueChanged<String> onSuggestionSelected;
  final VoidCallback onSend;
  final VoidCallback? onStop;
  final StreamingAssistantMessage? streaming;
  final VoiceController? voice;

  /// Dispatches an action requested by an interactive component in the message
  /// list (e.g. a mail card's Summarize or a deadline card's Add reminder).
  final ValueChanged<GeneratedComponentAction>? onComponentAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: MessageList(
            messages: messages,
            compact: compactMessages,
            controller: messageScrollController,
            streaming: streaming,
            onComponentAction: onComponentAction,
          ),
        ),
        if (messages.isEmpty) SuggestionStrip(onSelected: onSuggestionSelected),
        if (voice != null) VoiceListeningOverlay(voice: voice!),
        ComposerBar(
          controller: inputController,
          isSending: isSending,
          onSend: onSend,
          onStop: onStop,
          voice: voice,
        ),
      ],
    );
  }
}
