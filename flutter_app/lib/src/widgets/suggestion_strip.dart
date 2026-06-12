import 'package:flutter/material.dart';

import '../studyos_theme.dart';

class SuggestionStrip extends StatelessWidget {
  const SuggestionStrip({required this.onSelected, super.key});

  final ValueChanged<String> onSelected;

  static const List<String> _suggestions = <String>[
    'Summarize my day and tell me what still needs attention.',
    'Find my next lecture, including the room and when I should leave.',
    'Plan a focused study block around my timetable and open tasks.',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        StudyOsSpacing.md,
        0,
        StudyOsSpacing.md,
        StudyOsSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: StudyOsSpacing.xs,
        children: <Widget>[
          for (final suggestion in _suggestions)
            _SuggestionButton(
              label: suggestion,
              onPressed: () => onSelected(suggestion),
            ),
        ],
      ),
    );
  }
}

class _SuggestionButton extends StatelessWidget {
  const _SuggestionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: StudyOsColors.text, height: 1.28);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: StudyOsSpacing.md,
            vertical: StudyOsSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: StudyOsColors.surfaceRaised.withValues(alpha: 0.68),
            border: Border.all(color: StudyOsColors.border),
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
          ),
          child: Text(label, style: textStyle),
        ),
      ),
    );
  }
}
