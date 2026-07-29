import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

/// Renders a `quick_reply` generative-UI component: a suggested follow-up the
/// user can tap to send back into the chat. The tap emits a
/// [PromptComponentAction] carrying the `reply` argument, so the suggestion runs
/// as if the user had typed it. With no [onAction] (e.g. the settings preview)
/// the suggestion renders as a plain, non-tappable chip.
class QuickReplyCard extends StatelessWidget {
  const QuickReplyCard({
    required this.component,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final GeneratedUiComponent component;
  final ValueChanged<GeneratedComponentAction>? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reply = component.arguments['reply']?.toString().trim() ?? '';
    final body = component.body.trim();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: EdgeInsets.symmetric(vertical: compact ? 5 : 8),
        child: Material(
          color: StudyOsColors.surface,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: StudyOsColors.border),
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(StudyOsSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (body.isNotEmpty) ...<Widget>[
                  Text(body, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: StudyOsSpacing.sm),
                ],
                if (reply.isNotEmpty)
                  _ReplyChip(
                    label: reply,
                    onPressed: onAction == null
                        ? null
                        : () => onAction!(PromptComponentAction(reply)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyChip extends StatelessWidget {
  const _ReplyChip({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.reply_rounded, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: StudyOsColors.accent,
        side: const BorderSide(color: StudyOsColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StudyOsRadii.lg),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: StudyOsSpacing.md,
          vertical: StudyOsSpacing.sm,
        ),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.labelLarge,
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
