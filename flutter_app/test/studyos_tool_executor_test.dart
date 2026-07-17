import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/mail_repository.dart';
import 'package:studyos_agent/src/mail_tools.dart';
import 'package:studyos_agent/src/native_tool_router.dart';
import 'package:studyos_agent/src/prompt_context.dart';
import 'package:studyos_agent/src/private_study_tools.dart';
import 'package:studyos_agent/src/public_study_tools.dart';
import 'package:studyos_agent/src/studyos_tool_catalog.dart';
import 'package:studyos_agent/src/studyos_tool_executor.dart';

void main() {
  test('StudyOsToolExecutor reads memory and schedule tools', () async {
    final executor = StudyOsToolExecutor();
    final context = _context(
      readMemory: () async => 'Remember office hours.',
      readSchedule: () async => 'Algorithms at 10:00.',
    );

    expect(
      await executor.execute('read_memories', '{}', context),
      'Remember office hours.',
    );
    expect(
      await executor.execute('get_schedule', '{}', context),
      'Algorithms at 10:00.',
    );
  });

  test('StudyOsToolExecutor appends memory from JSON arguments', () async {
    final saved = <String>[];
    final executor = StudyOsToolExecutor();

    final response = await executor.execute(
      'append_memory',
      '{"text":"Prefers morning study blocks."}',
      _context(appendMemory: (text) async => saved.add(text)),
    );

    expect(response, 'Memory saved.');
    expect(saved, <String>['Prefers morning study blocks.']);
  });

  test('StudyOsToolExecutor searches upcoming talks', () async {
    String? requestedQuery;
    int? requestedLimit;

    final response = await const StudyOsToolExecutor().execute(
      'search_talks',
      '{"query":"AI","limit":50}',
      _context(
        searchTalks: (query, limit) async {
          requestedQuery = query;
          requestedLimit = limit;
          return 'Talk results';
        },
      ),
    );

    expect(response, 'Talk results');
    expect(requestedQuery, 'AI');
    expect(requestedLimit, 20);
  });

  test('StudyOsToolExecutor routes public study tools', () async {
    final publicTools = _FakePublicStudyToolRunner('Public results');

    final response = await const StudyOsToolExecutor().execute(
      getMensaOptionsToolName,
      '{"preference":"vegan"}',
      _context(publicStudyTools: publicTools),
    );

    expect(response, 'Public results');
    expect(publicTools.calls, <String>[getMensaOptionsToolName]);
    expect(publicTools.arguments, <String>['{"preference":"vegan"}']);
  });

  test('StudyOsToolExecutor routes private study tools locally', () async {
    final privateTools = _FakePrivateStudyToolRunner('Private results');

    final response = await const StudyOsToolExecutor().execute(
      getTasksToolName,
      '{"sources":["ilias"]}',
      _context(privateStudyTools: privateTools),
    );

    expect(response, 'Private results');
    expect(privateTools.calls, <String>[getTasksToolName]);
  });

  test(
    'StudyOsToolExecutor returns explicit errors for bad tool input',
    () async {
      final executor = StudyOsToolExecutor();
      final context = _context();

      expect(
        await executor.execute('append_memory', '{bad json', context),
        'Memory arguments were not valid JSON.',
      );
      expect(
        await executor.execute('missing_tool', '{}', context),
        'Tool is not available: missing_tool',
      );
    },
  );

  test('StudyOS catalog exposes active native tools for #30 only', () {
    final toolNames = studyOsTools.map((tool) => tool.name).toSet();

    expect(toolNames, contains('search_talks'));
    expect(toolNames, contains(getMensaOptionsToolName));
    expect(toolNames, contains(searchCampusLocationsToolName));
    expect(toolNames, contains(getTasksToolName));
    expect(toolNames, contains(getDeadlinesToolName));
    expect(toolNames, contains(nativeDeviceStatusToolName));
    expect(toolNames, contains(nativeSetFlashlightToolName));
    expect(toolNames, contains(nativeOpenInstalledAppToolName));
    expect(toolNames, contains(nativeSearchYoutubeToolName));
    expect(toolNames, contains(nativeOpenSystemSettingToolName));
    expect(toolNames, contains(nativeCreateReminderToolName));
    expect(toolNames, contains(nativeListCalendarEventsToolName));
    expect(toolNames, contains(nativeCreateCalendarEventToolName));
  });

  test(
    'StudyOsToolExecutor routes native tools through native runner',
    () async {
      final nativeTools = _FakeNativeToolRunner('Flashlight enabled.');
      final executor = StudyOsToolExecutor();

      final response = await executor.execute(
        nativeSetFlashlightToolName,
        '{"enabled":true}',
        _context(nativeTools: nativeTools),
      );

      expect(response, 'Flashlight enabled.');
      expect(nativeTools.calls, <String>[nativeSetFlashlightToolName]);
      expect(nativeTools.arguments, <String>['{"enabled":true}']);
    },
  );

  test('StudyOsToolExecutor gates native tools without runner', () async {
    final executor = StudyOsToolExecutor();

    expect(
      await executor.execute(nativeDeviceStatusToolName, '{}', _context()),
      'Native tool is not available in this runtime: get_device_status',
    );
  });

  test(
    'StudyOsToolExecutor routes create reminder through native runner',
    () async {
      final nativeTools = _FakeNativeToolRunner('Reminder scheduled.');
      final executor = StudyOsToolExecutor();

      final response = await executor.execute(
        nativeCreateReminderToolName,
        '{"title":"Submit report","time":"2026-06-24T18:00:00+02:00"}',
        _context(nativeTools: nativeTools),
      );

      expect(response, 'Reminder scheduled.');
      expect(nativeTools.calls, <String>[nativeCreateReminderToolName]);
    },
  );
}

