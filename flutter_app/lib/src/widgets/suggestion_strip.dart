import 'package:flutter/material.dart';

import '../studyos_theme.dart';

class SuggestionStrip extends StatelessWidget {
  const SuggestionStrip({required this.onSelected, super.key});

  final ValueChanged<String> onSelected;

  static const List<String> _suggestions = <String>[
    'Summarize today',
    'Find next lecture',
    'Plan study block',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: StudyOsSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 560;
          return Wrap(
            spacing: StudyOsSpacing.sm,
            runSpacing: StudyOsSpacing.sm,
            children: <Widget>[
              for (final suggestion in _suggestions)
                SizedBox(
                  width: isWide
                      ? (constraints.maxWidth - StudyOsSpacing.sm * 2) / 3
                      : null,
                  child: _SuggestionButton(
                    label: suggestion,
                    onPressed: () => onSelected(suggestion),
                  ),
                ),
            ],
          );
        },
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
    return ActionChip(
      avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
      label: Text(label),
      backgroundColor: StudyOsColors.surfaceRaised,
      side: const BorderSide(color: StudyOsColors.border),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: StudyOsColors.text, fontSize: 13),
      onPressed: onPressed,
    );
  }
}
