import 'student_profile.dart';
import 'timetable_models.dart';

enum HomeFeedSourceStatus { fresh, stale, unavailable }

enum UrgentItemSeverity { info, warning }

class DailySummary {
  const DailySummary({required this.title, required this.body});

  final String title;
  final String body;
}

class NextAction {
  const NextAction({
    required this.title,
    required this.body,
    required this.label,
  });

  final String title;
  final String body;
  final String label;
}

class UrgentItem {
  const UrgentItem({
    required this.title,
    required this.body,
    this.severity = UrgentItemSeverity.info,
  });

  final String title;
  final String body;
  final UrgentItemSeverity severity;
}

class HomeFeedSourceFreshness {
  const HomeFeedSourceFreshness({
    required this.label,
    required this.status,
    this.fetchedAt,
  });

  final String label;
  final HomeFeedSourceStatus status;
  final DateTime? fetchedAt;

  String get statusLabel {
    return switch (status) {
      HomeFeedSourceStatus.fresh => 'Fresh',
      HomeFeedSourceStatus.stale => 'Stale',
      HomeFeedSourceStatus.unavailable => 'Unavailable',
    };
  }
}

class HomeFeedSnapshot {
  const HomeFeedSnapshot({
    required this.summary,
    required this.nextAction,
    required this.urgentItems,
    required this.sources,
    required this.generatedAt,
  });

  factory HomeFeedSnapshot.fromLocalState({
    required OnboardingProfile? profile,
    required TimetableSnapshot? timetable,
    required String memoryText,
    required DateTime now,
  }) {
    final nextLecture = timetable?.nextLectureAt(now);
    final todayCount = timetable?.eventsOn(now).length ?? 0;
    final urgentItems = <UrgentItem>[];

    if (nextLecture != null) {
      final startsIn = nextLecture.start.difference(now);
      if (!startsIn.isNegative && startsIn.inMinutes <= 30) {
        urgentItems.add(
          UrgentItem(
            title: 'Lecture soon',
            body:
                '${nextLecture.title} ${nextLecture.relativeTimeLabel(now)}'
                '${nextLecture.location == null ? '' : ' in ${nextLecture.location}'}',
            severity: UrgentItemSeverity.warning,
          ),
        );
      }
    }

    final summary = DailySummary(
      title: _summaryTitle(profile),
      body: _summaryBody(
        profile: profile,
        nextLecture: nextLecture,
        todayCount: todayCount,
        hasMemory: memoryText.trim().isNotEmpty,
        now: now,
      ),
    );

    return HomeFeedSnapshot(
      summary: summary,
      nextAction: _nextActionFor(
        profile: profile,
        timetable: timetable,
        nextLecture: nextLecture,
        memoryText: memoryText,
        now: now,
      ),
      urgentItems: List<UrgentItem>.unmodifiable(urgentItems),
      sources: List<HomeFeedSourceFreshness>.unmodifiable(
        _sourcesFor(timetable: timetable, memoryText: memoryText, now: now),
      ),
      generatedAt: now,
    );
  }

  final DailySummary summary;
  final NextAction nextAction;
  final List<UrgentItem> urgentItems;
  final List<HomeFeedSourceFreshness> sources;
  final DateTime generatedAt;

  bool get hasUrgentItems => urgentItems.isNotEmpty;
  bool get isStale =>
      sources.any((source) => source.status == HomeFeedSourceStatus.stale);
  String get generatedAtLabel => _time(generatedAt);
}

class FeedMessage {
  const FeedMessage({required this.title, required this.body});

  final String title;
  final String body;
}

class DailyBriefingState {
  const DailyBriefingState({
    required this.headline,
    required this.messages,
    required this.generatedAt,
  });

