import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models.dart';
import '../studyos_theme.dart';

class MessageList extends StatelessWidget {
  const MessageList({required this.messages, required this.compact, super.key});

  final List<ChatMessage> messages;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: StudyOsSpacing.sm),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MessageBubble(message: message, compact: compact);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.compact});

  final ChatMessage message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!message.isUser) {
      return _AssistantText(message: message, compact: compact);
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: EdgeInsets.symmetric(vertical: compact ? 3 : 5),
        padding: EdgeInsets.all(
          compact ? StudyOsSpacing.sm : StudyOsSpacing.md,
        ),
        decoration: BoxDecoration(
          color: StudyOsColors.accentStrong,
          border: Border.all(
            color: StudyOsColors.accent.withValues(alpha: 0.8),
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(StudyOsRadii.lg),
            topRight: const Radius.circular(StudyOsRadii.lg),
            bottomLeft: const Radius.circular(StudyOsRadii.lg),
            bottomRight: const Radius.circular(StudyOsRadii.sm),
          ),
        ),
        child: Text(message.text, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

class _AssistantText extends StatelessWidget {
  const _AssistantText({required this.message, required this.compact});

  final ChatMessage message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: EdgeInsets.symmetric(vertical: compact ? 7 : 11),
        child: MarkdownBody(
          data: message.text,
          selectable: true,
          styleSheet: _markdownStyle(context),
        ),
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final base = textTheme.bodyLarge ?? const TextStyle();
    return MarkdownStyleSheet(
      p: base,
      strong: base.copyWith(fontWeight: FontWeight.w700),
      em: base.copyWith(fontStyle: FontStyle.italic),
      code: base.copyWith(
        color: StudyOsColors.text,
        backgroundColor: StudyOsColors.background.withValues(alpha: 0.7),
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: StudyOsColors.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(StudyOsRadii.sm),
        border: Border.all(color: StudyOsColors.border),
      ),
      blockquoteDecoration: BoxDecoration(
        border: const Border(
          left: BorderSide(color: StudyOsColors.accent, width: 3),
        ),
        color: StudyOsColors.surface,
        borderRadius: BorderRadius.circular(StudyOsRadii.sm),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: StudyOsSpacing.md,
        vertical: StudyOsSpacing.sm,
      ),
      listBullet: base.copyWith(color: StudyOsColors.text),
      a: base.copyWith(
        color: StudyOsColors.accent,
        decoration: TextDecoration.underline,
      ),
    );
  }
}
