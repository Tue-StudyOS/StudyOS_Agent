import 'dart:convert';

import 'package:flutter/services.dart';

import 'native_bridge.dart';

const nativeDeviceStatusToolName = 'get_device_status';
const nativeSetFlashlightToolName = 'set_flashlight';
const nativeOpenInstalledAppToolName = 'open_installed_app';
const nativeSearchYoutubeToolName = 'search_youtube';
const nativeOpenSystemSettingToolName = 'open_system_setting';
const nativeCreateReminderToolName = 'create_reminder';

const activeNativeToolNames = <String>{
  nativeDeviceStatusToolName,
  nativeSetFlashlightToolName,
  nativeOpenInstalledAppToolName,
  nativeSearchYoutubeToolName,
  nativeOpenSystemSettingToolName,
  nativeCreateReminderToolName,
};

abstract class NativeToolRunner {
  Future<Set<String>> supportedToolNames();

  Future<String> execute(String toolName, String arguments);
}

class NativeToolRouter implements NativeToolRunner {
  NativeToolRouter(this._bridge);

  final NativeBridge _bridge;
  Future<NativeToolCapabilities>? _capabilities;

  @override
  Future<Set<String>> supportedToolNames() async {
    final capabilities = await _loadCapabilities();
    return capabilities.supportedToolNames(activeNativeToolNames);
  }

  @override
  Future<String> execute(String toolName, String arguments) async {
    if (!activeNativeToolNames.contains(toolName)) {
      return 'Native tool is not available: $toolName';
    }

    final Map<String, Object?> decodedArguments;
    try {
      decodedArguments = _decodeArguments(arguments);
    } on FormatException {
      return 'Native tool arguments were not valid JSON.';
    }

    final capabilities = await _loadCapabilities();
    final support = capabilities.supportFor(toolName);
    if (!support.supported) {
      return support.messageFor(toolName);
    }

    try {
      return await _bridge.executeNativeTool(toolName, decodedArguments);
    } on PlatformException catch (error) {
      return error.message ?? 'Native tool failed: ${error.code}';
    }
  }

  Future<NativeToolCapabilities> _loadCapabilities() {
    return _capabilities ??= _bridge.getNativeToolCapabilities().then(
      NativeToolCapabilities.fromMap,
    );
  }

  Map<String, Object?> _decodeArguments(String arguments) {
    final trimmed = arguments.trim();
    if (trimmed.isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) {
      throw const FormatException('Expected JSON object arguments.');
    }
    return Map<String, Object?>.from(decoded);
  }
}

class NativeToolCapabilities {
  const NativeToolCapabilities(this._tools);

  factory NativeToolCapabilities.fromMap(Map<String, Object?> capabilities) {
    final entries = capabilities['nativeTools'];
    final tools = <String, NativeToolSupport>{};
    if (entries is List) {
      for (final entry in entries) {
        if (entry is! Map) continue;
        final mapped = Map<String, Object?>.from(entry);
        final name = mapped['name']?.toString();
        if (name == null || name.isEmpty) continue;
        tools[name] = NativeToolSupport(
          supported: mapped['supported'] == true,
          reason: mapped['reason']?.toString(),
        );
      }
    }
    return NativeToolCapabilities(tools);
  }

  final Map<String, NativeToolSupport> _tools;

  NativeToolSupport supportFor(String toolName) {
    return _tools[toolName] ?? const NativeToolSupport(supported: false);
  }

  Set<String> supportedToolNames(Iterable<String> toolNames) {
    return toolNames
        .where((toolName) => supportFor(toolName).supported)
        .toSet();
  }
}

class NativeToolSupport {
  const NativeToolSupport({required this.supported, this.reason});

  final bool supported;
  final String? reason;

  String messageFor(String toolName) {
    final detail = reason?.trim();
    if (detail == null || detail.isEmpty) {
      return 'Native tool is not supported on this device: $toolName';
    }
    return 'Native tool is not supported on this device: $toolName. $detail';
  }
}
