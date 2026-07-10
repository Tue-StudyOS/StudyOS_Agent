import 'android_ai_core_models.dart';
import 'models.dart';

bool assistantIsReady(String status) {
  final lower = status.toLowerCase();
  return lower.contains('ready') ||
      lower.contains('initialized') ||
      lower.contains('response received');
}

String assistantStatusLabel(String status) {
  if (assistantIsReady(status)) return 'Ready';
  if (status.trim().isEmpty || status == 'Starting') return 'Starting';
  return 'Needs attention';
}

String assistantSetupLabel(AgentConfig config) {
  if (config.usesCloud) {
    final model = config.cloudModel.trim();
    return model.isEmpty ? 'Custom AI' : model;
  }
  if (config.localModelPath.trim().isNotEmpty) {
    return 'Downloaded custom model';
  }
  if (isAndroidAiCoreModelId(config.localModelId)) {
    return androidAiCoreModelLabel(config.localModelId);
  }
  return 'Built-in platform AI';
}