StudyOsToolContext _context({
  Future<void> Function(String text)? appendMemory,
  Future<String> Function()? readMemory,
  Future<String> Function()? readSchedule,
  Future<String> Function(String query, int limit)? searchTalks,
  NativeToolRunner? nativeTools,
  PublicStudyToolRunner? publicStudyTools,
  PrivateStudyToolRunner? privateStudyTools,
}) {
  return StudyOsToolContext(
    promptContext: const PromptContext(
      profile: null,
      memory: '',
      worldState: <String, Object?>{},
    ),
    appendMemory: appendMemory ?? (_) async {},
    readMemory: readMemory ?? () async => '',
    readSchedule: readSchedule ?? () async => '',
    searchTalks: searchTalks ?? (_, _) async => '',
    mailTools: MailToolRunner(repository: MailRepository(), profile: null),
    nativeTools: nativeTools,
    publicStudyTools: publicStudyTools,
    privateStudyTools: privateStudyTools,
  );
}

class _FakePrivateStudyToolRunner implements PrivateStudyToolRunner {
  _FakePrivateStudyToolRunner(this.response);

  final String response;
  final calls = <String>[];

  @override
  Future<String> execute(String toolName, String arguments) async {
    calls.add(toolName);
    return response;
  }

  @override
  void invalidate() {}
}

class _FakePublicStudyToolRunner implements PublicStudyToolRunner {
  _FakePublicStudyToolRunner(this.response);

  final String response;
  final calls = <String>[];
  final arguments = <String>[];

  @override
  Future<String> execute(String toolName, String arguments) async {
    calls.add(toolName);
    this.arguments.add(arguments);
    return response;
  }

  @override
  void close() {}
}

class _FakeNativeToolRunner implements NativeToolRunner {
  _FakeNativeToolRunner(this.response);

  final String response;
  final calls = <String>[];
  final arguments = <String>[];

  @override
  Future<Set<String>> supportedToolNames() async => activeNativeToolNames;

  @override
  Future<String> execute(String toolName, String arguments) async {
    calls.add(toolName);
    this.arguments.add(arguments);
    return response;
  }
}
