import 'agent_config_store.dart';
import 'chat_session_mutation.dart';
import 'cloud_agent_client.dart';
import 'mail_tools.dart';
import 'memory_store.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'prompt_context.dart';
import 'studyos_tool_catalog.dart';
import 'studyos_tool_executor.dart';

class AgentLlmRequest {
  const AgentLlmRequest({
    required this.config,
    required this.sessions,
    required this.activeSessionId,
    required this.userText,
    required this.context,
    required this.memoryText,
    required this.appendMemory,
    required this.readSchedule,
    required this.mailTools,
    required this.onToolTrace,
  });

  final AgentConfig config;
  final List<ChatSession> sessions;
  final String? activeSessionId;
  final String userText;
  final PromptContext context;
  final String memoryText;
  final Future<void> Function(String text) appendMemory;
  final Future<String> Function() readSchedule;
  final MailToolRunner mailTools;
  final void Function(ToolTrace trace) onToolTrace;
}

abstract class AgentLlmProvider {
  AgentProvider get provider;
  String get id;
  String get displayName;

  Future<String> send(AgentLlmRequest request);
}

class AgentLlmProviderRegistry {
  AgentLlmProviderRegistry(Iterable<AgentLlmProvider> providers) {
    for (final provider in providers) {
      register(provider);
    }
  }

  factory AgentLlmProviderRegistry.defaults({
    required NativeBridge bridge,
    required AgentConfigStore configStore,
    required MemoryStore memoryStore,
    required Future<void> Function(String text) appendMemory,
    required CloudAgentClient cloudClient,
  }) {
    return AgentLlmProviderRegistry(<AgentLlmProvider>[
      LocalNativeLlmProvider(bridge),
      CloudLlmProvider(configStore, memoryStore, appendMemory, cloudClient),
    ]);
  }

  final Map<AgentProvider, AgentLlmProvider> _providers =
      <AgentProvider, AgentLlmProvider>{};

  void register(AgentLlmProvider provider) {
    _providers[provider.provider] = provider;
  }

  AgentLlmProvider resolve(AgentProvider provider) {
    final resolved = _providers[provider];
    if (resolved == null) {
      throw StateError('No LLM provider registered for ${provider.name}.');
    }
    return resolved;
  }
}

class LocalNativeLlmProvider implements AgentLlmProvider {
  const LocalNativeLlmProvider(
    this._bridge, [
    this._toolExecutor = const StudyOsToolExecutor(),
  ]);

  static final RegExp _toolCallPattern = RegExp(
    r'\[TOOL:([^\]:]+):?([^\]]*)\]',
  );
  static const int _maxToolRounds = 3;

  final NativeBridge _bridge;
  final StudyOsToolExecutor _toolExecutor;

  @override
  AgentProvider get provider => AgentProvider.local;

  @override
  String get id => 'local-native';

  @override
  String get displayName => 'Local native model';

  @override
  Future<String> send(AgentLlmRequest request) async {
    final systemPrompt = _localSystemPrompt(request.context.systemPrompt());
    var response = await _bridge.sendMessage(
      request.userText,
      systemPrompt: systemPrompt,
      memory: request.memoryText,
      localModelPath: request.config.localModelPath,
    );
    final toolContext = StudyOsToolContext(
      promptContext: request.context,
      appendMemory: request.appendMemory,
      readMemory: () async => request.memoryText,
      readSchedule: request.readSchedule,
      mailTools: request.mailTools,
    );

    for (var round = 0; round < _maxToolRounds; round += 1) {
      final calls = _toolCalls(response);
      if (calls.isEmpty) return response;

      final feedback = <String>[];
      for (final call in calls) {
        final callId =
            'local-${call.name}-${DateTime.now().microsecondsSinceEpoch}';
        final trace = _traceForCall(call, 'running', callId: callId);
        request.onToolTrace(trace);
        final String output;
        try {
          output = await _toolExecutor.execute(
            call.name,
            call.arguments,
            toolContext,
          );
        } on Object catch (error) {
          request.onToolTrace(
            _traceForCall(
              call,
              'failed',
              callId: callId,
              output: error.toString(),
            ),
          );
          rethrow;
        }
        request.onToolTrace(
          _traceForCall(call, 'done', callId: callId, output: output),
        );
        feedback.add('- ${call.name}: $output');
      }

      response = await _bridge.sendMessage(
        _localToolFeedbackPrompt(feedback),
        systemPrompt: systemPrompt,
        memory: request.memoryText,
        localModelPath: request.config.localModelPath,
      );
    }
    return response;
  }

