import 'dart:async';

import 'package:flutter/material.dart';

import '../studyos_theme.dart';

class ScheduleDayStrip extends StatefulWidget {
  const ScheduleDayStrip({
    required this.days,
    required this.selectedDay,
    required this.countFor,
    required this.onSelected,
    super.key,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final int Function(DateTime day) countFor;
  final ValueChanged<DateTime> onSelected;

  @override
  State<ScheduleDayStrip> createState() => _ScheduleDayStripState();
}

class _ScheduleDayStripState extends State<ScheduleDayStrip> {
  static const double _dayWidth = 56;
  static const double _dayStride = _dayWidth + StudyOsSpacing.sm;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _initialScrollOffset(),
    );
    _scheduleEnsureSelectedVisible(animate: false);
  }

  @override
  void didUpdateWidget(covariant ScheduleDayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIndex = _selectedIndex(oldWidget.days, oldWidget.selectedDay);
    final newIndex = _selectedIndex(widget.days, widget.selectedDay);
    if (!scheduleSameDay(oldWidget.selectedDay, widget.selectedDay) ||
        oldIndex != newIndex) {
      _scheduleEnsureSelectedVisible(animate: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessibilitySize = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    return SizedBox(
      height: accessibilitySize ? 88 : 72,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.days.length,
        separatorBuilder: (_, _) => const SizedBox(width: StudyOsSpacing.sm),
        itemBuilder: (context, index) {
          final day = widget.days[index];
          final selected = scheduleSameDay(day, widget.selectedDay);
          final count = widget.countFor(day);
          final foreground = selected ? Colors.white : StudyOsColors.text;
          final countLabel = count == 1 ? '1 item' : '$count items';
          return Semantics(
            button: true,
            selected: selected,
            label:
                '${scheduleWeekday(day)}, ${day.day} ${scheduleMonth(day)}, '
                '$countLabel',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: _dayWidth,
              decoration: BoxDecoration(
                color: selected ? StudyOsColors.accent : StudyOsColors.surface,
                borderRadius: BorderRadius.circular(StudyOsRadii.md),
              ),
              child: InkWell(
                onTap: () => widget.onSelected(day),
                borderRadius: BorderRadius.circular(StudyOsRadii.md),
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (!accessibilitySize)
                        Text(
                          scheduleShortWeekday(day),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.82)
                                    : StudyOsColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      Text(
                        '${day.day}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (!accessibilitySize) ...<Widget>[
                        const SizedBox(height: 2),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.2)
                                : StudyOsColors.background,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _initialScrollOffset() {
    final index = _selectedIndex(widget.days, widget.selectedDay);
    return index <= 0 ? 0 : (index - 1) * _dayStride;
  }

  void _scheduleEnsureSelectedVisible({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureSelectedVisible(animate: animate);
    });
  }

  void _ensureSelectedVisible({required bool animate}) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    final index = _selectedIndex(widget.days, widget.selectedDay);
    if (index < 0) return;

    final itemStart = index * _dayStride;
    final itemEnd = itemStart + _dayWidth;
    final visibleStart = position.pixels;
    final visibleEnd = visibleStart + position.viewportDimension;
    if (itemStart >= visibleStart && itemEnd <= visibleEnd) return;

    final requestedOffset = itemStart < visibleStart
        ? itemStart - StudyOsSpacing.sm
        : itemEnd - position.viewportDimension + StudyOsSpacing.sm;
    final target = requestedOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < 0.5) return;
    if (!animate) {
      _scrollController.jumpTo(target);
      return;
    }
    unawaited(
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  int _selectedIndex(List<DateTime> days, DateTime selectedDay) =>
      days.indexWhere((day) => scheduleSameDay(day, selectedDay));
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
        count == 1 ? '1 calendar item' : '$count calendar items',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );
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
