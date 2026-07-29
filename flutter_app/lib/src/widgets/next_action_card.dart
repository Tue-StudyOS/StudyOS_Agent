import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

/// Renders a `next_action` generative-UI component: a prominent call-to-action
/// the model surfaces when a reply has an obvious next step. Tapping the CTA
/// sends its label back into the chat as a [PromptComponentAction] (e.g. "Open
/// schedule" → the agent then opens the schedule), so the button stays useful
/// without a bespoke route per `action_id`. With no [onAction] the card shows
/// its title and body only.
class NextActionCard extends StatelessWidget {
  const NextActionCard({
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
    final cta = component.arguments['cta']?.toString().trim() ?? '';
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
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: StudyOsColors.accent,
                    ),
                    const SizedBox(width: StudyOsSpacing.sm),
                    Expanded(
                      child: Text(
                        component.title,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                if (body.isNotEmpty) ...<Widget>[
                  const SizedBox(height: StudyOsSpacing.xs),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
                if (cta.isNotEmpty && onAction != null) ...<Widget>[
                  const SizedBox(height: StudyOsSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: () => onAction!(PromptComponentAction(cta)),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: StudyOsSpacing.lg,
                        ),
                      ),
                      child: Text(cta),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
