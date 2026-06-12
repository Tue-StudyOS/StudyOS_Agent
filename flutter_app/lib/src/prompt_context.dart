import 'models.dart';

class PromptContext {
  const PromptContext({
    required this.profile,
    required this.memory,
    required this.worldState,
    this.timetable,
  });

  final OnboardingProfile? profile;
  final String memory;
  final Map<String, Object?> worldState;
  final TimetableSnapshot? timetable;

  String systemPrompt() {
    final now = DateTime.now().toLocal();
    final buffer = StringBuffer()
      ..writeln('You are StudyOS Agent, a tool-grounded study agent.')
      ..writeln('Current local timestamp: ${now.toIso8601String()}.')
      ..writeln('Use Markdown when formatting helps readability.')
      ..writeln('Call at least one available StudyOS tool before answering.')
      ..writeln(
        'Ground every factual study answer in tool results or provided context.',
      )
      ..writeln(
        'When the user asks you to remember, save, or update a durable preference or fact, call append_memory with a concise memory.',
      )
      ..writeln(
        'If required data is unavailable, say what is missing instead of guessing.',
      )
      ..writeln('Do not expose secrets or credentials.');
    final profileBlock = _profileBlock();
    if (profileBlock.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Student profile:')
        ..write(profileBlock);
    }
    if (memory.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Long-term memory:')
        ..writeln(memory.trim());
    }
    final timetableBlock = timetable?.compactSummary(limit: 5);
    if (timetableBlock != null && timetableBlock.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Cached timetable summary:')
        ..writeln(timetableBlock.trim());
    }
    if (worldState.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Current local context:')
        ..writeln(worldState.toString());
    }
    return buffer.toString().trim();
  }

  String _profileBlock() {
    final profile = this.profile;
    if (profile == null) return '';
    final lines = <String>[
      '- Name: ${profile.displayName}',
      '- Username: ${profile.username}',
      if (profile.email != null && profile.email!.isNotEmpty)
        '- Email: ${profile.email}',
      '- Degree program: ${profile.degreeProgram}',
      if (profile.semester != null) '- Semester: ${profile.semester}',
      '- Lives in Tübingen: ${profile.livesInTuebingen ? 'yes' : 'no'}',
      if (profile.interests.isNotEmpty)
        '- Interests: ${profile.interests.map((interest) => interest.label).join(', ')}',
      if (profile.foodPreference != FoodPreference.noPreference)
        '- Mensa preference: ${profile.foodPreference.label}',
      if (profile.notificationPreferences.isNotEmpty)
        '- Notification preferences: ${profile.notificationPreferences.map((preference) => preference.label).join(', ')}',
    ];
    return lines.join('\n');
  }
}
