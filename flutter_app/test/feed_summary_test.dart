import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';

void main() {
  test('home feed snapshot falls back when no local state needs attention', () {
    final snapshot = HomeFeedSnapshot.fromLocalState(
      profile: null,
      timetable: null,
      memoryText: '',
      now: DateTime(2026, 7, 1, 9),
    );

    expect(snapshot.summary.title, 'Set up your StudyOS');
    expect(snapshot.summary.body, contains('Connect your profile'));
    expect(snapshot.nextAction.title, 'Complete profile');
    expect(snapshot.sources.first.status, HomeFeedSourceStatus.unavailable);
  });

  test('home feed snapshot summarizes next lecture and freshness', () {
    final now = DateTime(2026, 7, 1, 9);
    final timetable = TimetableSnapshot(
      refreshedAt: now,
      sourceTerm: 'Summer 2026',
      events: <LectureEvent>[
        LectureEvent(
          id: 'ml',
          title: 'Machine Learning',
          start: DateTime(2026, 7, 1, 10),
          end: DateTime(2026, 7, 1, 12),
          location: 'Room A',
        ),
      ],
    );

    final snapshot = HomeFeedSnapshot.fromLocalState(
      profile: const OnboardingProfile(
        displayName: 'Ada',
        username: 'ada42',
        email: null,
        degreeProgram: 'M.Sc. AI',
        semester: 2,
        livesInTuebingen: true,
      ),
      timetable: timetable,
      memoryText: '',
      now: now,
    );

    expect(snapshot.summary.title, 'Today at a glance');
    expect(snapshot.summary.body, contains('Machine Learning in 1 h'));
    expect(snapshot.nextAction.title, 'Prepare for next lecture');
    expect(snapshot.nextAction.body, 'Machine Learning in 1 h in Room A');
    expect(snapshot.sources.first.status, HomeFeedSourceStatus.fresh);
  });

  test('home feed does not duplicate the next lecture action as urgent', () {
    final now = DateTime(2026, 7, 1, 9);
    final snapshot = HomeFeedSnapshot.fromLocalState(
      profile: const OnboardingProfile(
        displayName: 'Ada',
        username: 'ada42',
        email: null,
        degreeProgram: 'M.Sc. AI',
        semester: 2,
        livesInTuebingen: true,
      ),
      timetable: TimetableSnapshot(
        refreshedAt: now,
        sourceTerm: 'Summer 2026',
        events: <LectureEvent>[
          LectureEvent(
            id: 'seminar',
            title: 'Seminar',
            start: now.add(const Duration(minutes: 20)),
            end: now.add(const Duration(hours: 2)),
          ),
        ],
      ),
      memoryText: '',
      now: now,
    );

    expect(snapshot.nextAction.title, 'Prepare for next lecture');
    expect(snapshot.hasUrgentItems, isFalse);
  });

  test('home feed keeps soon lecture warning when timetable needs refresh', () {
    final now = DateTime(2026, 7, 1, 9);
    final snapshot = HomeFeedSnapshot.fromLocalState(
      profile: const OnboardingProfile(
        displayName: 'Ada',
        username: 'ada42',
        email: null,
        degreeProgram: 'M.Sc. AI',
        semester: 2,
        livesInTuebingen: true,
      ),
      timetable: TimetableSnapshot(
        refreshedAt: now.subtract(const Duration(hours: 5)),
        sourceTerm: 'Summer 2026',
        events: <LectureEvent>[
          LectureEvent(
            id: 'seminar',
            title: 'Seminar',
            start: now.add(const Duration(minutes: 20)),
            end: now.add(const Duration(hours: 2)),
          ),
        ],
      ),
      memoryText: '',
      now: now,
    );

    expect(snapshot.nextAction.title, 'Refresh timetable');
    expect(snapshot.hasUrgentItems, isTrue);
    expect(snapshot.urgentItems.single.title, 'Lecture soon');
  });

  test('lecture relative time labels cover upcoming and terminal states', () {
    final base = DateTime(2026, 7, 1, 9);
    final event = LectureEvent(
      id: 'seminar',
      title: 'Seminar',
      start: DateTime(2026, 7, 1, 9, 30),
      end: DateTime(2026, 7, 1, 10, 30),
    );

    expect(event.relativeTimeLabel(base), 'in 30 min');
    expect(event.relativeTimeLabel(DateTime(2026, 7, 1, 9, 26)), 'starts soon');
    expect(event.relativeTimeLabel(DateTime(2026, 7, 1, 10)), 'ongoing');
    expect(event.relativeTimeLabel(DateTime(2026, 7, 1, 10, 30)), 'ended');
  });

  test('next lecture lookup includes ongoing lectures', () {
    final now = DateTime(2026, 7, 1, 10);
    final snapshot = TimetableSnapshot(
      refreshedAt: now,
      sourceTerm: 'Summer 2026',
      events: <LectureEvent>[
        LectureEvent(
          id: 'studio',
          title: 'Project Studio',
          start: DateTime(2026, 7, 1, 9),
          end: DateTime(2026, 7, 1, 11),
        ),
      ],
    );

    expect(snapshot.nextLectureAt(now)?.title, 'Project Studio');
    expect(snapshot.nextLectureAt(now)?.relativeTimeLabel(now), 'ongoing');
  });
}
