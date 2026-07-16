import 'package:flutter/material.dart';

import '../studyos_theme.dart';

class SchedulePlanHeader extends StatelessWidget {
  const SchedulePlanHeader({
    required this.subtitle,
    required this.classCount,
    required this.talkCount,
    required this.calendarCount,
    required this.talksAvailable,
    required this.calendarAvailable,
    required this.isLoadingOverview,
    required this.isRefreshing,
    required this.isSyncing,
    required this.canSync,
    required this.onRefresh,
    required this.onSync,
    super.key,
  });

  final String subtitle;
  final int classCount;
  final int talkCount;
  final int calendarCount;
  final bool talksAvailable;
  final bool calendarAvailable;
  final bool isLoadingOverview;
  final bool isRefreshing;
  final bool isSyncing;
  final bool canSync;
  final VoidCallback onRefresh;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Plan',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Tooltip(
            message: 'Update the device calendar from ALMA',
            child: TextButton.icon(
              key: const ValueKey<String>('schedule-sync-calendar'),
              onPressed: canSync && !isSyncing ? onSync : null,
              icon: isSyncing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_rounded, size: 18),
              label: Text(isSyncing ? 'Updating' : 'Update'),
            ),
          ),
          IconButton(
            tooltip: 'Refresh all calendars',
            onPressed: isRefreshing ? null : onRefresh,
            style: IconButton.styleFrom(
              backgroundColor: StudyOsColors.surface,
              foregroundColor: StudyOsColors.accent,
            ),
            icon: isRefreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: StudyOsSpacing.md),
      Wrap(
        spacing: StudyOsSpacing.md,
        runSpacing: StudyOsSpacing.xs,
        children: <Widget>[
          _SourceCount(
            color: const Color(0xFF2A9D8F),
            label: classCount == 1 ? 'Class' : 'Classes',
            value: '$classCount',
          ),
          _SourceCount(
            color: const Color(0xFF8B5CF6),
            label: talkCount == 1 ? 'Talk' : 'Talks',
            value: isLoadingOverview
                ? '…'
                : talksAvailable
                ? '$talkCount'
                : '—',
          ),
          _SourceCount(
            color: StudyOsColors.accent,
            label: calendarCount == 1 ? 'Other event' : 'Other events',
            value: isLoadingOverview
                ? '…'
                : calendarAvailable
                ? '$calendarCount'
                : '—',
          ),
        ],
      ),
    ],
  );
}

class ScheduleNotice extends StatelessWidget {
  const ScheduleNotice({
    required this.icon,
    required this.title,
    required this.body,
    this.isSuccess = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? const Color(0xFF2A9D8F) : StudyOsColors.textMuted;
    return Material(
      color: StudyOsColors.surface,
      borderRadius: BorderRadius.circular(StudyOsRadii.md),
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: StudyOsSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(body, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCount extends StatelessWidget {
  const _SourceCount({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        '$value $label',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: StudyOsColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
