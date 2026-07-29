import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

/// Renders a `mensa_menu` generative-UI component: canteen menu lines with their
/// dishes, dietary markers, and student price. Read-only.
class MensaCard extends StatelessWidget {
  const MensaCard({
    required this.component,
    this.compact = false,
    super.key,
  });

  final GeneratedUiComponent component;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final options = _options(component.arguments['options']);
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
                      Icons.restaurant_outlined,
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
                const SizedBox(height: StudyOsSpacing.sm),
                for (var i = 0; i < options.length; i++) ...<Widget>[
                  if (i > 0)
                    const Divider(height: 1, color: StudyOsColors.border),
                  _OptionRow(option: options[i]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<Map<String, Object?>> _options(Object? raw) {
    if (raw is! List) return const <Map<String, Object?>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option});

  final Map<String, Object?> option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = option['line']?.toString() ?? 'Menu';
    final price = option['price']?.toString().trim() ?? '';
    final items = (option['items'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .join(', ') ??
        '';
    final markers = (option['markers'] as List?)
            ?.map((marker) => marker.toString())
            .where((marker) => marker.isNotEmpty)
            .toList() ??
        const <String>[];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: StudyOsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  line,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: StudyOsColors.text,
                  ),
                ),
              ),
              if (price.isNotEmpty)
                Text(
                  price,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: StudyOsColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                items,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: StudyOsColors.text,
                ),
              ),
            ),
          if (markers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: StudyOsSpacing.xs),
              child: Wrap(
                spacing: StudyOsSpacing.xs,
                runSpacing: StudyOsSpacing.xs,
                children: markers
                    .map((marker) => _MarkerChip(label: marker))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarkerChip extends StatelessWidget {
  const _MarkerChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final vegetarian =
        label.toLowerCase().contains('veg'); // vegan/vegetarisch/vegetarian
    final color = vegetarian ? StudyOsColors.success : StudyOsColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(StudyOsRadii.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
