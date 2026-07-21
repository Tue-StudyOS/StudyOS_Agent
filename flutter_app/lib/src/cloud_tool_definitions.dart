import 'studyos_tool_catalog.dart';

List<Map<String, Object?>> cloudToolDefinitions({
  Set<String> supportedNativeToolNames = const <String>{},
}) {
  return cloudStudyOsTools(supportedNativeToolNames).map(_tool).toList();
}

Map<String, Object?> _tool(StudyOsToolSpec spec) {
  return <String, Object?>{
    'type': 'function',
    'function': <String, Object?>{
      'name': spec.name,
      'description': spec.description,
      'parameters': <String, Object?>{
        'type': 'object',
        'properties': spec.properties,
        'required': spec.required,
      },
    },
  };
}
