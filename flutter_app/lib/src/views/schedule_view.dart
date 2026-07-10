import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';
import '../widgets/schedule_components.dart';
import '../widgets/academic_status_section.dart';

class ScheduleView extends StatefulWidget {
  const ScheduleView({
    required this.profile,
    required this.snapshot,
    required this.error,
    required this.isRefreshing,
    required this.onRefresh,
    this.academicStatus,
    this.academicStatusError,
    this.isRefreshingAcademicStatus = false,
    this.onRefreshAcademicStatus,
    this.academicReportError,
    this.isOpeningAcademicReport = false,
    this.onOpenAcademicReport,
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
  final AcademicStatusSnapshot? academicStatus;
  final String? academicStatusError;
  final bool isRefreshingAcademicStatus;
  final Future<void> Function()? onRefreshAcademicStatus;
  final String? academicReportError;
  final bool isOpeningAcademicReport;
  final Future<void> Function()? onOpenAcademicReport;
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
    final nextEvent = _nextEvent(events, DateTime.now());
    final hasSyncableTimetable = snapshot != null && snapshot.events.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.only(
        top: StudyOsSpacing.xl,
        bottom: StudyOsSpacing.xxl,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Plan',
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
            _RefreshButton(
              isRefreshing: widget.isRefreshing,
              onPressed: widget.onRefresh,
            ),
          ],
        ),
        const SizedBox(height: StudyOsSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
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
            label: Text(
              widget.isSyncingCalendar
                  ? 'Syncing calendar'
                  : 'Sync to Calendar',
            ),
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
            Material(
              color: StudyOsColors.surface,
              borderRadius: BorderRadius.circular(StudyOsRadii.md),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(StudyOsRadii.md),
                child: Column(
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < events.length;
                      index++
                    ) ...<Widget>[
                      ScheduleLectureCard(
                        event: events[index],
                        isNext: events[index].id == nextEvent?.id,
                        color: scheduleColorFor(events[index].title),
                      ),
                      if (index < events.length - 1)
                        const Padding(
                          padding: EdgeInsets.only(left: 60),
                          child: Divider(),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: StudyOsSpacing.xxl),
          AcademicStatusSection(
            snapshot: widget.academicStatus,
            error: widget.academicStatusError,
            isRefreshing: widget.isRefreshingAcademicStatus,
            onRefresh: widget.onRefreshAcademicStatus ?? () async {},
            reportError: widget.academicReportError,
            isOpeningReport: widget.isOpeningAcademicReport,
            onOpenReport: widget.onOpenAcademicReport ?? () async {},
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

  LectureEvent? _nextEvent(List<LectureEvent> events, DateTime now) {
    for (final event in events) {
      if (event.start.isAfter(now)) return event;
    }
    return null;
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.isRefreshing, required this.onPressed});

  final bool isRefreshing;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Refresh timetable',
    onPressed: isRefreshing ? null : onPressed,
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
  );
}
