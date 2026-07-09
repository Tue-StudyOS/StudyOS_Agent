import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';
import '../widgets/schedule_components.dart';

class ScheduleView extends StatefulWidget {
  const ScheduleView({
    required this.profile,
    required this.snapshot,
    required this.error,
    required this.isRefreshing,
    required this.onRefresh,
    this.calendarSyncMessage,
    this.calendarSyncError,
    this.isSyncingCalendar = false,
    this.onSyncCalendar,
    super.key,
  });

  final OnboardingProfile? profile;
  final TimetableSnapshot? snapshot;
  final String? error;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final String? calendarSyncMessage;
  final String? calendarSyncError;
  final bool isSyncingCalendar;
  final Future<void> Function()? onSyncCalendar;

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final days = snapshot?.days ?? const <DateTime>[];
    final selectedDay = _visibleDay(days);
    final events = selectedDay == null
        ? const <LectureEvent>[]
        : snapshot!.eventsOn(selectedDay);
    final hasSyncableTimetable = snapshot != null && snapshot.events.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.only(top: StudyOsSpacing.sm),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Schedule',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: StudyOsSpacing.xs),
                  Text(
                    _subtitle(snapshot),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh timetable',
              onPressed: widget.isRefreshing ? null : widget.onRefresh,
              icon: widget.isRefreshing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: StudyOsSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            key: const ValueKey<String>('schedule-sync-calendar'),
            onPressed: hasSyncableTimetable && !widget.isSyncingCalendar
                ? widget.onSyncCalendar
                : null,
            icon: widget.isSyncingCalendar
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.event_available_outlined),
            label: Text(widget.isSyncingCalendar ? 'Syncing' : 'Sync calendar'),
          ),
        ),
        if (widget.error != null) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.md),
          ScheduleMessageCard(
            icon: Icons.warning_amber_rounded,
            title: 'Could not refresh timetable',
            body: widget.error!,
          ),
        ],
        if (widget.calendarSyncError != null) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.md),
          ScheduleMessageCard(
            icon: Icons.warning_amber_rounded,
            title: 'Calendar sync failed',
            body: widget.calendarSyncError!,
          ),
        ] else if (widget.calendarSyncMessage != null) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.md),
          ScheduleMessageCard(
            icon: Icons.check_circle_outline_rounded,
            title: 'Calendar synced',
            body: widget.calendarSyncMessage!,
          ),
        ],
        const SizedBox(height: StudyOsSpacing.lg),
        if (snapshot == null || snapshot.events.isEmpty)
          const ScheduleMessageCard(
            icon: Icons.calendar_month_outlined,
            title: 'No timetable synced yet',
            body: 'Refresh ALMA to load your upcoming lectures and rooms.',
          )
        else ...<Widget>[
          ScheduleDayStrip(
            days: days,
            selectedDay: selectedDay ?? days.first,
            eventsFor: snapshot.eventsOn,
            onSelected: (day) => setState(() => _selectedDay = day),
          ),
          const SizedBox(height: StudyOsSpacing.lg),
          ScheduleDayHeader(
            day: selectedDay ?? days.first,
            count: events.length,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          if (events.isEmpty)
            const ScheduleMessageCard(
              icon: Icons.calendar_today_outlined,
              title: 'No lectures this day',
              body: 'Pick another day from the strip above.',
            )
          else
            for (var index = 0; index < events.length; index++)
              ScheduleLectureCard(
                event: events[index],
                isFirst: index == 0,
                color: scheduleColorFor(events[index].title),
              ),
        ],
      ],
    );
  }

  DateTime? _visibleDay(List<DateTime> days) {
    if (days.isEmpty) return null;
    final selected = _selectedDay;
    if (selected != null && days.any((day) => scheduleSameDay(day, selected))) {
      return days.firstWhere((day) => scheduleSameDay(day, selected));
    }
    final today = DateTime.now();
    return days.firstWhere(
      (day) => !day.isBefore(DateTime(today.year, today.month, today.day)),
      orElse: () => days.first,
    );
  }

  String _subtitle(TimetableSnapshot? snapshot) {
    final profile = widget.profile;
    final details = <String>[
      if (snapshot != null) snapshot.sourceTerm,
      if (profile != null) profile.degreeProgram,
      if (snapshot != null) '${snapshot.events.length} entries',
    ];
    return details.isEmpty
        ? 'Upcoming lectures from ALMA.'
        : details.join(' · ');
  }
}
