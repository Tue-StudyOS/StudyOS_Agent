import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../message_trace_compaction.dart';
import '../models.dart';
import '../studyos_theme.dart';

class MessageList extends StatelessWidget {
  const MessageList({
    required this.messages,
    required this.compact,
    required this.controller,
    super.key,
  });

  final List<ChatMessage> messages;
  final bool compact;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final visibleMessages = compactTraceMessages(messages);
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: StudyOsSpacing.sm),
      itemCount: visibleMessages.length,
      itemBuilder: (context, index) {
        final message = visibleMessages[index];
        if (message.isTrace) {
          return _ToolTraceRow(message: message, compact: compact);
        }
        return _MessageBubble(message: message, compact: compact);
      },
    );
  }
}

class _ToolTraceRow extends StatelessWidget {
  const _ToolTraceRow({required this.message, required this.compact});

  final ChatMessage message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final trace = message.trace!;
    final style = _TraceStatusStyle.forStatus(trace.status);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: EdgeInsets.symmetric(vertical: compact ? 3 : 5),
        padding: const EdgeInsets.symmetric(
          horizontal: StudyOsSpacing.sm,
          vertical: StudyOsSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: StudyOsColors.surface.withValues(alpha: 0.42),
          border: Border.all(color: style.borderColor, width: style.width),
          borderRadius: BorderRadius.circular(StudyOsRadii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Tooltip(
                message: trace.status,
                child: _StatusDot(color: style.dotColor),
              ),
            ),
            const SizedBox(width: StudyOsSpacing.sm),
            Flexible(
              child: Text(
                trace.toolName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: StudyOsColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(dimension: 7),
    );
  }
}

class _TraceStatusStyle {
  const _TraceStatusStyle({
    required this.borderColor,
    required this.dotColor,
    required this.width,
  });

  final Color borderColor;
  final Color dotColor;
  final double width;

  static _TraceStatusStyle forStatus(String status) {
    return switch (status) {
      'running' => _TraceStatusStyle(
        borderColor: StudyOsColors.accent.withValues(alpha: 0.6),
        dotColor: StudyOsColors.accent,
        width: 1,
      ),
      'done' => _TraceStatusStyle(
        borderColor: StudyOsColors.success.withValues(alpha: 0.72),
        dotColor: StudyOsColors.success,
        width: 1.4,
      ),
      'failed' => _TraceStatusStyle(
        borderColor: StudyOsColors.warning,
        dotColor: StudyOsColors.warning,
        width: 1.8,
      ),
      _ => _TraceStatusStyle(
        borderColor: StudyOsColors.border,
        dotColor: StudyOsColors.textMuted,
        width: 1,
      ),
    };
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
