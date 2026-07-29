import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

/// Renders a `schedule_agenda` generative-UI component: upcoming lectures
/// grouped by day, each with its time range and room. Read-only.
class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    required this.component,
    this.compact = false,
    super.key,
  });

  final GeneratedUiComponent component;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final days = _groupByDay(component.arguments['events']);
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
                      Icons.calendar_month_outlined,
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
                for (final day in days) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(
                      top: StudyOsSpacing.md,
                      bottom: StudyOsSpacing.xs,
                    ),
                    child: Text(
                      day.label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: StudyOsColors.textMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  for (final event in day.events) _EventRow(event: event),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<_DayGroup> _groupByDay(Object? raw) {
    if (raw is! List) return const <_DayGroup>[];
    final order = <String>[];
    final byDay = <String, _DayGroup>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final event = Map<String, Object?>.from(item);
      final start = DateTime.tryParse(event['start']?.toString() ?? '')
          ?.toLocal();
      if (start == null) continue;
      final key =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-'
          '${start.day.toString().padLeft(2, '0')}';
      final group = byDay.putIfAbsent(key, () {
        order.add(key);
        return _DayGroup(_dayLabel(start));
      });
      group.events.add(event);
    }
    return order.map((key) => byDay[key]!).toList(growable: false);
  }
}

class _DayGroup {
  _DayGroup(this.label);

  final String label;
  final List<Map<String, Object?>> events = <Map<String, Object?>>[];
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final Map<String, Object?> event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = event['title']?.toString() ?? 'Lecture';
    final location = event['location']?.toString().trim() ?? '';
    final start = DateTime.tryParse(event['start']?.toString() ?? '')?.toLocal();
    final end = DateTime.tryParse(event['end']?.toString() ?? '')?.toLocal();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: StudyOsSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              _timeRange(start, end),
              style: theme.textTheme.bodySmall?.copyWith(
                color: StudyOsColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: StudyOsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: StudyOsColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (location.isNotEmpty)
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: StudyOsColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _timeRange(DateTime? start, DateTime? end) {
  if (start == null) return '';
  final startText = _time(start);
  if (end == null) return startText;
  return '$startText–${_time(end)}';
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _dayLabel(DateTime day) {
  const weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[day.weekday - 1]} ${day.day} ${months[day.month - 1]}';
}
