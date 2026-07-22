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

  /// The full system prompt: the stable instruction plus the current ephemeral
  /// context. The cloud path re-sends the whole prompt every request, so it uses
  /// this. The local path installs [stableSystemPrompt] once as the
  /// conversation's system instruction and carries [ephemeralContext] on the
  /// turn instead (see `LocalNativeLlmProvider`).
  String systemPrompt() {
    final stable = stableSystemPrompt();
    final ephemeral = ephemeralContext();
    if (ephemeral.isEmpty) return stable;
    return '$stable\n\n$ephemeral';
  }

  /// The stable portion of the system prompt: identity, behaviour rules,
  /// student profile, long-term memory, and the cached timetable. This only
  /// changes when the profile/memory/timetable change, so the local model can
  /// keep it as its system instruction across turns without re-encoding it (and
  /// without invalidating the KV cache) every message.
  String stableSystemPrompt() {
    final buffer = StringBuffer()
      ..writeln('You are StudyOS Agent, a tool-grounded study agent.')
      ..writeln('Use Markdown when formatting helps readability.')
      ..writeln(
        'Use StudyOS tools when current data, actions, or durable memory updates are needed; answer directly when provided context is enough.',
      )
      ..writeln(
        'Ground every factual study answer in tool results or provided context.',
      )
      ..writeln(
        'When the user asks you to remember, save, or update a durable preference or fact, call append_memory with a concise memory.',
      )
      ..writeln(
        'If required data is unavailable, say what is missing instead of guessing.',
      )
      ..writeln(
        'These tools display their own results visually in the app: '
        'get_recent_mail, search_mail, get_deadlines, search_talks, '
        'get_schedule, get_academic_status, get_study_planner, '
        'get_mensa_options, search_campus_locations. After '
        'calling one, reply with a single short, natural lead-in sentence (for '
        'example "Here are your recent emails:") and nothing more. Do not list, '
        'tabulate, or restate the returned items, and never mention, describe, '
        'or promise a card, widget, or that something "will appear" — just the '
        'lead-in. If the tool returned no items, say briefly and plainly what '
        'was empty or missing instead.',
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
    return buffer.toString().trim();
  }

  /// The per-turn volatile context: wall-clock time and the device world state.
  /// Deliberately excluded from [stableSystemPrompt] because these change on
  /// every call and would otherwise force the local model to re-encode its whole
  /// system instruction each turn.
  String ephemeralContext() {
    final now = DateTime.now().toLocal();
    final buffer = StringBuffer()
      ..writeln('Current local timestamp: ${now.toIso8601String()}.');
    if (worldState.isNotEmpty) {
      buffer
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
