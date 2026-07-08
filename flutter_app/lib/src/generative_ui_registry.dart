enum GeneratedComponentKind {
  nextAction('next_action'),
  scheduleSummary('schedule_summary'),
  routeHint('route_hint'),
  deadlineCard('deadline_card'),
  quickReply('quick_reply');

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
  const GeneratedUiValidation._({this.component, this.errors = const <String>[]});

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
      GeneratedComponentKind.deadlineCard => _requireStrings(arguments, <String>[
        'course',
        'due',
      ]),
      GeneratedComponentKind.quickReply => _requireStrings(arguments, <String>[
        'reply',
      ]),
    };
  }
}

const List<Map<String, Object?>> generativeUiFixturePayloads =
    <Map<String, Object?>>[
      <String, Object?>{
        'type': 'next_action',
        'title': 'Leave for class',
        'body': 'Machine Learning starts soon in Room A. Open the schedule before you go.',
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
    ];

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

