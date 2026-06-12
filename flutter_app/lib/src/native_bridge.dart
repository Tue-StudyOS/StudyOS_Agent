import 'package:flutter/services.dart';

import 'models.dart';

class NativeBridge {
  static const MethodChannel _methods = MethodChannel('studyos/native');
  static const EventChannel _events = EventChannel('studyos/events');

  Stream<NativeEvent> get events =>
      _events.receiveBroadcastStream().map((event) {
        if (event is Map) {
          return NativeEvent.fromMap(Map<String, Object?>.from(event));
        }
        return const NativeEvent(type: 'status', message: '', timestamp: '');
      });

  Future<Map<String, Object?>> initialize() async {
    final result = await _methods.invokeMapMethod<String, Object?>(
      'initialize',
    );
    return result ?? const {};
  }

  Future<Map<String, Object?>> getWorldState() async {
    final result = await _methods.invokeMapMethod<String, Object?>(
      'getWorldState',
    );
    return result ?? const {};
  }

  Future<Map<String, Object?>> getCapabilities() async {
    final result = await _methods.invokeMapMethod<String, Object?>(
      'getCapabilities',
    );
    return result ?? const {};
  }

  Future<String> sendMessage(
    String text, {
    String? systemPrompt,
    String? memory,
  }) async {
    final result = await _methods.invokeMethod<String>(
      'sendMessage',
      <String, Object?>{
        'text': text,
        'systemPrompt': systemPrompt,
        'memory': memory,
      },
    );
    return result ?? 'The assistant did not return a response.';
  }
}
