import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'agent_exception.dart';
import 'cloud_tool_definitions.dart';
import 'mail_tools.dart';
import 'models.dart';
import 'native_tool_router.dart';
import 'prompt_context.dart';
import 'private_study_tools.dart';
import 'public_study_tools.dart';
import 'studyos_tool_catalog.dart';
import 'studyos_tool_executor.dart';

Future<String> _unavailableAcademicStatus() async =>
    'Academic status is not available.';
Future<String> _unavailableTalks(String query, int limit) async =>
    'Tübingen Talks are not available.';

class CloudAgentClient {
  CloudAgentClient({
    http.Client? httpClient,
    StudyOsToolExecutor? toolExecutor,
    NativeToolRunner? nativeTools,
  }) : _httpClient = httpClient ?? http.Client(),
       _toolExecutor = toolExecutor ?? const StudyOsToolExecutor(),
       // Keep the public constructor parameter named `nativeTools`.
       // ignore: prefer_initializing_formals
       _nativeTools = nativeTools;

  final http.Client _httpClient;
  final StudyOsToolExecutor _toolExecutor;
  final NativeToolRunner? _nativeTools;
  static const int _maxToolRounds = 3;

  Future<String> sendMessage({
    required AgentConfig config,
    required String apiKey,
    required List<ChatMessage> history,
    required String userText,
    required PromptContext context,
    required Future<void> Function(String text) appendMemory,
    required Future<String> Function() readMemory,
    required Future<String> Function() readSchedule,
    Future<String> Function() readAcademicStatus = _unavailableAcademicStatus,
    Future<String> Function(String query, int limit) searchTalks =
        _unavailableTalks,
    required MailToolRunner mailTools,
    PublicStudyToolRunner? publicStudyTools,
    PrivateStudyToolRunner? privateStudyTools,
    void Function(ToolTrace trace)? onToolTrace,
    AgentStreamSink? onDelta,
    AgentCancelToken? cancelToken,
  }) async {
    final endpoint = Uri.tryParse(config.cloudEndpoint.trim());
    if (endpoint == null || !endpoint.hasScheme || !endpoint.hasAuthority) {
      throw const AgentException('Custom AI server URL is not valid.');
    }
    if (config.cloudModel.trim().isEmpty) {
      throw const AgentException('Model name is required.');
    }
    if (apiKey.trim().isEmpty) {
      throw const AgentException('API key is required.');
    }

    final supportedNativeToolNames =
        await _nativeTools?.supportedToolNames() ?? const <String>{};
    var request = _requestBody(
      config: config,
      history: history,
      userText: userText,
      context: context,
      supportedNativeToolNames: supportedNativeToolNames,
    );
    final messages = List<Map<String, Object?>>.from(
      request['messages'] as List,
    );

    final toolContext = StudyOsToolContext(
      promptContext: context,
      appendMemory: appendMemory,
      readMemory: readMemory,
      readSchedule: readSchedule,
      readAcademicStatus: readAcademicStatus,
      searchTalks: searchTalks,
      mailTools: mailTools,
      nativeTools: _nativeTools,
      publicStudyTools: publicStudyTools,
      privateStudyTools: privateStudyTools,
    );
    for (var round = 0; ; round += 1) {
      final message = await _fetchTurn(
        endpoint,
        apiKey,
        request,
        onDelta,
        cancelToken,
      );
      final toolCalls = _toolCalls(message);
      if (toolCalls.isEmpty) {
        return _contentFromMessage(message);
      }
      if (round >= _maxToolRounds) {
        throw const AgentException(
          'Cloud tool loop exceeded the maximum number of tool rounds.',
        );
      }

      // A streamed turn that resolved into tool calls carries no user-facing
      // answer yet; clear the live buffer before the follow-up answer streams.
      onDelta?.call(const AgentStreamDelta(reset: true));

      final toolMessages = <Map<String, Object?>>[];
      for (final call in toolCalls) {
        if (cancelToken?.isCancelled ?? false) {
          throw const AgentCancelledException();
        }
        onToolTrace?.call(_traceForCall(call, 'running'));
        final String output;
        try {
          output = await _toolExecutor.execute(
            call.name,
            call.arguments,
            toolContext,
          );
        } on Object catch (error) {
          final failure = _toolFailureOutput(error);
          onToolTrace?.call(_traceForCall(call, 'failed', output: failure));
          toolMessages.add(<String, Object?>{
            'role': 'tool',
            'tool_call_id': call.id,
            'content': failure,
          });
          continue;
        }
        onToolTrace?.call(_traceForCall(call, 'done', output: output));
        toolMessages.add(<String, Object?>{
          'role': 'tool',
          'tool_call_id': call.id,
          'content': output,
        });
      }

      messages
        ..add(message)
        ..addAll(toolMessages);
      request = <String, Object?>{
        'model': config.cloudModel.trim(),
        'messages': messages,
        'tools': cloudToolDefinitions(
          supportedNativeToolNames: supportedNativeToolNames,
        ),
        'tool_choice': 'auto',
      };
    }
  }

