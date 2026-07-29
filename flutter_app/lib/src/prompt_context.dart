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
        'These tools can display their result visually in the app: '
        'get_recent_mail, search_mail, get_deadlines, search_talks, '
        'get_schedule, get_academic_status, get_study_planner, '
        'get_mensa_options, search_campus_locations. When your answer is '
        'presenting one of these results, reply with ONLY a single short, '
        'natural lead-in sentence (for example "Here are your recent emails:") '
        'and nothing else — the app then shows the result as a card, so do not '
        'list, tabulate, or restate the returned items, and never describe or '
        'promise the card. If you called such a tool but your answer is about '
        'something else (you were checking, or the question turned out to be '
        'about another topic), write your normal full answer with no lead-in — '
        'no card appears. If the tool returned no items, say briefly and plainly '
        'what was empty or missing. When you fetched from several of these tools '
        'in one turn and need a specific one shown, you may end the message with '
        'a reference naming it:\n'
        '```ui\n'
        '{"type":"tool_card","tool":"get_recent_mail"}\n'
        '```',
      )
      ..writeln('Do not expose secrets or credentials.')
      ..writeln(
        'When a reply that used none of those tools would be helped by a small '
        'interactive card, you MAY end the message with exactly one fenced '
        '```ui block holding a single JSON object. Use it sparingly and only '
        'when it clearly helps; most replies need no card. Put the block last, '
        'write nothing after it, and do not mention or describe the card in '
        'your prose. Every block needs "type", "title", "body", and '
        '"arguments". Supported cards:\n'
        '- quick_reply: suggest one tappable follow-up. '
        'arguments: {"reply": "<message sent when tapped>"}.\n'
        '- next_action: offer one next step as a button. '
        'arguments: {"action_id": "<slug>", "cta": "<label, also sent when '
        'tapped>"}.\n'
        '- deadline_card: highlight one deadline. '
        'arguments: {"course": "<course>", "due": "<ISO-8601 datetime>"}.\n'
        'Example:\n'
        '```ui\n'
        '{"type":"quick_reply","title":"Suggestion","body":"Want a study '
        'plan?","arguments":{"reply":"Plan a 45 minute review block before my '
        'next lecture."}}\n'
        '```',
      )
      ..writeln(
        'When a reply needs a richer layout than those (a comparison, '
        'checklist, steps, or key figures), you MAY instead emit a custom_view '
        'card. Its "arguments" is {"blocks": [ ... ]}, an ordered list of '
        'nodes; each node is an object with a "node" field. Node types: '
        'heading {text}; paragraph {text}; bullets {items:[string]}; '
        'key_values {rows:[{label,value}]}; table {columns:[string], '
        'rows:[[string]]}; stats {items:[{value,label}]}; badges '
        '{items:[{text,tone}]} with tone neutral|positive|warning; divider {}; '
        'group {blocks:[...]} to nest one level; button {label, action}. A '
        'button "action" is one of {"type":"prompt","prompt":"..."}, '
        '{"type":"reminder","title":"...","due":"<ISO-8601>"}, or '
        '{"type":"map","name":"...","latitude":<n>,"longitude":<n>}. Keep it '
        'small: a few blocks and shallow nesting. Same rules — put the block '
        'last, write nothing after it, keep your prose to a short lead-in. '
        'Example:\n'
        '```ui\n'
        '{"type":"custom_view","title":"Two options","body":"Quick '
        'compare.","arguments":{"blocks":[{"node":"table","columns":["Aspect",'
        '"A","B"],"rows":[["Cost","Low","High"]]},{"node":"button","label":'
        '"Explain more","action":{"type":"prompt","prompt":"Explain option A in '
        'detail."}}]}}\n'
        '```',
      );
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
