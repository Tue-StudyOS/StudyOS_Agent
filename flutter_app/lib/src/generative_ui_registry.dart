import 'dart:convert';

enum GeneratedComponentKind {
  nextAction('next_action'),
  scheduleSummary('schedule_summary'),
  routeHint('route_hint'),
  deadlineCard('deadline_card'),
  quickReply('quick_reply'),
  mailList('mail_list'),
  deadlineList('deadline_list');

  const GeneratedComponentKind(this.wireName);

  final String wireName;

  static GeneratedComponentKind? fromWireName(String value) {
    for (final kind in GeneratedComponentKind.values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

class GeneratedUiComponent {
  const GeneratedUiComponent({
    required this.kind,
    required this.title,
    required this.body,
    required this.arguments,
  });

  final GeneratedComponentKind kind;
  final String title;
  final String body;
  final Map<String, Object?> arguments;
}

class GeneratedUiValidation {
  const GeneratedUiValidation._({
    this.component,
    this.errors = const <String>[],
  });

  factory GeneratedUiValidation.valid(GeneratedUiComponent component) {
    return GeneratedUiValidation._(component: component);
  }

  factory GeneratedUiValidation.invalid(List<String> errors) {
    return GeneratedUiValidation._(errors: List<String>.unmodifiable(errors));
  }

  final GeneratedUiComponent? component;
  final List<String> errors;

  bool get isValid => component != null;
}

abstract final class GenerativeUiRegistry {
  static GeneratedUiValidation validate(Map<String, Object?> payload) {
    final errors = <String>[];
    final typeValue = _string(payload['type']);
    final kind = typeValue == null
        ? null
        : GeneratedComponentKind.fromWireName(typeValue);
    if (typeValue == null) {
      errors.add('Missing string field: type');
    } else if (kind == null) {
      errors.add('Unsupported component type: $typeValue');
    }

    final title = _string(payload['title']);
    if (title == null) errors.add('Missing string field: title');
    final body = _string(payload['body']);
    if (body == null) errors.add('Missing string field: body');

    final rawArguments = payload['arguments'];
    final arguments = rawArguments is Map
        ? Map<String, Object?>.from(rawArguments)
        : <String, Object?>{};
    if (rawArguments != null && rawArguments is! Map) {
      errors.add('Field arguments must be an object when present');
    }

    if (kind != null) {
      errors.addAll(_validateArguments(kind, arguments));
    }
    if (errors.isNotEmpty || kind == null || title == null || body == null) {
      return GeneratedUiValidation.invalid(errors);
    }
    return GeneratedUiValidation.valid(
      GeneratedUiComponent(
        kind: kind,
        title: title,
        body: body,
        arguments: Map<String, Object?>.unmodifiable(arguments),
      ),
    );
  }

  static List<String> _validateArguments(
    GeneratedComponentKind kind,
    Map<String, Object?> arguments,
  ) {
    return switch (kind) {
      GeneratedComponentKind.nextAction => _requireStrings(arguments, <String>[
        'action_id',
        'cta',
      ]),
      GeneratedComponentKind.scheduleSummary => _requireStrings(
        arguments,
        <String>['source', 'date'],
      ),
      GeneratedComponentKind.routeHint => _requireStrings(arguments, <String>[
        'destination',
        'mode',
      ]),
      GeneratedComponentKind.deadlineCard => _requireStrings(
        arguments,
        <String>['course', 'due'],
      ),
      GeneratedComponentKind.quickReply => _requireStrings(arguments, <String>[
        'reply',
      ]),
      GeneratedComponentKind.mailList => _validateItemList(
        arguments,
        'messages',
      ),
      GeneratedComponentKind.deadlineList => _validateItemList(
        arguments,
        'deadlines',
      ),
    };
  }
}

/// Single entry point the provider tool loops use to turn a completed tool's
/// JSON output into a generative-UI component payload, or `null` when the tool
/// has no card. Each component kind registers its builder here, so adding a
/// component never touches the provider code again — the registry is the one
/// place that maps tools to cards.
Map<String, Object?>? componentPayloadForTool(String toolName, String output) {
  return mailTriageComponentPayload(toolName, output) ??
      deadlineListComponentPayload(toolName, output);
}

/// Builds a `mail_list` GenUI payload from the JSON a mail-summary tool
/// (`get_recent_mail` / `search_mail`) returns, or `null` when [toolName] is not
/// a mail-list producer or [output] cannot be parsed into a non-empty list.
///
/// Kept provider-agnostic (pure, no Flutter imports) so both the local and the
/// cloud tool loops can attach the result to the tool's [ToolTrace]. It only
/// forwards the summary fields the card renders — no message bodies.
Map<String, Object?>? mailTriageComponentPayload(String toolName, String output) {
  const producers = <String>{'get_recent_mail', 'search_mail'};
  if (!producers.contains(toolName)) return null;

  final Object? decoded;
  try {
    decoded = jsonDecode(output);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final rawMessages = decoded['messages'];
  if (rawMessages is! List) return null;

  final messages = <Map<String, Object?>>[];
  for (final raw in rawMessages) {
    if (raw is! Map) continue;
    final uid = _string(raw['uid']);
    final subject = _string(raw['subject']);
    if (uid == null || subject == null) continue;
    messages.add(<String, Object?>{
      'uid': uid,
      'subject': subject,
      'sender':
          _string(raw['from_name']) ??
          _string(raw['from_address']) ??
          'Unknown sender',
      'received_at': _string(raw['received_at']),
      'preview': _string(raw['preview']),
      'is_unread': raw['is_unread'] == true,
      'is_approved_broadcast': raw['is_approved_broadcast'] == true,
    });
  }
  if (messages.isEmpty) return null;

  final mailbox = _string(decoded['mailbox']) ?? 'INBOX';
  final rawUnread = decoded['unread_count'];
  final unread = rawUnread is int
      ? rawUnread
      : messages.where((message) => message['is_unread'] == true).length;
  final count = messages.length;
  return <String, Object?>{
    'type': 'mail_list',
    'title': unread > 0 ? '$mailbox · $unread unread' : mailbox,
    'body': count == 1 ? '1 message' : '$count messages',
    'arguments': <String, Object?>{
      'mailbox': mailbox,
      'unread_count': unread,
      'messages': messages,
    },
  };
}

List<String> _validateItemList(Map<String, Object?> arguments, String listKey) {
  final items = arguments[listKey];
  if (items is! List || items.isEmpty) {
    return <String>['Missing non-empty list argument: $listKey'];
  }
  return const <String>[];
}

/// Builds a `deadline_list` payload from the JSON `get_deadlines` returns (a
/// [CapabilityResult] whose `data` is the deadline list), or `null` for other
/// tools / empty results. Forwards only the fields the card renders.
Map<String, Object?>? deadlineListComponentPayload(
  String toolName,
  String output,
) {
  if (toolName != 'get_deadlines') return null;

  final Object? decoded;
  try {
    decoded = jsonDecode(output);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final rawData = decoded['data'];
  if (rawData is! List) return null;

  final deadlines = <Map<String, Object?>>[];
  for (final raw in rawData) {
    if (raw is! Map) continue;
    final title = _string(raw['title']);
    final dueAt = _string(raw['dueAt']);
    if (title == null || dueAt == null) continue;
    deadlines.add(<String, Object?>{
      'id': _string(raw['id']),
      'title': title,
      'course': _string(raw['courseTitle']),
      'due_at': dueAt,
      'requirement': _string(raw['requirement']),
      'status': _string(raw['status']),
    });
  }
  if (deadlines.isEmpty) return null;

  final count = deadlines.length;
  return <String, Object?>{
    'type': 'deadline_list',
    'title': count == 1 ? 'Upcoming deadline' : '$count upcoming deadlines',
    'body': count == 1 ? '1 deadline' : '$count deadlines',
    'arguments': <String, Object?>{'deadlines': deadlines},
  };
}

const List<Map<String, Object?>>
generativeUiFixturePayloads = <Map<String, Object?>>[
  <String, Object?>{
    'type': 'next_action',
    'title': 'Leave for class',
    'body':
        'Machine Learning starts soon in Room A. Open the schedule before you go.',
    'arguments': <String, Object?>{
      'action_id': 'open_schedule',
      'cta': 'Open schedule',
    },
  },
  <String, Object?>{
    'type': 'schedule_summary',
    'title': 'Compact day',
    'body': 'Two lectures today, with a free study block after lunch.',
    'arguments': <String, Object?>{
      'source': 'local_timetable',
      'date': '2026-07-08',
    },
  },
  <String, Object?>{
    'type': 'route_hint',
    'title': 'Route hint',
    'body': 'Leave in 12 minutes to reach the campus library on time.',
    'arguments': <String, Object?>{
      'destination': 'Campus Library',
      'mode': 'walk',
    },
  },
  <String, Object?>{
    'type': 'deadline_card',
    'title': 'Deadline tomorrow',
    'body': 'Submit the ML exercise sheet before 18:00.',
    'arguments': <String, Object?>{
      'course': 'Machine Learning',
      'due': '2026-07-09T18:00:00',
    },
  },
  <String, Object?>{
    'type': 'quick_reply',
    'title': 'Quick reply',
    'body': 'Ask StudyOS to plan a 45 minute review block.',
    'arguments': <String, Object?>{
      'reply': 'Plan a 45 minute review block around my next lecture.',
    },
  },
  <String, Object?>{
    'type': 'mail_list',
    'title': 'INBOX · 2 unread',
    'body': '3 messages',
    'arguments': <String, Object?>{
      'mailbox': 'INBOX',
      'unread_count': 2,
      'messages': <Map<String, Object?>>[
        <String, Object?>{
          'uid': '4821',
          'subject': 'ML exercise sheet 7 — submission Friday',
          'sender': 'Prof. Dr. Weber',
          'received_at': '2026-07-08T09:12:00',
          'preview': 'Please upload your solutions to Ilias before 18:00 on…',
          'is_unread': true,
          'is_approved_broadcast': true,
        },
        <String, Object?>{
          'uid': '4820',
          'subject': 'Room change for Thursday tutorial',
          'sender': 'Studierendensekretariat',
          'received_at': '2026-07-07T16:40:00',
          'preview': 'The tutorial moves to room A301 starting this week.',
          'is_unread': true,
          'is_approved_broadcast': false,
        },
        <String, Object?>{
          'uid': '4818',
          'subject': 'Re: Study group notes',
          'sender': 'Lena',
          'received_at': '2026-07-07T11:05:00',
          'preview': 'Thanks! I added the missing derivations to the shared…',
          'is_unread': false,
          'is_approved_broadcast': false,
        },
      ],
    },
  },
  <String, Object?>{
    'type': 'deadline_list',
    'title': '2 upcoming deadlines',
    'body': '2 deadlines',
    'arguments': <String, Object?>{
      'deadlines': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'ilias:9921',
          'title': 'ML exercise sheet 7',
          'course': 'Machine Learning',
          'due_at': '2026-12-11T18:00:00.000Z',
          'requirement': 'Graded submission',
          'status': 'open',
        },
        <String, Object?>{
          'id': 'moodle:5540',
          'title': 'Databases project milestone',
          'course': 'Databases',
          'due_at': '2026-12-15T23:59:00.000Z',
          'requirement': null,
          'status': 'open',
        },
      ],
    },
  },
];

/// An interaction requested by a generative-UI component. Cards emit these
/// through a single callback so the widget layer stays uniform as new component
/// kinds are added; the app shell dispatches on the concrete type.
sealed class GeneratedComponentAction {
  const GeneratedComponentAction();
}

/// Submit [prompt] into the chat composer and send it (e.g. mail Summarize).
class PromptComponentAction extends GeneratedComponentAction {
  const PromptComponentAction(this.prompt);

  final String prompt;
}

/// Create a native device reminder for a deadline. Side-effecting, but always
/// user-initiated (a tap), so the tap itself is the authorization.
class ReminderComponentAction extends GeneratedComponentAction {
  const ReminderComponentAction({required this.title, required this.dueAt});

  final String title;
  final DateTime dueAt;
}

List<String> _requireStrings(
  Map<String, Object?> arguments,
  List<String> keys,
) {
  final errors = <String>[];
  for (final key in keys) {
    if (_string(arguments[key]) == null) {
      errors.add('Missing string argument: $key');
    }
  }
  return errors;
}

String? _string(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