  /// Fetches one assistant turn, returning a message map shaped like
  /// [_messageFromResponse]. Streams via SSE when [onDelta] is provided,
  /// otherwise performs a single buffered request.
  Future<Map<String, Object?>> _fetchTurn(
    Uri endpoint,
    String apiKey,
    Map<String, Object?> body,
    AgentStreamSink? onDelta,
    AgentCancelToken? cancelToken,
  ) async {
    if (cancelToken?.isCancelled ?? false) {
      throw const AgentCancelledException();
    }
    if (onDelta == null) {
      final response = await _awaitCancellable(
        _post(endpoint, apiKey, body),
        cancelToken,
      );
      return _messageFromResponse(_decodeResponse(response));
    }
    return _streamTurn(endpoint, apiKey, body, onDelta, cancelToken);
  }

  /// Awaits [future] but abandons it the moment the request is cancelled, so a
  /// stalled connect (e.g. a misconfigured or unreachable endpoint) unblocks
  /// Stop immediately instead of hanging until the socket times out. The
  /// abandoned request keeps running in the background; [Future.any] swallows
  /// its late completion so it never surfaces as an unhandled error.
  Future<T> _awaitCancellable<T>(
    Future<T> future,
    AgentCancelToken? cancelToken,
  ) {
    if (cancelToken == null) return future;
    final cancelled = cancelToken.whenCancelled.then<T>(
      (_) => throw const AgentCancelledException(),
    );
    return Future.any<T>(<Future<T>>[future, cancelled]);
  }

  Future<Map<String, Object?>> _streamTurn(
    Uri endpoint,
    String apiKey,
    Map<String, Object?> body,
    AgentStreamSink onDelta,
    AgentCancelToken? cancelToken,
  ) async {
    final request = http.Request('POST', endpoint)
      ..headers['Authorization'] = 'Bearer ${apiKey.trim()}'
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode(<String, Object?>{...body, 'stream': true});

    final response = await _awaitCancellable(
      _httpClient.send(request),
      cancelToken,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>();
      throw AgentException(
        'Custom AI service returned HTTP ${response.statusCode}.',
      );
    }

    final contentBuffer = StringBuffer();
    final toolCalls = <int, _StreamingToolCall>{};
    final completer = Completer<Map<String, Object?>>();
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    late final StreamSubscription<String> subscription;

    void complete() {
      if (completer.isCompleted) return;
      completer.complete(<String, Object?>{
        'role': 'assistant',
        'content': contentBuffer.isEmpty ? null : contentBuffer.toString(),
        if (toolCalls.isNotEmpty) 'tool_calls': _assembleToolCalls(toolCalls),
      });
    }

    subscription = lines.listen(
      (rawLine) {
        final line = rawLine.trim();
        if (line.isEmpty || !line.startsWith('data:')) return;
        final data = line.substring(5).trim();
        if (data == '[DONE]') {
          subscription.cancel();
          complete();
          return;
        }
        final decoded = jsonDecode(data);
        if (decoded is! Map) return;
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty || choices.first is! Map) {
          return;
        }
        final delta = (choices.first as Map)['delta'];
        if (delta is! Map) return;

        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          contentBuffer.write(content);
          onDelta(AgentStreamDelta(content: content));
        }
        final reasoning = delta['reasoning'] ?? delta['reasoning_content'];
        if (reasoning is String && reasoning.isNotEmpty) {
          onDelta(AgentStreamDelta(reasoning: reasoning));
        }
        final rawToolCalls = delta['tool_calls'];
        if (rawToolCalls is List) {
          _accumulateToolCalls(rawToolCalls, toolCalls);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
      onDone: complete,
      cancelOnError: true,
    );

    // Aborting the subscription tears down the underlying socket, so a stalled
    // stream (server accepted but never responds) stops immediately on Stop.
    unawaited(
      cancelToken?.whenCancelled.then((_) async {
        await subscription.cancel();
        if (!completer.isCompleted) {
          completer.completeError(const AgentCancelledException());
        }
      }),
    );

    return completer.future;
  }

