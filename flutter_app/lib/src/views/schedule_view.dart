import 'dart:async';

import 'package:flutter/material.dart';

import '../calendar_overview_repository.dart';
import '../device_calendar_event.dart';
import '../models.dart';
import '../plan_models.dart';
import '../studyos_theme.dart';
import '../talk_models.dart';
import '../widgets/academic_status_section.dart';
import '../widgets/schedule_agenda_card.dart';
import '../widgets/schedule_components.dart';
import '../widgets/schedule_plan_header.dart';

class ScheduleView extends StatefulWidget {
  const ScheduleView({
    required this.snapshot,
    required this.error,
    required this.isRefreshing,
    required this.onRefresh,
    required this.calendarOverviewSource,
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

  final TimetableSnapshot? snapshot;
  final String? error;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final CalendarOverviewSource calendarOverviewSource;
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
  CalendarOverviewSnapshot _overview = CalendarOverviewSnapshot.empty;
  bool _isLoadingOverview = true;
  int _overviewRequest = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_refreshOverview());
  }

  @override
  Widget build(BuildContext context) {
    final items = buildPlanItems(
      lectures: widget.snapshot?.events ?? const <LectureEvent>[],
      talks: _overview.talks,
      deviceEvents: _overview.deviceEvents,
    );
    final days = planDays(items);
    final selectedDay = _visibleDay(days);
    final selectedItems = selectedDay == null
        ? const <PlanItem>[]
        : planItemsOn(items, selectedDay);
    final nextItem = _nextItem(items, DateTime.now());
    final classCount = items
        .where((item) => item.source == PlanItemSource.alma)
        .length;
    final talkCount = items
        .where((item) => item.source == PlanItemSource.talk)
        .length;
    final calendarCount = items
        .where((item) => item.source == PlanItemSource.deviceCalendar)
        .length;
    final hasSyncableTimetable = widget.snapshot != null;

    return ListView(
      padding: const EdgeInsets.only(
        top: StudyOsSpacing.xl,
        bottom: StudyOsSpacing.xxl,
      ),
      children: <Widget>[
        SchedulePlanHeader(
          subtitle:
              widget.snapshot?.sourceTerm ??
              'Classes, Tübingen Talks, and your device calendar',
          classCount: classCount,
          talkCount: talkCount,
          calendarCount: calendarCount,
          talksAvailable: _overview.talksError == null,
          calendarAvailable: _overview.deviceCalendarError == null,
          isLoadingOverview: _isLoadingOverview,
          isRefreshing: widget.isRefreshing || _isLoadingOverview,
          isSyncing: widget.isSyncingCalendar,
          canSync: hasSyncableTimetable,
          onRefresh: _refreshAll,
          onSync: _syncCalendar,
        ),
        if (widget.error != null) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.md),
          ScheduleNotice(
            icon: Icons.warning_amber_rounded,
            title: 'ALMA timetable unavailable',
            body: widget.error!,
          ),
        ],
        if (_sourceError != null) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.md),
          ScheduleNotice(
            icon: Icons.info_outline_rounded,
            title: 'Some calendars are unavailable',
            body: _sourceError!,
          ),
        ],
        if (widget.calendarSyncError != null) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.md),
          ScheduleNotice(
            icon: Icons.warning_amber_rounded,
            title: 'Device calendar update failed',
            body: widget.calendarSyncError!,
          ),
        ] else if (widget.calendarSyncMessage != null) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.md),
          ScheduleNotice(
            icon: Icons.check_circle_outline_rounded,
            title: 'Device calendar updated',
            body: widget.calendarSyncMessage!,
            isSuccess: true,
          ),
        ],
        const SizedBox(height: StudyOsSpacing.lg),
        if (_isLoadingOverview && items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: StudyOsSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          const ScheduleMessageCard(
            icon: Icons.calendar_month_outlined,
            title: 'Nothing scheduled',
            body: 'Refresh to load ALMA, Talks, and your device calendar.',
          )
        else ...<Widget>[
          ScheduleDayStrip(
            days: days,
            selectedDay: selectedDay ?? days.first,
            countFor: (day) => planItemsOn(items, day).length,
            onSelected: (day) => setState(() => _selectedDay = day),
          ),
          const SizedBox(height: StudyOsSpacing.lg),
          ScheduleDayHeader(
            day: selectedDay ?? days.first,
            count: selectedItems.length,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          ScheduleAgenda(items: selectedItems, nextItemId: nextItem?.id),
        ],
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
    );
  }

  String? get _sourceError {
    final messages = <String>[
      if (_overview.talksError != null) 'Talks: ${_overview.talksError}',
      if (_overview.deviceCalendarError != null)
        'Calendar: ${_overview.deviceCalendarError}',
      if (_overview.deviceCalendarTruncated)
        'Calendar: showing the first 250 events in this date range.',
    ];
    return messages.isEmpty ? null : messages.join('\n');
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>(<Future<void>>[
      widget.onRefresh(),
      _refreshOverview(refreshTalks: true),
    ]);
  }

  Future<void> _syncCalendar() async {
    await widget.onSyncCalendar?.call();
    await _refreshOverview();
  }

  Future<void> _refreshOverview({bool refreshTalks = false}) async {
    final request = ++_overviewRequest;
    if (mounted) setState(() => _isLoadingOverview = true);
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 7));
    final end = start.add(const Duration(days: 127));
    CalendarOverviewSnapshot overview;
    try {
      overview = await widget.calendarOverviewSource.load(
        start: start,
        end: end,
        refreshTalks: refreshTalks,
      );
    } on Object catch (error) {
      final message = 'Calendar overview could not refresh: $error';
      overview = CalendarOverviewSnapshot(
        talks: const <Talk>[],
        deviceEvents: const <DeviceCalendarEvent>[],
        talksError: message,
        deviceCalendarError: message,
      );
    }
    if (!mounted || request != _overviewRequest) return;
    setState(() {
      _overview = overview;
      _isLoadingOverview = false;
    });
  }

  DateTime? _visibleDay(List<DateTime> days) {
    if (days.isEmpty) return null;
    final selected = _selectedDay;
    if (selected != null && days.any((day) => scheduleSameDay(day, selected))) {
      return days.firstWhere((day) => scheduleSameDay(day, selected));
    }
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return days.firstWhere(
      (day) => !day.isBefore(startOfToday),
      orElse: () => days.first,
    );
  }

  PlanItem? _nextItem(List<PlanItem> items, DateTime now) {
    for (final item in items) {
      if (item.end?.isAfter(now) == true || item.start.isAfter(now)) {
        return item;
      }
    }
    return null;
  }
}
