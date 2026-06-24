import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/native_bridge.dart';
import 'package:studyos_agent/src/native_tool_router.dart';

void main() {
  test('NativeToolRouter executes supported native tools', () async {
    final bridge = _FakeNativeBridge(
      capabilities: <String, Object?>{
        'nativeTools': <Map<String, Object?>>[
          <String, Object?>{
            'name': nativeSearchYoutubeToolName,
            'supported': true,
          },
        ],
      },
      response: 'Opened YouTube search.',
    );
    final router = NativeToolRouter(bridge);

    final response = await router.execute(
      nativeSearchYoutubeToolName,
      '{"query":"study techniques"}',
    );

    expect(response, 'Opened YouTube search.');
    expect(bridge.executedTool, nativeSearchYoutubeToolName);
    expect(bridge.executedArguments, <String, Object?>{
      'query': 'study techniques',
    });
  });

  test('NativeToolRouter returns capability reason when unsupported', () async {
    final bridge = _FakeNativeBridge(
      capabilities: <String, Object?>{
        'nativeTools': <Map<String, Object?>>[
          <String, Object?>{
            'name': nativeOpenInstalledAppToolName,
            'supported': false,
            'reason': 'iOS cannot open arbitrary installed apps.',
          },
        ],
      },
    );
    final router = NativeToolRouter(bridge);

    final response = await router.execute(
      nativeOpenInstalledAppToolName,
      '{"name":"Camera"}',
    );

    expect(
      response,
      'Native tool is not supported on this device: open_installed_app. '
      'iOS cannot open arbitrary installed apps.',
    );
    expect(bridge.executedTool, isNull);
  });

  test('NativeToolRouter lists only supported active native tools', () async {
    final bridge = _FakeNativeBridge(
      capabilities: <String, Object?>{
        'nativeTools': <Map<String, Object?>>[
          <String, Object?>{
            'name': nativeDeviceStatusToolName,
            'supported': true,
          },
          <String, Object?>{
            'name': nativeOpenInstalledAppToolName,
            'supported': false,
          },
          <String, Object?>{
            'name': nativeCreateReminderToolName,
            'supported': true,
          },
        ],
      },
    );
    final router = NativeToolRouter(bridge);

    expect(
      await router.supportedToolNames(),
      <String>{nativeDeviceStatusToolName},
    );
  });


  test('NativeToolRouter rejects non-object JSON arguments', () async {
    final router = NativeToolRouter(_FakeNativeBridge());

    expect(
      await router.execute(nativeSetFlashlightToolName, 'true'),
      'Native tool arguments were not valid JSON.',
    );
  });

  test('NativeToolRouter keeps reminder inactive for #30', () async {
    final router = NativeToolRouter(_FakeNativeBridge());

    expect(
      await router.execute(nativeCreateReminderToolName, '{}'),
      'Native tool is not available: create_reminder',
    );
  });
}

class _FakeNativeBridge extends NativeBridge {
  _FakeNativeBridge({
    this.capabilities = const <String, Object?>{},
    this.response = 'Native response.',
  });

  final Map<String, Object?> capabilities;
  final String response;
  String? executedTool;
  Map<String, Object?>? executedArguments;

  @override
  Future<Map<String, Object?>> getNativeToolCapabilities() async {
    return capabilities;
  }

  @override
  Future<String> executeNativeTool(
    String name,
    Map<String, Object?> arguments,
  ) async {
    executedTool = name;
    executedArguments = arguments;
    return response;
  }
}
