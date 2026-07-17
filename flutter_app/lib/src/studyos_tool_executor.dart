import 'dart:convert';

import 'mail_tools.dart';
import 'memory_store.dart';
import 'native_tool_router.dart';
import 'prompt_context.dart';
import 'private_study_tools.dart';
import 'public_study_tools.dart';

Future<String> _unavailableAcademicStatus() async =>
    'Academic status is not available.';
Future<String> _unavailableTalks(String query, int limit) async =>
    'Tübingen Talks are not available.';

class StudyOsToolContext {
  const StudyOsToolContext({
    required this.promptContext,
    required this.appendMemory,
    required this.readMemory,
    required this.readSchedule,
    this.readAcademicStatus = _unavailableAcademicStatus,
    this.searchTalks = _unavailableTalks,
    required this.mailTools,
    required this.nativeTools,
    this.publicStudyTools,
    this.privateStudyTools,
  });

  final PromptContext promptContext;
  final Future<void> Function(String text) appendMemory;
  final Future<String> Function() readMemory;
  final Future<String> Function() readSchedule;
  final Future<String> Function() readAcademicStatus;
  final Future<String> Function(String query, int limit) searchTalks;
  final MailToolRunner mailTools;
  final NativeToolRunner? nativeTools;
  final PublicStudyToolRunner? publicStudyTools;
  final PrivateStudyToolRunner? privateStudyTools;
}

class StudyOsToolExecutor {
  const StudyOsToolExecutor();

  Future<String> execute(
    String toolName,
    String arguments,
    StudyOsToolContext context,
  ) async {
    return switch (toolName) {
      'append_memory' => _appendMemory(arguments, context.appendMemory),
      'read_memories' => context.readMemory(),
      'get_study_context' => context.promptContext.systemPrompt(),
      'get_schedule' => context.readSchedule(),
      'get_academic_status' => context.readAcademicStatus(),
      'search_talks' => _searchTalks(arguments, context.searchTalks),
      getMensaOptionsToolName || searchCampusLocationsToolName =>
        _executePublicStudyTool(toolName, arguments, context.publicStudyTools),
      getTasksToolName || getDeadlinesToolName => _executePrivateStudyTool(
        toolName,
        arguments,
        context.privateStudyTools,
      ),
      'list_mailboxes' ||
      'get_recent_mail' ||
      'search_mail' ||
      'get_mail_message' ||
      'find_mail_deadlines' => context.mailTools.execute(toolName, arguments),
      _ when activeNativeToolNames.contains(toolName) => _executeNativeTool(
        toolName,
        arguments,
        context.nativeTools,
      ),
      _ => 'Tool is not available: $toolName',
    };
  }

  Future<String> _executePrivateStudyTool(
    String toolName,
    String arguments,
    PrivateStudyToolRunner? privateStudyTools,
  ) {
    if (privateStudyTools == null) {
      return Future<String>.value(
        'Private study tool is not available in this app runtime: $toolName',
      );
    }
    return privateStudyTools.execute(toolName, arguments);
  }

  Future<String> _executePublicStudyTool(
    String toolName,
    String arguments,
    PublicStudyToolRunner? publicStudyTools,
  ) {
    if (publicStudyTools == null) {
      return Future<String>.value(
        'Public study tool is not available in this runtime: $toolName',
      );
    }
    return publicStudyTools.execute(toolName, arguments);
  }

  Future<String> _executeNativeTool(
    String toolName,
    String arguments,
    NativeToolRunner? nativeTools,
  ) {
    if (nativeTools == null) {
      return Future<String>.value(
        'Native tool is not available in this runtime: $toolName',
      );
    }
    return nativeTools.execute(toolName, arguments);
  }

  Future<String> _appendMemory(
    String arguments,
    Future<void> Function(String text) appendMemory,
  ) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(arguments);
    } on FormatException {
      return 'Memory arguments were not valid JSON.';
    }
    if (decoded is! Map) return 'Memory text was not provided.';
    final text = Map<String, Object?>.from(decoded)['text']?.toString();
    if (text == null || text.trim().isEmpty) {
      return 'Memory text was not provided.';
    }
    await appendMemory(text);
    return 'Memory saved.';
  }

  Future<String> _searchTalks(
    String arguments,
    Future<String> Function(String query, int limit) searchTalks,
  ) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(arguments);
    } on FormatException {
      return 'Talk search arguments were not valid JSON.';
    }
    if (decoded is! Map) {
      return 'Talk search arguments must be a JSON object.';
    }
    final values = Map<String, Object?>.from(decoded);
    final query = values['query']?.toString().trim() ?? '';
    final requestedLimit = values['limit'];
    final limit = requestedLimit is num
        ? requestedLimit.toInt().clamp(1, 20).toInt()
        : 8;
    return searchTalks(query, limit);
  }
}

StudyOsToolContext studyOsToolContext({
  required PromptContext promptContext,
  required Future<void> Function(String text) appendMemory,
  required MemoryStore memoryStore,
  required Future<String> Function() readSchedule,
  Future<String> Function() readAcademicStatus = _unavailableAcademicStatus,
  Future<String> Function(String query, int limit) searchTalks =
      _unavailableTalks,
  required MailToolRunner mailTools,
  NativeToolRunner? nativeTools,
  PublicStudyToolRunner? publicStudyTools,
  PrivateStudyToolRunner? privateStudyTools,
}) {
  return StudyOsToolContext(
    promptContext: promptContext,
    appendMemory: appendMemory,
    readMemory: memoryStore.read,
    readSchedule: readSchedule,
    readAcademicStatus: readAcademicStatus,
    searchTalks: searchTalks,
    mailTools: mailTools,
    nativeTools: nativeTools,
    publicStudyTools: publicStudyTools,
    privateStudyTools: privateStudyTools,
  );
}
