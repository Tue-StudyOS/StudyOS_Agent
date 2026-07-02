import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../message_trace_compaction.dart';
import '../models.dart';
import '../studyos_theme.dart';
import 'thinking_trace.dart';

class MessageList extends StatelessWidget {
  const MessageList({
    required this.messages,
    required this.compact,
    required this.controller,
    this.streaming,
    super.key,
  });

  final List<ChatMessage> messages;
  final bool compact;
  final ScrollController controller;

  /// The reply currently streaming in, rendered as a live bubble after the
  /// committed messages. Null when no reply is in flight.
  final StreamingAssistantMessage? streaming;

  @override
  Widget build(BuildContext context) {
    final visibleMessages = compactTraceMessages(messages);
    final streaming = this.streaming;
    final itemCount = visibleMessages.length + (streaming != null ? 1 : 0);
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: StudyOsSpacing.sm),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= visibleMessages.length) {
          return _StreamingBubble(streaming: streaming!, compact: compact);
        }
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
    final reasoning = message.reasoning?.trim() ?? '';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: EdgeInsets.symmetric(vertical: compact ? 7 : 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (reasoning.isNotEmpty) ThinkingTrace(reasoning: reasoning),
            MarkdownBody(
              data: message.text,
              selectable: true,
              styleSheet: assistantMarkdownStyle(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live bubble for the reply that is still streaming in. Shows accumulated
/// reasoning (collapsed) and the partial answer, or animated dots before the
/// first token arrives.
class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.streaming, required this.compact});

  final StreamingAssistantMessage streaming;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reasoning = streaming.reasoning.trim();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: EdgeInsets.symmetric(vertical: compact ? 7 : 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (reasoning.isNotEmpty)
              ThinkingTrace(reasoning: reasoning, live: true),
            if (streaming.hasText)
              MarkdownBody(
                data: streaming.text,
                selectable: true,
                styleSheet: assistantMarkdownStyle(context),
              )
            else if (reasoning.isEmpty)
              const _TypingDots(),
          ],
        ),
      ),
    );
  }
}

/// Three-dot "typing" indicator shown before the first token streams in.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: StudyOsSpacing.sm),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(3, (index) {
              final phase = (_controller.value - index * 0.2) % 1.0;
              final opacity =
                  0.3 + 0.7 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Opacity(
                  opacity: opacity,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: StudyOsColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: 7),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

MarkdownStyleSheet assistantMarkdownStyle(BuildContext context) {
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
