import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

class ProactiveFeedSection extends StatelessWidget {
  const ProactiveFeedSection({
    required this.snapshot,
    required this.onRefresh,
    super.key,
  });

  final HomeFeedSnapshot snapshot;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final nextAction = snapshot.nextAction;
    return Material(
      color: StudyOsColors.surface,
      borderRadius: BorderRadius.circular(StudyOsRadii.md),
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.auto_awesome,
                  color: StudyOsColors.accent,
                  size: 20,
                ),
                const SizedBox(width: StudyOsSpacing.sm),
                Expanded(
                  child: Text(
                    snapshot.summary.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _TimeLeftPill(
                  label: snapshot.isStale
                      ? 'Stale'
                      : 'Updated ${snapshot.generatedAtLabel}',
                ),
              ],
            ),
            const SizedBox(height: StudyOsSpacing.md),
            Text(
              snapshot.summary.body,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: StudyOsSpacing.lg),
            _NextActionTile(action: nextAction, onRefresh: onRefresh),
            if (snapshot.hasUrgentItems) ...<Widget>[
              const SizedBox(height: StudyOsSpacing.md),
              for (final item in snapshot.urgentItems)
                _UrgentItemTile(item: item),
            ],
            const SizedBox(height: StudyOsSpacing.lg),
            Wrap(
              spacing: StudyOsSpacing.sm,
              runSpacing: StudyOsSpacing.sm,
              children: <Widget>[
                for (final source in snapshot.sources)
                  _SourceFreshnessPill(source: source),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NextActionTile extends StatelessWidget {
  const _NextActionTile({required this.action, required this.onRefresh});

  final NextAction action;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final isRefresh = action.label == 'Refresh';
    return Material(
      color: StudyOsColors.accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(StudyOsRadii.sm),
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.md),
        child: Row(
          children: <Widget>[
            const Icon(Icons.arrow_upward_rounded, color: StudyOsColors.accent),
            const SizedBox(width: StudyOsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    action.title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: StudyOsSpacing.xs),
                  Text(
                    action.body,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (isRefresh) ...<Widget>[
              const SizedBox(width: StudyOsSpacing.sm),
              TextButton(
                onPressed: () => onRefresh(),
                style: TextButton.styleFrom(
                  foregroundColor: StudyOsColors.accent,
                ),
                child: Text(action.label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UrgentItemTile extends StatelessWidget {
  const _UrgentItemTile({required this.item});

  final UrgentItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: StudyOsSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            item.severity == UrgentItemSeverity.warning
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            color: item.severity == UrgentItemSeverity.warning
                ? StudyOsColors.warning
                : StudyOsColors.accent,
          ),
          const SizedBox(width: StudyOsSpacing.sm),
          Expanded(
            child: Text(
              '${item.title}: ${item.body}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceFreshnessPill extends StatelessWidget {
  const _SourceFreshnessPill({required this.source});

  final HomeFeedSourceFreshness source;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudyOsColors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudyOsSpacing.sm,
          vertical: StudyOsSpacing.xs,
        ),
        child: Text(
          '${source.label}: ${source.statusLabel}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _TimeLeftPill extends StatelessWidget {
  const _TimeLeftPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudyOsColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudyOsSpacing.sm,
          vertical: StudyOsSpacing.xs,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: StudyOsColors.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