  factory DailyBriefingState.fromLocalState({
    required OnboardingProfile? profile,
    required TimetableSnapshot? timetable,
    required String memoryText,
    required DateTime now,
  }) {
    final snapshot = HomeFeedSnapshot.fromLocalState(
      profile: profile,
      timetable: timetable,
      memoryText: memoryText,
      now: now,
    );
    final messages = <FeedMessage>[
      FeedMessage(title: snapshot.summary.title, body: snapshot.summary.body),
    ];
    final nextAction = snapshot.nextAction;
    messages.add(FeedMessage(title: nextAction.title, body: nextAction.body));
    for (final item in snapshot.urgentItems) {
      messages.add(FeedMessage(title: item.title, body: item.body));
    }
    if (messages.isEmpty) {
      messages.add(
        FeedMessage(
          title: 'Nothing from my side right now.',
          body: profile == null
              ? 'No assistant update is available yet. Pull down to refresh or ask StudyOS about mail, schedules, campus places, or saved notes.'
              : 'No assistant update is available for your profile yet. Pull down to refresh or ask StudyOS about mail, schedules, campus places, or saved notes.',
        ),
      );
    }
    return DailyBriefingState(
      headline: 'Assistant summary',
      messages: List<FeedMessage>.unmodifiable(messages),
      generatedAt: now,
    );
  }

  final String headline;
  final List<FeedMessage> messages;
  final DateTime generatedAt;
}

String _summaryTitle(OnboardingProfile? profile) {
  return profile == null ? 'Set up your StudyOS' : 'Today at a glance';
}

String _summaryBody({
  required OnboardingProfile? profile,
  required LectureEvent? nextLecture,
  required int todayCount,
  required bool hasMemory,
  required DateTime now,
}) {
  if (profile == null) {
    return 'Connect your profile to unlock timetable, mail, campus, and route-aware suggestions.';
  }
  if (nextLecture != null) {
    final count = todayCount == 1 ? '1 lecture' : '$todayCount lectures';
    return 'You have $count today. Next: ${nextLecture.title} ${nextLecture.relativeTimeLabel(now)}.';
  }
  if (hasMemory) {
    return 'No lecture needs attention right now. Your saved notes are ready for assistant context.';
  }
  return 'Nothing urgent from my side right now. Ask StudyOS about schedule, mail, campus, or saved notes.';
}

NextAction _nextActionFor({
  required OnboardingProfile? profile,
  required TimetableSnapshot? timetable,
  required LectureEvent? nextLecture,
  required String memoryText,
  required DateTime now,
}) {
  if (profile == null) {
    return const NextAction(
      title: 'Complete profile',
      body: 'Tell StudyOS your degree and campus preferences to personalize the home feed.',
      label: 'Open settings',
    );
  }
  if (timetable == null || _isTimetableStale(timetable, now)) {
    return const NextAction(
      title: 'Refresh timetable',
      body: 'Sync your latest schedule so the feed can rank lectures and route hints.',
      label: 'Refresh',
    );
  }
  if (nextLecture != null) {
    return NextAction(
      title: 'Prepare for next lecture',
      body:
          '${nextLecture.title} ${nextLecture.relativeTimeLabel(now)}'
          '${nextLecture.location == null ? '' : ' in ${nextLecture.location}'}',
      label: 'Open schedule',
    );
  }
  if (memoryText.trim().isEmpty) {
    return const NextAction(
      title: 'Add study context',
      body: 'Save notes or preferences so the assistant can personalize future suggestions.',
      label: 'Open notes',
    );
  }
  return const NextAction(
    title: 'Ask StudyOS',
    body: 'No automatic action is urgent. Start with a question or plan your next study block.',
    label: 'Open chat',
  );
}

List<HomeFeedSourceFreshness> _sourcesFor({
  required TimetableSnapshot? timetable,
  required String memoryText,
  required DateTime now,
}) {
  return <HomeFeedSourceFreshness>[
    HomeFeedSourceFreshness(
      label: 'Timetable',
      status: timetable == null
          ? HomeFeedSourceStatus.unavailable
          : _isTimetableStale(timetable, now)
          ? HomeFeedSourceStatus.stale
          : HomeFeedSourceStatus.fresh,
      fetchedAt: timetable?.refreshedAt,
    ),
    HomeFeedSourceFreshness(
      label: 'Notes',
      status: memoryText.trim().isEmpty
          ? HomeFeedSourceStatus.unavailable
          : HomeFeedSourceStatus.fresh,
    ),
  ];
}

bool _isTimetableStale(TimetableSnapshot timetable, DateTime now) {
  return now.difference(timetable.refreshedAt) > const Duration(hours: 4);
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
