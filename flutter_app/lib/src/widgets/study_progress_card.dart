import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

/// Renders a `study_progress` generative-UI component: an overall ECTS progress
/// bar plus a per-module breakdown with mini bars. Read-only.
class StudyProgressCard extends StatelessWidget {
  const StudyProgressCard({
    required this.component,
    this.compact = false,
    super.key,
  });

  final GeneratedUiComponent component;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final modules = _modules(component.arguments['modules']);
    final totalEarned = _double(component.arguments['total_earned']);
    final totalRequired = _double(component.arguments['total_required']);
    final theme = Theme.of(context);
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
                      Icons.donut_large_outlined,
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
                if (totalEarned != null && totalRequired != null) ...<Widget>[
                  const SizedBox(height: StudyOsSpacing.sm),
                  _ProgressBar(
                    earned: totalEarned,
                    required: totalRequired,
                    label:
                        'Overall · ${_trim(totalEarned)} / '
                        '${_trim(totalRequired)} ECTS',
                    emphasized: true,
                  ),
                ],
                const SizedBox(height: StudyOsSpacing.sm),
                for (final module in modules)
                  Padding(
                    padding: const EdgeInsets.only(top: StudyOsSpacing.sm),
                    child: _ModuleRow(module: module),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<Map<String, Object?>> _modules(Object? raw) {
    if (raw is! List) return const <Map<String, Object?>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module});

  final Map<String, Object?> module;

  @override
  Widget build(BuildContext context) {
    final title = module['title']?.toString() ?? 'Module';
    final earned = _double(module['earned']);
    final required = _double(module['required']);
    final summary =
        module['summary']?.toString() ??
        (earned != null && required != null
            ? '${_trim(earned)} / ${_trim(required)} ECTS'
            : '');
    if (earned == null || required == null || required <= 0) {
      return Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: StudyOsColors.text,
              ),
            ),
          ),
          if (summary.isNotEmpty)
            Text(
              summary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: StudyOsColors.textMuted,
              ),
            ),
        ],
      );
    }
    return _ProgressBar(
      earned: earned,
      required: required,
      label: '$title · $summary',
      emphasized: false,
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.earned,
    required this.required,
    required this.label,
    required this.emphasized,
  });

  final double earned;
  final double required;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final fraction = required <= 0 ? 0.0 : (earned / required).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: StudyOsColors.text,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(StudyOsRadii.sm),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: emphasized ? 8 : 6,
            backgroundColor: StudyOsColors.background.withValues(alpha: 0.6),
            valueColor: AlwaysStoppedAnimation<Color>(
              fraction >= 1.0 ? StudyOsColors.success : StudyOsColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _trim(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();
