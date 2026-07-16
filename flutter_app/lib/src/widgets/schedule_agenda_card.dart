import 'package:flutter/material.dart';

import '../plan_models.dart';
import '../studyos_theme.dart';
import 'schedule_components.dart';

class ScheduleAgenda extends StatelessWidget {
  const ScheduleAgenda({
    required this.items,
    required this.nextItemId,
    super.key,
  });

  final List<PlanItem> items;
  final String? nextItemId;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const ScheduleMessageCard(
        icon: Icons.calendar_today_outlined,
        title: 'No items this day',
        body: 'Pick another day from the strip above.',
      );
    }
    return Material(
      color: StudyOsColors.surface,
      borderRadius: BorderRadius.circular(StudyOsRadii.md),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (var index = 0; index < items.length; index++) ...<Widget>[
            ScheduleAgendaCard(
              item: items[index],
              isNext: items[index].id == nextItemId,
            ),
            if (index < items.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 60),
                child: Divider(),
              ),
          ],
        ],
      ),
    );
  }
}

class ScheduleAgendaCard extends StatelessWidget {
  const ScheduleAgendaCard({
    required this.item,
    required this.isNext,
    super.key,
  });

  final PlanItem item;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isNow = item.isOngoingAt(now);
    final color = _sourceColor(item.source);
    final timeRailWidth = MediaQuery.textScalerOf(
      context,
    ).scale(50).clamp(50.0, 90.0);
    final course = item.source == PlanItemSource.alma
        ? _courseLabel(item.title)
        : _CourseLabel(title: item.title);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: StudyOsSpacing.md,
        vertical: StudyOsSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: timeRailWidth,
            child: _TimeLabel(item: item),
          ),
          Container(
            width: 3,
            height: 88,
            decoration: BoxDecoration(
              color: isNow ? StudyOsColors.accent : color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: StudyOsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(_sourceIcon(item.source), size: 14, color: color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _sourceLabel(item, course.code),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item.isSyncedToDevice) ...<Widget>[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.sync_rounded,
                        size: 13,
                        color: StudyOsColors.textMuted,
                      ),
                    ],
                    const Spacer(),
                    if (isNow || isNext)
                      Text(
                        isNow ? 'In progress' : 'Up next',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isNow
                              ? StudyOsColors.accent
                              : StudyOsColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  course.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (item.detail != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    item.detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (item.location != null) ...<Widget>[
                  const SizedBox(height: StudyOsSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: StudyOsColors.textMuted,
                      ),
                      const SizedBox(width: StudyOsSpacing.xs),
                      Expanded(
                        child: Text(
                          item.location!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.item});

  final PlanItem item;

  @override
  Widget build(BuildContext context) {
    if (item.isAllDay) {
      return Text('All day', style: Theme.of(context).textTheme.labelLarge);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          scheduleTime(item.start),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (item.end != null)
          Text(
            scheduleTime(item.end!),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    );
  }
}

String _sourceLabel(PlanItem item, String? courseCode) {
  if (courseCode != null) return '$courseCode · ${item.sourceName}';
  return item.sourceName;
}

IconData _sourceIcon(PlanItemSource source) => switch (source) {
  PlanItemSource.alma => Icons.menu_book_outlined,
  PlanItemSource.talk => Icons.record_voice_over_outlined,
  PlanItemSource.deviceCalendar => Icons.calendar_today_outlined,
};

Color _sourceColor(PlanItemSource source) => switch (source) {
  PlanItemSource.alma => const Color(0xFF2A9D8F),
  PlanItemSource.talk => const Color(0xFF8B5CF6),
  PlanItemSource.deviceCalendar => StudyOsColors.accent,
};

_CourseLabel _courseLabel(String value) {
  final match = RegExp(r'^([A-Z]{2,}[A-Z0-9-]*)\s+(.+)$').firstMatch(value);
  return match == null
      ? _CourseLabel(title: value)
      : _CourseLabel(code: match.group(1), title: match.group(2)!);
}

class _CourseLabel {
  const _CourseLabel({this.code, required this.title});

  final String? code;
  final String title;
}
