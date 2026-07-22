import 'dart:convert';

/// Bounds on a `custom_view` node tree, enforced during validation so a
/// malformed or oversized payload from a small model can't blow up layout or
/// recursion. The renderer stays tolerant of individual bad leaf nodes (it
/// skips them); these caps only guard the overall shape.
const int customViewMaxNodes = 48;
const int customViewMaxDepth = 4;
const int customViewMaxChildrenPerContainer = 24;

/// The one recursive container node in the `custom_view` vocabulary. Its
/// children live under the same `blocks` key the root uses.
const String customViewContainerNode = 'group';

enum GeneratedComponentKind {
  nextAction('next_action'),
  scheduleSummary('schedule_summary'),
  routeHint('route_hint'),
  deadlineCard('deadline_card'),
  quickReply('quick_reply'),
  mailList('mail_list'),
  deadlineList('deadline_list'),
  talkList('talk_list'),
  academicStatus('academic_status'),
  studyProgress('study_progress'),
  mensaMenu('mensa_menu'),
  campusLocations('campus_locations'),
  scheduleAgenda('schedule_agenda'),
  customView('custom_view');

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
      GeneratedComponentKind.talkList => _validateItemList(arguments, 'talks'),
      GeneratedComponentKind.academicStatus => _validateItemList(
        arguments,
        'entries',
      ),
      GeneratedComponentKind.studyProgress => _validateItemList(
        arguments,
        'modules',
      ),
      GeneratedComponentKind.mensaMenu => _validateItemList(
        arguments,
        'options',
      ),
      GeneratedComponentKind.campusLocations => _validateItemList(
        arguments,
        'locations',
      ),
      GeneratedComponentKind.scheduleAgenda => _validateItemList(
        arguments,
        'events',
      ),
      GeneratedComponentKind.customView => _validateCustomView(arguments),
    };
  }

  /// Validates only the *structure* of a `custom_view` tree: a non-empty
  /// `blocks` list within the node-count, depth, and per-container caps. Leaf
  /// nodes are intentionally not field-checked here — the renderer skips any it
  /// can't draw — so a mostly-good tree from a weak model still renders instead
  /// of collapsing to plain text.
  static List<String> _validateCustomView(Map<String, Object?> arguments) {
    final blocks = arguments['blocks'];
    if (blocks is! List || blocks.isEmpty) {
      return <String>['Missing non-empty list argument: blocks'];
    }
    final errors = <String>[];
    var nodeCount = 0;

    void walk(List<Object?> nodes, int depth) {
      if (errors.isNotEmpty) return;
      if (depth > customViewMaxDepth) {
        errors.add('Custom view nesting exceeds depth $customViewMaxDepth');
        return;
      }
      if (nodes.length > customViewMaxChildrenPerContainer) {
        errors.add(
          'Custom view container exceeds '
          '$customViewMaxChildrenPerContainer children',
        );
        return;
      }
      for (final node in nodes) {
        nodeCount++;
        if (nodeCount > customViewMaxNodes) {
          errors.add('Custom view exceeds $customViewMaxNodes nodes');
          return;
        }
        if (node is Map && node['node'] == customViewContainerNode) {
          final children = node['blocks'];
          if (children is List) walk(children, depth + 1);
          if (errors.isNotEmpty) return;
        }
      }
    }

    walk(blocks, 1);
    return errors;
  }
}

