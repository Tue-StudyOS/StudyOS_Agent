import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';

void main() {
  test('daily briefing falls back when no local state needs attention', () {
    final briefing = DailyBriefingState.fromLocalState(
      profile: null,
      timetable: null,
      memoryText: '',
      now: DateTime(2026, 7, 1, 9),
    );

    expect(briefing.headline, 'Assistant summary');
    expect(briefing.messages.single.title, 'Nothing from my side right now.');
    expect(
      briefing.messages.single.body,
      contains('No assistant update is available yet.'),
    );
  });

  test('daily briefing summarizes next lecture and today count', () {
    final now = DateTime(2026, 7, 1, 9);
    final snapshot = TimetableSnapshot(
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

    final briefing = DailyBriefingState.fromLocalState(
      profile: const OnboardingProfile(
        displayName: 'Ada',
        username: 'ada42',
        email: null,
        degreeProgram: 'M.Sc. AI',
        semester: 2,
        livesInTuebingen: true,
      ),
      timetable: snapshot,
      memoryText: '',
      now: now,
    );

    expect(briefing.headline, 'Assistant summary');
    expect(briefing.messages.first.title, 'Next lecture');
    expect(briefing.messages.first.body, 'Machine Learning in 1 h in Room A');
    expect(
      briefing.messages.last.body,
      'You have 1 lecture on the schedule today.',
    );
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
