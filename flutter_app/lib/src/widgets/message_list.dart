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
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final bubbleColor = message.isUser
        ? StudyOsColors.accentStrong
        : StudyOsColors.surfaceRaised;
    final borderColor = message.isUser
        ? StudyOsColors.accent
        : StudyOsColors.border;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: EdgeInsets.symmetric(vertical: compact ? 3 : 5),
        padding: EdgeInsets.all(
          compact ? StudyOsSpacing.sm : StudyOsSpacing.md,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          border: Border.all(color: borderColor.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(StudyOsRadii.lg),
            topRight: const Radius.circular(StudyOsRadii.lg),
            bottomLeft: Radius.circular(
              message.isUser ? StudyOsRadii.lg : StudyOsRadii.sm,
            ),
            bottomRight: Radius.circular(
              message.isUser ? StudyOsRadii.sm : StudyOsRadii.lg,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message.author,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: message.isUser
                    ? const Color(0xFFEAF4FF)
                    : StudyOsColors.accent,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            message.isUser
                ? Text(
                    message.text,
                    style: Theme.of(context).textTheme.bodyLarge,
                  )
                : MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: _markdownStyle(context),
                  ),
          ],
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
