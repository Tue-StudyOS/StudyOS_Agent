const String defaultAndroidAiCoreModelId = 'android-aicore-stable-full';
const String androidAiCoreModelPrefix = 'android-aicore-';

bool isAndroidAiCoreModelId(String id) =>
    id.startsWith(androidAiCoreModelPrefix);

class AndroidAiCoreModelOption {
  const AndroidAiCoreModelOption({
    required this.id,
    required this.label,
    required this.releaseStage,
    required this.preference,
    required this.status,
    required this.baseModelName,
  });

  factory AndroidAiCoreModelOption.fromMap(Map<String, Object?> value) {
    return AndroidAiCoreModelOption(
      id: value['id']?.toString() ?? '',
      label: value['label']?.toString() ?? 'Gemini Nano',
      releaseStage: value['releaseStage']?.toString() ?? '',
      preference: value['preference']?.toString() ?? '',
      status: value['status']?.toString() ?? 'unavailable',
      baseModelName: value['baseModelName']?.toString() ?? '',
    );
  }

  final String id;
  final String label;
  final String releaseStage;
  final String preference;
  final String status;
  final String baseModelName;

  bool get isAvailable => status == 'available';
  bool get isDownloadable => status == 'downloadable';
  bool get isDownloading => status == 'downloading';
  bool get isSupported => isAvailable || isDownloadable || isDownloading;

  String get statusLabel => switch (status) {
    'available' => 'Available',
    'downloadable' => 'Download required',
    'downloading' => 'Downloading',
    _ => 'Not supported',
  };
}

String androidAiCoreModelLabel(String id) {
  return switch (id) {
    'android-aicore-stable-fast' => 'Gemini Nano · Stable · Fast',
    'android-aicore-preview-full' => 'Gemini Nano · Preview · Full',
    'android-aicore-preview-fast' => 'Gemini Nano · Preview · Fast',
    _ => 'Gemini Nano · Stable · Full',
  };
}
