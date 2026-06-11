import 'models.dart';

class PromptContext {
  const PromptContext({
    required this.profile,
    required this.memory,
    required this.worldState,
  });

  final OnboardingProfile? profile;
  final String memory;
  final Map<String, Object?> worldState;

  String systemPrompt() {
    final buffer = StringBuffer()
      ..writeln('You are StudyOS Agent, a concise study companion.')
      ..writeln('Use Markdown when formatting helps readability.')
      ..writeln('Use available tools before guessing stored student context.')
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
    ];
    return lines.join('\n');
  }
}
