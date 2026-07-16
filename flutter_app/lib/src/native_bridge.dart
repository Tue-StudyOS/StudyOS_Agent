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

  // TODO(voice): native voice assist should emit
  // {type: 'voicePrompt', message: '<transcript>', autosend: true} so the
  // Flutter router can open /chat?prompt=<transcript>&autosend=true without
  // touching widget-local navigation state.

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

  Future<Map<String, Object?>> getNativeToolCapabilities() async {
    final result = await _methods.invokeMapMethod<String, Object?>(
      'getNativeToolCapabilities',
    );
    return result ?? const {};
  }

  Future<String> executeNativeTool(
    String name,
    Map<String, Object?> arguments,
  ) async {
    final result = await _methods.invokeMethod<String>(
      'executeNativeTool',
      <String, Object?>{'name': name, 'arguments': arguments},
    );
    return result ?? 'Native tool returned no response.';
  }

  Future<List<Map<String, Object?>>> listLocalModels() async {
    final result = await _methods.invokeListMethod<Object?>('listLocalModels');
    return (result ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }

  Future<List<Map<String, Object?>>> listAndroidAiCoreModels() async {
    final result = await _methods.invokeListMethod<Object?>(
      'listAndroidAiCoreModels',
    );
    return (result ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }

  Future<void> downloadAndroidAiCoreModel(String modelId) async {
    await _methods.invokeMethod<void>(
      'downloadAndroidAiCoreModel',
      <String, Object?>{'modelId': modelId},
    );
  }

  Future<Map<String, Object?>> downloadLocalModel({
    required String id,
    required String label,
    required String fileName,
    required String url,
  }) async {
    final result = await _methods.invokeMapMethod<String, Object?>(
      'downloadLocalModel',
      <String, Object?>{
        'id': id,
        'label': label,
        'fileName': fileName,
        'url': url,
      },
    );
    return result ?? const {};
  }

  Future<void> cancelLocalModelDownload() async {
    await _methods.invokeMethod<String>('cancelLocalModelDownload');
  }

  Future<void> deleteLocalModel(String id) async {
    await _methods.invokeMethod<String>('deleteLocalModel', <String, Object?>{
      'id': id,
    });
  }

  Future<String?> consumePendingIntentPrompt() {
    return _methods.invokeMethod<String>('consumePendingIntentPrompt');
  }

  Future<void> publishIntentSnapshot({
    required TimetableSnapshot? timetable,
    required String memoryText,
  }) async {
    await _methods
        .invokeMethod<String>('publishIntentSnapshot', <String, Object?>{
          'updatedAt': DateTime.now().toIso8601String(),
          'memoryPreview': _memoryPreview(memoryText),
          'lectures':
              timetable?.events.map((event) => event.toJson()).toList() ??
              const <Map<String, Object?>>[],
        });
  }

  Future<String> syncScheduleToCalendar(TimetableSnapshot timetable) async {
    final result = await _methods
        .invokeMethod<String>('syncScheduleToCalendar', <String, Object?>{
          'sourceTerm': timetable.sourceTerm,
          'updatedAt': DateTime.now().toIso8601String(),
          'windowStart': timetable.refreshedAt.toIso8601String(),
          'windowEnd': timetable.refreshedAt
              .add(timetableLookAhead)
              .toIso8601String(),
          'lectures': timetable.events.map((event) => event.toJson()).toList(),
        });
    return result ?? 'Calendar sync finished.';
  }

  Future<List<Map<String, Object?>>> listDeviceCalendarEvents({
    required DateTime start,
    required DateTime end,
    int limit = 250,
  }) async {
    final result = await _methods.invokeListMethod<Object?>(
      'listDeviceCalendarEvents',
      <String, Object?>{
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'limit': limit.clamp(1, 500),
      },
    );
    return (result ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(
          (event) => event.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }

  Future<String> extractPdfText(Uint8List document) async {
    final text = await _methods.invokeMethod<String>(
      'extractPdfText',
      <String, Object?>{'document': document},
    );
    if (text == null || text.trim().isEmpty) {
      throw PlatformException(
        code: 'pdf_text_empty',
        message: 'The registration report did not contain extractable text.',
      );
    }
    return text;
  }

  Future<void> previewPdf({
    required Uint8List document,
    required String filename,
  }) async {
    await _methods.invokeMethod<String>('previewPdf', <String, Object?>{
      'document': document,
      'filename': filename,
    });
  }

  Future<String> sendMessage(
    String text, {
    String? systemPrompt,
    String? memory,
    String? localModelId,
    String? localModelPath,
    String? localBackend,
  }) async {
    final result = await _methods
        .invokeMethod<String>('sendMessage', <String, Object?>{
          'text': text,
          'systemPrompt': systemPrompt,
          'memory': memory,
          'localModelId': localModelId,
          'localModelPath': localModelPath,
          'localBackend': localBackend,
        });
    return result ?? 'The assistant did not return a response.';
  }

  /// Best-effort cancel of an in-flight local (native) generation. No-op on
  /// platforms without a local model bridge.
  Future<void> cancelMessage() async {
    await _methods.invokeMethod<void>('cancelMessage');
  }

  String _memoryPreview(String value) {
    const maxCharacters = 4000;
    final cleaned = value.trim();
    if (cleaned.length <= maxCharacters) return cleaned;
    return cleaned.substring(cleaned.length - maxCharacters);
  }
}