/// Single entry point the provider tool loops use to turn a completed tool's
/// JSON output into a generative-UI component payload, or `null` when the tool
/// has no card. Each component kind registers its builder here, so adding a
/// component never touches the provider code again — the registry is the one
/// place that maps tools to cards.
Map<String, Object?>? componentPayloadForTool(String toolName, String output) {
  return mailTriageComponentPayload(toolName, output) ??
      deadlineListComponentPayload(toolName, output) ??
      talkListComponentPayload(toolName, output) ??
      academicStatusComponentPayload(toolName, output) ??
      studyProgressComponentPayload(toolName, output) ??
      mensaMenuComponentPayload(toolName, output) ??
      campusLocationsComponentPayload(toolName, output) ??
      scheduleAgendaComponentPayload(toolName, output);
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

/// Builds a `talk_list` payload from `search_talks` output (a `{items: [...]}`
/// envelope of Tübingen talks), or `null` otherwise. Forwards only the fields
/// the card renders plus the ISO timestamp its "Remind me" action needs.
Map<String, Object?>? talkListComponentPayload(String toolName, String output) {
  if (toolName != 'search_talks') return null;

  final Object? decoded;
  try {
    decoded = jsonDecode(output);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final rawItems = decoded['items'];
  if (rawItems is! List) return null;

  final talks = <Map<String, Object?>>[];
  for (final raw in rawItems) {
    if (raw is! Map) continue;
    final title = _string(raw['title']);
    if (title == null) continue;
    talks.add(<String, Object?>{
      'title': title,
      'timestamp': _string(raw['timestamp']),
      'speaker': _string(raw['speaker_name']),
      'location': _string(raw['location']),
    });
  }
  if (talks.isEmpty) return null;

  final count = talks.length;
  return <String, Object?>{
    'type': 'talk_list',
    'title': count == 1 ? 'Upcoming talk' : '$count upcoming talks',
    'body': count == 1 ? '1 talk' : '$count talks',
    'arguments': <String, Object?>{'talks': talks},
  };
}

/// Builds an `academic_status` payload from `get_academic_status` output (a
/// `{term, entries: [...]}` snapshot of exam/course statuses), or `null`
/// otherwise. Read-only card — no per-item actions.
Map<String, Object?>? academicStatusComponentPayload(
  String toolName,
  String output,
) {
  if (toolName != 'get_academic_status') return null;

  final Object? decoded;
  try {
    decoded = jsonDecode(output);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final rawEntries = decoded['entries'];
  if (rawEntries is! List) return null;

  final entries = <Map<String, Object?>>[];
  for (final raw in rawEntries) {
    if (raw is! Map) continue;
    final title = _string(raw['title']);
    if (title == null) continue;
    entries.add(<String, Object?>{
      'category': _string(raw['category']) ?? 'Other',
      'title': title,
      'status': _string(raw['status']),
      'semester': _string(raw['semester']),
    });
  }
  if (entries.isEmpty) return null;

  final term = _string(decoded['term']);
  final count = entries.length;
  return <String, Object?>{
    'type': 'academic_status',
    'title': term == null ? 'Academic status' : 'Academic status · $term',
    'body': count == 1 ? '1 entry' : '$count entries',
    'arguments': <String, Object?>{
      'term': ?term,
      'entries': entries,
    },
  };
}

/// Builds a `study_progress` payload from `get_study_planner` output (a
/// [CapabilityResult] whose `data` is an ALMA planner page with modules that
/// carry earned/required ECTS), or `null` otherwise. Also computes the overall
/// earned-vs-required total across modules that report both.
Map<String, Object?>? studyProgressComponentPayload(
  String toolName,
  String output,
) {
  if (toolName != 'get_study_planner') return null;

  final Object? decoded;
  try {
    decoded = jsonDecode(output);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final data = decoded['data'];
  if (data is! Map) return null;
  final rawModules = data['modules'];
  if (rawModules is! List) return null;

  final modules = <Map<String, Object?>>[];
  var totalEarned = 0.0;
  var totalRequired = 0.0;
  for (final raw in rawModules) {
    if (raw is! Map) continue;
    final title = _string(raw['title']);
    if (title == null) continue;
    final earned = _double(raw['creditsEarned']);
    final required = _double(raw['creditsRequired']);
    if (earned != null && required != null && required > 0) {
      totalEarned += earned;
      totalRequired += required;
    }
    modules.add(<String, Object?>{
      'title': title,
      'number': _string(raw['number']),
      'earned': earned,
      'required': required,
      'summary': _string(raw['creditsSummary']),
    });
  }
  if (modules.isEmpty) return null;

  final pageTitle = _string(data['title']) ?? 'Study progress';
  final body = totalRequired > 0
      ? '${_trimNumber(totalEarned)} / ${_trimNumber(totalRequired)} ECTS'
      : '${modules.length} modules';
  return <String, Object?>{
    'type': 'study_progress',
    'title': pageTitle,
    'body': body,
    'arguments': <String, Object?>{
      'total_earned': totalRequired > 0 ? totalEarned : null,
      'total_required': totalRequired > 0 ? totalRequired : null,
      'modules': modules,
    },
  };
}

/// Builds a `mensa_menu` payload from `get_mensa_options` output (a
/// [CapabilityResult] whose `data` is a list of canteen menu lines), or `null`
/// otherwise. Read-only card.
Map<String, Object?>? mensaMenuComponentPayload(
  String toolName,
  String output,
) {
  if (toolName != 'get_mensa_options') return null;

  final Object? decoded;
  try {
    decoded = jsonDecode(output);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final rawData = decoded['data'];
  if (rawData is! List) return null;

  final options = <Map<String, Object?>>[];
  for (final raw in rawData) {
    if (raw is! Map) continue;
    final line = _string(raw['line']);
    final items = _stringList(raw['items']);
    if (line == null && items.isEmpty) continue;
    options.add(<String, Object?>{
      'canteen': _string(raw['canteen']),
      'line': line ?? 'Menu',
      'items': items,
      'markers': _stringList(raw['dietary_markers']),
      'price': _string(raw['student_price']),
    });
  }
  if (options.isEmpty) return null;

  final canteens = options
      .map((option) => _string(option['canteen']))
      .whereType<String>()
      .toSet();
  final count = options.length;
  return <String, Object?>{
    'type': 'mensa_menu',
    'title': canteens.length == 1 ? canteens.first : 'Mensa menu',
    'body': count == 1 ? '1 option' : '$count options',
    'arguments': <String, Object?>{'options': options},
  };
}

/// Builds a `campus_locations` payload from `search_campus_locations` output (a
/// [CapabilityResult] whose `data` is a list of geocoded places), or `null`
/// otherwise. Each location keeps its coordinates so the card's "Open in Maps"
/// action can launch them.
Map<String, Object?>? campusLocationsComponentPayload(
  String toolName,
  String output,
) {
  if (toolName != 'search_campus_locations') return null;

  final Object? decoded;
  try {
    decoded = jsonDecode(output);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final rawData = decoded['data'];
  if (rawData is! List) return null;

  final locations = <Map<String, Object?>>[];
  for (final raw in rawData) {
    if (raw is! Map) continue;
    final name = _string(raw['name']);
    final latitude = _double(raw['latitude']);
    final longitude = _double(raw['longitude']);
    if (name == null || latitude == null || longitude == null) continue;
    locations.add(<String, Object?>{
      'name': name,
      'address': _string(raw['address']),
      'category': _string(raw['category']),
      'latitude': latitude,
      'longitude': longitude,
    });
  }
  if (locations.isEmpty) return null;

  final count = locations.length;
  return <String, Object?>{
    'type': 'campus_locations',
    'title': count == 1 ? locations.first['name'] : '$count places',
    'body': count == 1 ? '1 place' : '$count places',
    'arguments': <String, Object?>{'locations': locations},
  };
}

/// Builds a `schedule_agenda` payload from `get_schedule` output (a
/// `{source_term, events: [...]}` snapshot of upcoming lectures), or `null`
/// otherwise. Read-only card; the widget groups events by day.
Map<String, Object?>? scheduleAgendaComponentPayload(
  String toolName,
  String output,
) {
  if (toolName != 'get_schedule') return null;

  final Object? decoded;
  try {
    decoded = jsonDecode(output);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final rawEvents = decoded['events'];
  if (rawEvents is! List) return null;

  final events = <Map<String, Object?>>[];
  for (final raw in rawEvents) {
    if (raw is! Map) continue;
    final title = _string(raw['title']);
    final start = _string(raw['start']);
    if (title == null || start == null) continue;
    events.add(<String, Object?>{
      'title': title,
      'start': start,
      'end': _string(raw['end']),
      'location': _string(raw['location']),
    });
  }
  if (events.isEmpty) return null;

  final term = _string(decoded['source_term']);
  final count = events.length;
  return <String, Object?>{
    'type': 'schedule_agenda',
    'title': term == null ? 'Upcoming schedule' : 'Schedule · $term',
    'body': count == 1 ? '1 lecture' : '$count lectures',
    'arguments': <String, Object?>{'events': events},
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
  <String, Object?>{
    'type': 'talk_list',
    'title': '2 upcoming talks',
    'body': '2 talks',
    'arguments': <String, Object?>{
      'talks': <Map<String, Object?>>[
        <String, Object?>{
          'title': 'Foundation models for scientific discovery',
          'timestamp': '2026-12-09T16:15:00.000Z',
          'speaker': 'Dr. Amelie Roth',
          'location': 'Hörsaal 21, Kupferbau',
        },
        <String, Object?>{
          'title': 'Reinforcement learning in robotics',
          'timestamp': '2026-12-11T14:00:00.000Z',
          'speaker': 'Prof. Chen',
          'location': 'MPI-IS, Lecture Hall N0.002',
        },
      ],
    },
  },
  <String, Object?>{
    'type': 'academic_status',
    'title': 'Academic status · WS 2026/27',
    'body': '3 entries',
    'arguments': <String, Object?>{
      'term': 'WS 2026/27',
      'entries': <Map<String, Object?>>[
        <String, Object?>{
          'category': 'Exams',
          'title': 'Machine Learning — written exam',
          'status': 'Registered',
          'semester': 'WS 2026/27',
        },
        <String, Object?>{
          'category': 'Exams',
          'title': 'Databases — oral exam',
          'status': 'Passed (1.7)',
          'semester': 'WS 2026/27',
        },
        <String, Object?>{
          'category': 'Courses',
          'title': 'Statistics III',
          'status': 'Enrolled',
          'semester': 'WS 2026/27',
        },
      ],
    },
  },
  <String, Object?>{
    'type': 'study_progress',
    'title': 'M.Sc. Machine Learning',
    'body': '78 / 120 ECTS',
    'arguments': <String, Object?>{
      'total_earned': 78,
      'total_required': 120,
      'modules': <Map<String, Object?>>[
        <String, Object?>{
          'title': 'Core Machine Learning',
          'number': 'ML-4100',
          'earned': 27,
          'required': 30,
          'summary': '27 / 30 ECTS',
        },
        <String, Object?>{
          'title': 'Theoretical Foundations',
          'number': 'ML-4200',
          'earned': 18,
          'required': 30,
          'summary': '18 / 30 ECTS',
        },
        <String, Object?>{
          'title': "Master's Thesis",
          'number': 'ML-4900',
          'earned': 0,
          'required': 30,
          'summary': '0 / 30 ECTS',
        },
      ],
    },
  },
  <String, Object?>{
    'type': 'mensa_menu',
    'title': 'Mensa Wilhelmstraße',
    'body': '2 options',
    'arguments': <String, Object?>{
      'options': <Map<String, Object?>>[
        <String, Object?>{
          'canteen': 'Mensa Wilhelmstraße',
          'line': 'Line 1',
          'items': <String>['Gemüse-Lasagne', 'Blattsalat'],
          'markers': <String>['Vegetarisch'],
          'price': '3,20 €',
        },
        <String, Object?>{
          'canteen': 'Mensa Wilhelmstraße',
          'line': 'Line 2',
          'items': <String>['Rindergulasch', 'Semmelknödel'],
          'markers': <String>[],
          'price': '4,10 €',
        },
      ],
    },
  },
  <String, Object?>{
    'type': 'campus_locations',
    'title': '2 places',
    'body': '2 places',
    'arguments': <String, Object?>{
      'locations': <Map<String, Object?>>[
        <String, Object?>{
          'name': 'Universitätsbibliothek Tübingen',
          'address': 'Wilhelmstraße 32, 72074 Tübingen',
          'category': 'library',
          'latitude': 48.5296,
          'longitude': 9.0596,
        },
        <String, Object?>{
          'name': 'Mensa Wilhelmstraße',
          'address': 'Wilhelmstraße 13, 72074 Tübingen',
          'category': 'canteen',
          'latitude': 48.5309,
          'longitude': 9.0625,
        },
      ],
    },
  },
  <String, Object?>{
    'type': 'schedule_agenda',
    'title': 'Schedule · WS 2026/27',
    'body': '3 lectures',
    'arguments': <String, Object?>{
      'events': <Map<String, Object?>>[
        <String, Object?>{
          'title': 'Machine Learning',
          'start': '2026-12-09T10:15:00',
          'end': '2026-12-09T11:45:00',
          'location': 'Hörsaal 21',
        },
        <String, Object?>{
          'title': 'Databases Tutorial',
          'start': '2026-12-09T14:00:00',
          'end': '2026-12-09T15:30:00',
          'location': 'A301',
        },
        <String, Object?>{
          'title': 'Statistics III',
          'start': '2026-12-10T08:15:00',
          'end': '2026-12-10T09:45:00',
          'location': null,
        },
      ],
    },
  },
  <String, Object?>{
    'type': 'custom_view',
    'title': 'Supervised vs. unsupervised',
    'body': 'A quick comparison for your exam prep.',
    'arguments': <String, Object?>{
      'blocks': <Map<String, Object?>>[
        <String, Object?>{
          'node': 'badges',
          'items': <Map<String, Object?>>[
            <String, Object?>{'text': 'Exam topic', 'tone': 'positive'},
            <String, Object?>{'text': 'ML core', 'tone': 'neutral'},
          ],
        },
        <String, Object?>{
          'node': 'table',
          'columns': <String>['Aspect', 'Supervised', 'Unsupervised'],
          'rows': <List<String>>[
            <String>['Labels', 'Required', 'None'],
            <String>['Goal', 'Predict targets', 'Find structure'],
            <String>['Example', 'Classification', 'Clustering'],
          ],
        },
        <String, Object?>{
          'node': 'stats',
          'items': <Map<String, Object?>>[
            <String, Object?>{'value': '2', 'label': 'Lectures left'},
            <String, Object?>{'value': '5 days', 'label': 'Until exam'},
          ],
        },
        <String, Object?>{
          'node': 'group',
          'blocks': <Map<String, Object?>>[
            <String, Object?>{'node': 'heading', 'text': 'Revise next'},
            <String, Object?>{
              'node': 'bullets',
              'items': <String>[
                'k-means and its assumptions',
                'Bias–variance trade-off',
              ],
            },
          ],
        },
        <String, Object?>{'node': 'divider'},
        <String, Object?>{
          'node': 'button',
          'label': 'Plan a review block',
          'action': <String, Object?>{
            'type': 'prompt',
            'prompt': 'Plan a 45 minute review block on unsupervised learning.',
          },
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

/// Open a geocoded place in the device's maps app (external launch). Benign and
/// user-initiated, so the tap is the authorization.
class MapComponentAction extends GeneratedComponentAction {
  const MapComponentAction({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
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

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

/// Formats an ECTS number without a trailing `.0` (e.g. `30` not `30.0`, but
/// `7.5` stays `7.5`).
String _trimNumber(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
