import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_agent_config.dart';
import 'models.dart';

class AgentConfigStore {
  factory AgentConfigStore({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
  }) {
    return AgentConfigStore._(preferences, secureStorage);
  }

  AgentConfigStore._(this._preferences, this._secureStorage);

  static const String _providerKey = 'studyos.agent.provider.v1';
  static const String _endpointKey = 'studyos.agent.cloudEndpoint.v1';
  static const String _modelKey = 'studyos.agent.cloudModel.v1';
  static const String _localModelIdKey = 'studyos.agent.localModelId.v1';
  static const String _localModelPathKey = 'studyos.agent.localModelPath.v1';
  static const String _localBackendKey = 'studyos.agent.localBackend.v1';
  static const String _apiKeyKey = 'studyos.agent.cloudApiKey.v1';

  final SharedPreferencesAsync? _preferences;
  final FlutterSecureStorage? _secureStorage;

  SharedPreferencesAsync get _prefs => _preferences ?? SharedPreferencesAsync();
  FlutterSecureStorage get _secure =>
      _secureStorage ?? const FlutterSecureStorage();

  Future<AgentConfig> load() async {
    final providerName = await _prefs.getString(_providerKey);
    final endpoint = await _prefs.getString(_endpointKey);
    final model = await _prefs.getString(_modelKey);
    final localModelId = await _prefs.getString(_localModelIdKey);
    final localModelPath = await _prefs.getString(_localModelPathKey);
    final localBackend = await _prefs.getString(_localBackendKey);
    final apiKey = await _secure.read(key: _apiKeyKey);
    if (_hasNoSavedConfig(
      providerName: providerName,
      endpoint: endpoint,
      model: model,
      localModelId: localModelId,
      localModelPath: localModelPath,
      apiKey: apiKey,
    )) {
      final demoConfig = demoAgentConfig();
      await _saveValues(config: demoConfig);
      if (demoOpenRouterApiKey.isNotEmpty) {
        await _secure.write(key: _apiKeyKey, value: demoOpenRouterApiKey);
      }
      return demoConfig;
    }

    return AgentConfig(
      provider: providerName == AgentProvider.cloud.name
          ? AgentProvider.cloud
          : AgentProvider.local,
      cloudEndpoint: endpoint ?? '',
      cloudModel: model ?? '',
      hasApiKey: apiKey != null && apiKey.isNotEmpty,
      localModelId: localModelId ?? const AgentConfig.defaults().localModelId,
      localModelPath: localModelPath ?? '',
      localBackend: localBackendFromName(localBackend),
    );
  }

  Future<String?> readApiKey() {
    return _secure.read(key: _apiKeyKey);
  }

  Future<void> save({
    required AgentConfig config,
    required String? apiKey,
  }) async {
    await _saveValues(config: config);

    if (apiKey != null) {
      final trimmed = apiKey.trim();
      if (trimmed.isEmpty) {
        await _secure.delete(key: _apiKeyKey);
      } else {
        await _secure.write(key: _apiKeyKey, value: trimmed);
      }
    }
  }

  Future<void> _saveValues({required AgentConfig config}) async {
    await _prefs.setString(_providerKey, config.provider.name);
    await _prefs.setString(_endpointKey, config.cloudEndpoint.trim());
    await _prefs.setString(_modelKey, config.cloudModel.trim());
    await _prefs.setString(_localModelIdKey, config.localModelId.trim());
    await _prefs.setString(_localModelPathKey, config.localModelPath.trim());
    await _prefs.setString(_localBackendKey, config.localBackend.name);
  }

  bool _hasNoSavedConfig({
    required String? providerName,
    required String? endpoint,
    required String? model,
    required String? localModelId,
    required String? localModelPath,
    required String? apiKey,
  }) {
    return providerName == null &&
        endpoint == null &&
        model == null &&
        localModelId == null &&
        localModelPath == null &&
        apiKey == null;
  }
}
