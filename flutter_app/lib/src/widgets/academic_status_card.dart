import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

/// Renders an `academic_status` generative-UI component: exam/course entries
/// grouped by category with a status badge each. Read-only — a deliberate
/// example that the pattern handles no-action cards without an action callback.
class AcademicStatusCard extends StatelessWidget {
  const AcademicStatusCard({
    required this.component,
    this.compact = false,
    super.key,
  });

  final GeneratedUiComponent component;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCategory(component.arguments['entries']);
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
                      Icons.school_outlined,
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
                for (final group in grouped) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(
                      top: StudyOsSpacing.md,
                      bottom: StudyOsSpacing.xs,
                    ),
                    child: Text(
                      group.category.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: StudyOsColors.textMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  for (final entry in group.entries)
                    _EntryRow(entry: entry),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<_CategoryGroup> _groupByCategory(Object? raw) {
    if (raw is! List) return const <_CategoryGroup>[];
    final order = <String>[];
    final byCategory = <String, List<Map<String, Object?>>>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final entry = Map<String, Object?>.from(item);
      final category = entry['category']?.toString() ?? 'Other';
      if (!byCategory.containsKey(category)) {
        order.add(category);
        byCategory[category] = <Map<String, Object?>>[];
      }
      byCategory[category]!.add(entry);
    }
    return order
        .map((category) => _CategoryGroup(category, byCategory[category]!))
        .toList(growable: false);
  }
}

class _CategoryGroup {
  const _CategoryGroup(this.category, this.entries);

  final String category;
  final List<Map<String, Object?>> entries;
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final Map<String, Object?> entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = entry['title']?.toString() ?? '';
    final status = entry['status']?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: StudyOsSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: StudyOsColors.text,
              ),
            ),
          ),
          if (status.isNotEmpty) ...<Widget>[
            const SizedBox(width: StudyOsSpacing.sm),
            _StatusBadge(status: status),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(StudyOsRadii.sm),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Color _colorFor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('pass') ||
        normalized.contains('bestanden') ||
        normalized.contains('complete')) {
      return StudyOsColors.success;
    }
    if (normalized.contains('fail') ||
        normalized.contains('nicht') ||
        normalized.contains('overdue')) {
      return StudyOsColors.warning;
    }
    return StudyOsColors.accent;
  }
}
