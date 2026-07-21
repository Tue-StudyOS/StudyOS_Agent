import 'dart:convert';

import 'capability_result.dart';
import 'private_study_capabilities.dart';
import 'private_study_models.dart';

const getTasksToolName = 'get_tasks';
const getDeadlinesToolName = 'get_deadlines';

abstract interface class PrivateStudyToolRunner {
  Future<String> execute(String toolName, String arguments);
  void invalidate();
}

class LivePrivateStudyToolRunner implements PrivateStudyToolRunner {
  LivePrivateStudyToolRunner(this._capability);

  final PrivateStudyCapability _capability;

  @override
  Future<String> execute(String toolName, String arguments) async {
    final Map<String, Object?> args;
    try {
      final decoded = arguments.trim().isEmpty
          ? <String, Object?>{}
          : jsonDecode(arguments);
      if (decoded is! Map) throw const FormatException();
      args = Map<String, Object?>.from(decoded);
    } on Object {
      return _failure('Tool arguments must be a JSON object.');
    }
    final sources = _sources(args['sources']);
    if (sources == null) {
      return _failure('Sources must be a subset of ilias and moodle.');
    }
    return switch (toolName) {
      getTasksToolName => _tasks(args, sources),
      getDeadlinesToolName => _deadlines(args, sources),
      _ => _failure('Private study tool is not available.'),
    };
  }

  Future<String> _tasks(
    Map<String, Object?> args,
    Set<StudyPortalSource> sources,
  ) async {
    final result = await _capability.tasks(
      sources: sources,
      limit: _boundedInt(args['limit'], fallback: 20, max: 50),
    );
    return jsonEncode(
      result.toJson(
        (items) => items.map((item) => item.toJson()).toList(growable: false),
      ),
    );
  }

  Future<String> _deadlines(
    Map<String, Object?> args,
    Set<StudyPortalSource> sources,
  ) async {
    final result = await _capability.deadlines(
      sources: sources,
      days: _boundedInt(args['days'], fallback: 30, max: 180),
      limit: _boundedInt(args['limit'], fallback: 30, max: 100),
    );
    return jsonEncode(
      result.toJson(
        (items) => items.map((item) => item.toJson()).toList(growable: false),
      ),
    );
  }

  String _failure(String message) => jsonEncode(
    CapabilityResult<List<Object?>>(
      state: CapabilityState.failed,
      policy: CapabilityPolicy.privateRead,
      source: PrivateStudyCapability.source,
      fetchedAt: DateTime.now(),
      message: message,
    ).toJson((items) => items),
  );

  @override
  void invalidate() => _capability.invalidate();
}

Set<StudyPortalSource>? _sources(Object? value) {
  if (value == null) return StudyPortalSource.values.toSet();
  if (value is! List || value.isEmpty) return null;
  final result = <StudyPortalSource>{};
  for (final item in value) {
    final normalized = item.toString().trim().toLowerCase();
    final source = StudyPortalSource.values
        .where((candidate) => candidate.name == normalized)
        .firstOrNull;
    if (source == null) return null;
    result.add(source);
  }
  return result;
}

int _boundedInt(Object? value, {required int fallback, required int max}) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  return (parsed ?? fallback).clamp(1, max).toInt();
}
