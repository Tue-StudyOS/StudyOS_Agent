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
  Widget build(BuildContext context) => SizedBox(
    height: 68,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: days.length,
      separatorBuilder: (_, _) => const SizedBox(width: StudyOsSpacing.sm),
      itemBuilder: (context, index) {
        final day = days[index];
        final selected = scheduleSameDay(day, selectedDay);
        final count = eventsFor(day).length;
        final foreground = selected ? Colors.white : StudyOsColors.text;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 58,
          decoration: BoxDecoration(
            color: selected ? StudyOsColors.accent : StudyOsColors.surface,
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
          ),
          child: InkWell(
            onTap: () => onSelected(day),
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  scheduleShortWeekday(day),
                  style: TextStyle(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.8)
                        : StudyOsColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (count > 0)
                  Text(
                    count == 1 ? '1 session' : '$count sessions',
                    style: TextStyle(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.8)
                          : StudyOsColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class ScheduleDayHeader extends StatelessWidget {
  const ScheduleDayHeader({required this.day, required this.count, super.key});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        '${scheduleWeekday(day)}, ${day.day} ${scheduleMonth(day)}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 2),
      Text(
        count == 1 ? '1 scheduled session' : '$count scheduled sessions',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );
}

class ScheduleLectureCard extends StatelessWidget {
  const ScheduleLectureCard({
    required this.event,
    required this.isNext,
    required this.color,
    super.key,
  });

  final LectureEvent event;
  final bool isNext;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isNow = event.isOngoingAt(now);
    final course = _courseLabel(event.title);
    final state = isNow
        ? 'In progress'
        : isNext
        ? 'Up next'
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: StudyOsSpacing.md,
        vertical: StudyOsSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  scheduleTime(event.start),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (event.end != null)
                  Text(
                    scheduleTime(event.end!),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
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
                    if (course.code != null) ...<Widget>[
                      Text(
                        course.code!,
                        style: TextStyle(
                          color: isNow ? StudyOsColors.accent : color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.15,
                        ),
                      ),
                      const Spacer(),
                    ],
                    if (state != null)
                      Text(
                        state,
                        style: TextStyle(
                          color: isNow
                              ? StudyOsColors.accent
                              : StudyOsColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (course.code != null) const SizedBox(height: 2),
                Text(
                  course.title,
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
  Widget build(BuildContext context) => Container(
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

String scheduleMonth(DateTime day) {
  const names = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[day.month - 1];
}

String scheduleTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

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
