import 'models.dart';

Map<String, Object?> withProfileContext(
  Map<String, Object?> worldState,
  OnboardingProfile? profile, {
  TimetableSnapshot? timetable,
}) {
  if (profile == null && timetable == null) return worldState;
  return <String, Object?>{
    ...worldState,
    if (profile != null) ...<String, Object?>{
      'student': profile.displayName,
      'username': profile.username,
      if (profile.email != null && profile.email!.isNotEmpty)
        'email': profile.email,
      'degreeProgram': profile.degreeProgram,
      if (profile.semester != null) 'semester': profile.semester,
      'livesInTuebingen': profile.livesInTuebingen,
      if (profile.interests.isNotEmpty)
        'interests': profile.interests
            .map((interest) => interest.label)
            .toList(),
      if (profile.foodPreference != FoodPreference.noPreference)
        'foodPreference': profile.foodPreference.label,
      if (profile.notificationPreferences.isNotEmpty)
        'notificationPreferences': profile.notificationPreferences
            .map((preference) => preference.label)
            .toList(),
    },
    if (timetable?.nextLecture != null) ...<String, Object?>{
      'nextLecture': timetable!.nextLecture!.title,
      'nextLectureStartsAt': timetable.nextLecture!.start.toIso8601String(),
      if (timetable.nextLecture!.location != null)
        'nextLectureLocation': timetable.nextLecture!.location,
    },
  };
}
