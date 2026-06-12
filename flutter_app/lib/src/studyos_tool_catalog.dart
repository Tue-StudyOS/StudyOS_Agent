class StudyOsToolSpec {
  const StudyOsToolSpec({
    required this.name,
    required this.description,
    required this.traceSummary,
    required this.properties,
    required this.required,
  });

  final String name;
  final String description;
  final String traceSummary;
  final Map<String, Object?> properties;
  final List<String> required;
}

const appendMemoryTool = StudyOsToolSpec(
  name: 'append_memory',
  description: 'Append a durable student memory to local device storage.',
  traceSummary: 'Writing a durable student memory on this device.',
  properties: <String, Object?>{
    'text': <String, Object?>{
      'type': 'string',
      'description': 'A concise memory worth keeping for future chats.',
    },
  },
  required: <String>['text'],
);

const readMemoriesTool = StudyOsToolSpec(
  name: 'read_memories',
  description: 'Read the local long-term memory document.',
  traceSummary: 'Reading the local memory document.',
  properties: <String, Object?>{},
  required: <String>[],
);

const getStudyContextTool = StudyOsToolSpec(
  name: 'get_study_context',
  description: 'Read current profile, memory, and local study context.',
  traceSummary: 'Reading profile, memory, and device context.',
  properties: <String, Object?>{},
  required: <String>[],
);

const studyOsTools = <StudyOsToolSpec>[
  appendMemoryTool,
  readMemoriesTool,
  getStudyContextTool,
];

StudyOsToolSpec? studyOsToolByName(String name) {
  for (final tool in studyOsTools) {
    if (tool.name == name) return tool;
  }
  return null;
}
