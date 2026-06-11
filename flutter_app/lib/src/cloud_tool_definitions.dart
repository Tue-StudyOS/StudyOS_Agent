List<Map<String, Object?>> cloudToolDefinitions() {
  return <Map<String, Object?>>[
    _tool(
      name: 'append_memory',
      description: 'Append a durable student memory to local device storage.',
      properties: <String, Object?>{
        'text': <String, Object?>{
          'type': 'string',
          'description': 'A concise memory worth keeping for future chats.',
        },
      },
      required: const <String>['text'],
    ),
    _tool(
      name: 'read_memories',
      description: 'Read the local long-term memory document.',
      properties: const <String, Object?>{},
      required: const <String>[],
    ),
    _tool(
      name: 'get_study_context',
      description: 'Read current profile, memory, and local study context.',
      properties: const <String, Object?>{},
      required: const <String>[],
    ),
  ];
}

Map<String, Object?> _tool({
  required String name,
  required String description,
  required Map<String, Object?> properties,
  required List<String> required,
}) {
  return <String, Object?>{
    'type': 'function',
    'function': <String, Object?>{
      'name': name,
      'description': description,
      'parameters': <String, Object?>{
        'type': 'object',
        'properties': properties,
        'required': required,
      },
    },
  };
}
