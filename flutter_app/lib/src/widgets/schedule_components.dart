import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

class ScheduleDayStrip extends StatelessWidget {
  const ScheduleDayStrip({
    required this.days,
    required this.selectedDay,
    required this.eventsFor,
    required this.onSelected,
    super.key,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final List<LectureEvent> Function(DateTime day) eventsFor;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = scheduleSameDay(day, selectedDay);
          final count = eventsFor(day).length;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onSelected(day),
            label: SizedBox(
              width: 68,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(scheduleShortWeekday(day), maxLines: 1),
                  Text('${day.day}.${day.month}.', maxLines: 1),
                  Text('$count', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: StudyOsSpacing.sm),
        itemCount: days.length,
      ),
    );
  }
}

class ScheduleDayHeader extends StatelessWidget {
  const ScheduleDayHeader({required this.day, required this.count, super.key});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final noun = count == 1 ? 'lecture' : 'lectures';
    return Text(
      '${scheduleWeekday(day)} ${day.day}.${day.month}. · $count $noun',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class ScheduleLectureCard extends StatelessWidget {
  const ScheduleLectureCard({
    required this.event,
    required this.isFirst,
    required this.color,
    super.key,
  });

  final LectureEvent event;
  final bool isFirst;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isNow = event.isOngoingAt(now);
    final timeLeftLabel = event.relativeTimeLabel(now);
    final timeLeftColor = event.hasEndedAt(now)
        ? StudyOsColors.textMuted
        : color;
    return Container(
      margin: const EdgeInsets.only(bottom: StudyOsSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 6,
            height: 112,
            margin: const EdgeInsets.all(StudyOsSpacing.sm),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                StudyOsSpacing.sm,
                StudyOsSpacing.md,
                StudyOsSpacing.md,
                StudyOsSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          event.timeRangeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(width: StudyOsSpacing.xs),
                      Flexible(
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: StudyOsSpacing.xs,
                          runSpacing: StudyOsSpacing.xs,
                          children: <Widget>[
                            _ScheduleBadge(
                              text: timeLeftLabel,
                              color: timeLeftColor,
                            ),
                            if (isNow || isFirst)
                              _ScheduleBadge(
                                text: isNow ? 'Now' : 'Next',
                                color: color,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: StudyOsSpacing.sm),
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (event.location != null) ...<Widget>[
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
                            event.location!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleMessageCard extends StatelessWidget {
  const ScheduleMessageCard({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudyOsSpacing.xl),
      decoration: BoxDecoration(
        color: StudyOsColors.surface,
        border: Border.all(color: StudyOsColors.border),
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: StudyOsColors.accent),
          const SizedBox(height: StudyOsSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StudyOsSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ScheduleBadge extends StatelessWidget {
  const _ScheduleBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}

bool scheduleSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String scheduleShortWeekday(DateTime day) =>
    scheduleWeekday(day).substring(0, 3);

String scheduleWeekday(DateTime day) {
  const names = <int, String>{
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
  };
  return names[day.weekday] ?? 'Day';
}

Color scheduleColorFor(String title) {
  const colors = <Color>[
    Color(0xFFE85D75),
    Color(0xFFF4A261),
    Color(0xFF5EA8FF),
    Color(0xFF2A9D8F),
    Color(0xFF3DDC97),
    Color(0xFFD67AD2),
    Color(0xFF8EA7FF),
  ];
  final seed = title.runes.fold<int>(0, (sum, rune) => sum + rune);
  return colors[seed % colors.length];
}
