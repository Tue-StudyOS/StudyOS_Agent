import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/mail_repository.dart';
import 'package:studyos_agent/src/mail_tools.dart';
import 'package:studyos_agent/src/native_tool_router.dart';
import 'package:studyos_agent/src/prompt_context.dart';
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

    expect(toolNames, contains(nativeDeviceStatusToolName));
    expect(toolNames, contains(nativeSetFlashlightToolName));
    expect(toolNames, contains(nativeOpenInstalledAppToolName));
    expect(toolNames, contains(nativeSearchYoutubeToolName));
    expect(toolNames, contains(nativeOpenSystemSettingToolName));
    expect(toolNames, isNot(contains(nativeCreateReminderToolName)));
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
}

StudyOsToolContext _context({
  Future<void> Function(String text)? appendMemory,
  Future<String> Function()? readMemory,
  Future<String> Function()? readSchedule,
  NativeToolRunner? nativeTools,
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
    mailTools: MailToolRunner(repository: MailRepository(), profile: null),
    nativeTools: nativeTools,
  );
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
