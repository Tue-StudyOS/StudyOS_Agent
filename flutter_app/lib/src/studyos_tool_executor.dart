import 'dart:convert';

import 'mail_tools.dart';
import 'memory_store.dart';
import 'native_tool_router.dart';
import 'prompt_context.dart';

class StudyOsToolContext {
  const StudyOsToolContext({
    required this.promptContext,
    required this.appendMemory,
    required this.readMemory,
    required this.readSchedule,
    required this.mailTools,
    required this.nativeTools,
  });

  final PromptContext promptContext;
  final Future<void> Function(String text) appendMemory;
  final Future<String> Function() readMemory;
  final Future<String> Function() readSchedule;
  final MailToolRunner mailTools;
  final NativeToolRunner? nativeTools;
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
}

StudyOsToolContext studyOsToolContext({
  required PromptContext promptContext,
  required Future<void> Function(String text) appendMemory,
  required MemoryStore memoryStore,
  required Future<String> Function() readSchedule,
  required MailToolRunner mailTools,
  NativeToolRunner? nativeTools,
}) {
  return StudyOsToolContext(
    promptContext: promptContext,
    appendMemory: appendMemory,
    readMemory: memoryStore.read,
    readSchedule: readSchedule,
    mailTools: mailTools,
    nativeTools: nativeTools,
  );
}