  String _localSystemPrompt(String basePrompt) {
    final buffer = StringBuffer()
      ..writeln(basePrompt)
      ..writeln()
      ..writeln('Local StudyOS tool protocol:')
      ..writeln(
        'Use StudyOS tools only when they are helpful. For normal questions, answer directly.',
      )
      ..writeln(
        'To call a StudyOS tool, respond only with one or more directives '
        'in this exact form: [TOOL:tool_name:arguments].',
      )
      ..writeln(
        'Use JSON object arguments for tools that take parameters, and {} '
        'for tools with no parameters.',
      )
      ..writeln('After tool results are returned, answer naturally.')
      ..writeln('Available StudyOS tools:');
    for (final tool in studyOsTools) {
      final args = tool.required.isEmpty
          ? '{}'
          : '{${tool.required.map((name) => '"$name":"..."').join(',')}}';
      buffer.writeln('- ${tool.name}: ${tool.description}');
      buffer.writeln('  Example: [TOOL:${tool.name}:$args]');
    }
    return buffer.toString().trim();
  }

  String _localToolFeedbackPrompt(List<String> feedback) {
    return <String>[
      'System feedback from executed StudyOS tools:',
      feedback.join('\n'),
      '',
      'If another StudyOS tool is still needed, respond only with '
          '[TOOL:tool_name:arguments]. Otherwise answer the user naturally '
          'using the tool results.',
    ].join('\n');
  }

  List<_LocalToolCall> _toolCalls(String text) {
    return _toolCallPattern
        .allMatches(text)
        .map((match) {
          final name = match.group(1)?.trim().toLowerCase() ?? '';
          final arguments = match.group(2)?.trim();
          return _LocalToolCall(
            name: name,
            arguments: arguments == null || arguments.isEmpty
                ? '{}'
                : arguments,
          );
        })
        .where((call) => studyOsToolByName(call.name) != null)
        .toList();
  }

  ToolTrace _traceForCall(
    _LocalToolCall call,
    String status, {
    required String callId,
    String? output,
  }) {
    final summary =
        studyOsToolByName(call.name)?.traceSummary ??
        'Requested unavailable tool.';
    final outputSuffix = output == null
        ? ''
        : ' Returned ${output.length} chars.';
    return ToolTrace(
      toolName: call.name,
      status: status,
      summary: '$summary$outputSuffix',
      callId: callId,
    );
  }
}

class _LocalToolCall {
  const _LocalToolCall({required this.name, required this.arguments});

  final String name;
  final String arguments;
}

class CloudLlmProvider implements AgentLlmProvider {
  const CloudLlmProvider(
    this._configStore,
    this._memoryStore,
    this._appendMemory,
    this._cloudClient,
  );

  final AgentConfigStore _configStore;
  final MemoryStore _memoryStore;
  final Future<void> Function(String text) _appendMemory;
  final CloudAgentClient _cloudClient;

  @override
  AgentProvider get provider => AgentProvider.cloud;

  @override
  String get id => 'cloud-openai-compatible';

  @override
  String get displayName => 'OpenAI-compatible cloud model';

  @override
  Future<String> send(AgentLlmRequest request) async {
    final apiKey = await _configStore.readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const CloudAgentException('Cloud API key is required.');
    }
    return _cloudClient.sendMessage(
      config: request.config,
      apiKey: apiKey,
      history: activeSessionFrom(
        request.sessions,
        request.activeSessionId,
      ).messages,
      userText: request.userText,
      context: request.context,
      appendMemory: _appendMemory,
      readMemory: _memoryStore.read,
      readSchedule: request.readSchedule,
      mailTools: request.mailTools,
      onToolTrace: request.onToolTrace,
    );
  }
}
