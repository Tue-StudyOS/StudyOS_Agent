import 'package:flutter/material.dart';

import '../studyos_theme.dart';

/// Collapsible panel for the model's reasoning/"thinking" trace. Collapsed by
/// default; the body is revealed only when the user taps the header.
class ThinkingTrace extends StatefulWidget {
  const ThinkingTrace({
    required this.reasoning,
    this.live = false,
    super.key,
  });

  /// The reasoning text to show when expanded.
  final String reasoning;

  /// When true, the reply is still streaming, so the header reads "Thinking…".
  final bool live;

  @override
  State<ThinkingTrace> createState() => _ThinkingTraceState();
}

class _ThinkingTraceState extends State<ThinkingTrace> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: StudyOsSpacing.sm),
      decoration: BoxDecoration(
        color: StudyOsColors.surface.withValues(alpha: 0.42),
        border: Border.all(color: StudyOsColors.border),
        borderRadius: BorderRadius.circular(StudyOsRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(StudyOsRadii.sm),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StudyOsSpacing.sm,
                vertical: StudyOsSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.psychology_outlined,
                    size: 16,
                    color: StudyOsColors.textMuted,
                  ),
                  const SizedBox(width: StudyOsSpacing.sm),
                  Text(
                    widget.live ? 'Thinking…' : 'Thinking',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: StudyOsSpacing.xs),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: StudyOsColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                StudyOsSpacing.sm,
                0,
                StudyOsSpacing.sm,
                StudyOsSpacing.sm,
              ),
              child: SelectableText(
                widget.reasoning,
                style: textTheme.bodyMedium,
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 160),
          ),
        ],
      ),
    );
  }
}
