import 'student_profile.dart';
import 'timetable_models.dart';

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
    final messages = <FeedMessage>[];
    final nextLecture = timetable?.nextLectureAt(now);
    if (nextLecture != null) {
      messages.add(
        FeedMessage(
          title: 'Next lecture',
          body:
              '${nextLecture.title} ${nextLecture.relativeTimeLabel(now)}'
              '${nextLecture.location == null ? '' : ' in ${nextLecture.location}'}',
        ),
      );
    }
    final todayCount = timetable?.eventsOn(now).length ?? 0;
    if (todayCount > 0) {
      messages.add(
        FeedMessage(
          title: 'Daily plan',
          body: todayCount == 1
              ? 'You have 1 lecture on the schedule today.'
              : 'You have $todayCount lectures on the schedule today.',
        ),
      );
    }
    if (memoryText.trim().isNotEmpty) {
      messages.add(
        const FeedMessage(
          title: 'Notes',
          body: 'Saved study notes are available for assistant context.',
        ),
      );
    }
    return DailyBriefingState(
      headline: 'Assistant summary',
      messages: messages.isEmpty
          ? <FeedMessage>[
              FeedMessage(
                title: 'Nothing from my side right now.',
                body: profile == null
                    ? 'No assistant update is available yet. Pull down to refresh or ask StudyOS about mail, schedules, campus places, or saved notes.'
                    : 'No assistant update is available for your profile yet. Pull down to refresh or ask StudyOS about mail, schedules, campus places, or saved notes.',
              ),
            ]
          : List<FeedMessage>.unmodifiable(messages),
      generatedAt: now,
    );
  }

  final String headline;
  final List<FeedMessage> messages;
  final DateTime generatedAt;
}
