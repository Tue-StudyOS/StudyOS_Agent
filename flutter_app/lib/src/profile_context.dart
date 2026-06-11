import 'models.dart';

Map<String, Object?> withProfileContext(
  Map<String, Object?> worldState,
  OnboardingProfile? profile,
) {
  if (profile == null) return worldState;
  return <String, Object?>{
    ...worldState,
    'student': profile.displayName,
    'degreeProgram': profile.degreeProgram,
    if (profile.semester != null) 'semester': profile.semester,
    'livesInTuebingen': profile.livesInTuebingen,
  };
}