  void _accumulateToolCalls(
    List<Object?> raw,
    Map<int, _StreamingToolCall> accumulator,
  ) {
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = Map<String, Object?>.from(entry);
      final rawIndex = map['index'];
      final index = rawIndex is int
          ? rawIndex
          : int.tryParse('${rawIndex ?? 0}') ?? 0;
      final slot = accumulator.putIfAbsent(index, _StreamingToolCall.new);
      final id = map['id'];
      if (id is String && id.isNotEmpty) slot.id = id;
      final function = map['function'];
      if (function is Map) {
        final name = function['name'];
        if (name is String && name.isNotEmpty) slot.name = name;
        final args = function['arguments'];
        if (args is String) slot.arguments.write(args);
      }
    }
  }

  List<Map<String, Object?>> _assembleToolCalls(
    Map<int, _StreamingToolCall> accumulator,
  ) {
    final indices = accumulator.keys.toList()..sort();
    return <Map<String, Object?>>[
      for (final index in indices)
        <String, Object?>{
          'id': accumulator[index]!.id,
          'type': 'function',
          'function': <String, Object?>{
            'name': accumulator[index]!.name,
            'arguments': accumulator[index]!.arguments.toString(),
          },
        },
    ];
  }

  Future<http.Response> _post(
    Uri endpoint,
    String apiKey,
    Map<String, Object?> body,
  ) {
    return _httpClient.post(
      endpoint,
      headers: <String, String>{
        'Authorization': 'Bearer ${apiKey.trim()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  Map<String, Object?> _requestBody({
    required AgentConfig config,
    required List<ChatMessage> history,
    required String userText,
    required PromptContext context,
    required Set<String> supportedNativeToolNames,
  }) {
    final historyWithoutCurrent =
        history.isNotEmpty &&
            history.last.isUser &&
            history.last.text.trim() == userText.trim()
        ? history.take(history.length - 1)
        : history;
    return <String, Object?>{
      'model': config.cloudModel.trim(),
      'messages': <Map<String, Object?>>[
        <String, Object?>{'role': 'system', 'content': context.systemPrompt()},
        for (final message in historyWithoutCurrent)
          if (!message.isTrace && message.text.trim().isNotEmpty)
            <String, Object?>{
              'role': message.isUser ? 'user' : 'assistant',
              'content': message.text,
            },
        <String, Object?>{'role': 'user', 'content': userText},
      ],
      'tools': cloudToolDefinitions(
        supportedNativeToolNames: supportedNativeToolNames,
      ),
      'tool_choice': 'auto',
    };
  }

  Map<String, Object?> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AgentException(
        'Custom AI service returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const AgentException('Cloud response was not a JSON object.');
    }
    return decoded;
  }

  Map<String, Object?> _messageFromResponse(Map<String, Object?> decoded) {
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const AgentException('Cloud response did not include choices.');
    }
    final choice = Map<String, Object?>.from(choices.first as Map);
    final message = choice['message'];
    if (message is! Map) {
      throw const AgentException('Cloud response did not include content.');
    }
    return Map<String, Object?>.from(message);
  }

  String _contentFromMessage(Map<String, Object?> message) {
    final content = message['content']?.toString();
    if (content == null || content.trim().isEmpty) {
      throw const AgentException('Cloud response content was empty.');
    }
    return content;
  }

  List<_ToolCall> _toolCalls(Map<String, Object?> message) {
    final rawCalls = message['tool_calls'];
    if (rawCalls is! List) return const <_ToolCall>[];
    return rawCalls
        .whereType<Map>()
        .map((raw) {
          final call = Map<String, Object?>.from(raw);
          final function = call['function'];
          final functionMap = function is Map
              ? Map<String, Object?>.from(function)
              : const <String, Object?>{};
          return _ToolCall(
            id: call['id']?.toString() ?? '',
            name: functionMap['name']?.toString() ?? '',
            arguments: functionMap['arguments']?.toString() ?? '{}',
          );
        })
        .where((call) => call.id.isNotEmpty && call.name.isNotEmpty)
        .toList();
  }

  ToolTrace _traceForCall(_ToolCall call, String status, {String? output}) {
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
      callId: call.id,
      component: output == null
          ? null
          : componentPayloadForTool(call.name, output),
    );
  }
}

class _ToolCall {
  const _ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final String arguments;
}

/// Mutable accumulator for an OpenAI streaming tool call, whose `id`, name, and
/// argument fragments arrive across multiple `delta.tool_calls` chunks.
class _StreamingToolCall {
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();
}

String _toolFailureOutput(Object error) {
  final message = error.toString().trim();
  return message.isEmpty ? 'Tool failed.' : 'Tool failed: $message';
}
