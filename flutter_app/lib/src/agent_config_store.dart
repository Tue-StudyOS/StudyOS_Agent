import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AgentConfigStore {
  AgentConfigStore({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _providerKey = 'studyos.agent.provider.v1';
  static const String _endpointKey = 'studyos.agent.cloudEndpoint.v1';
  static const String _modelKey = 'studyos.agent.cloudModel.v1';
  static const String _apiKeyKey = 'studyos.agent.cloudApiKey.v1';

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secureStorage;

  Future<AgentConfig> load() async {
    final providerName = await _preferences.getString(_providerKey);
    final endpoint = await _preferences.getString(_endpointKey);
    final model = await _preferences.getString(_modelKey);
    final apiKey = await _secureStorage.read(key: _apiKeyKey);

    return AgentConfig(
      provider: providerName == AgentProvider.cloud.name
          ? AgentProvider.cloud
          : AgentProvider.local,
      cloudEndpoint: endpoint ?? '',
      cloudModel: model ?? '',
      hasApiKey: apiKey != null && apiKey.isNotEmpty,
    );
  }

  Future<String?> readApiKey() {
    return _secureStorage.read(key: _apiKeyKey);
  }

  Future<void> save({
    required AgentConfig config,
    required String? apiKey,
  }) async {
    await _preferences.setString(_providerKey, config.provider.name);
    await _preferences.setString(_endpointKey, config.cloudEndpoint.trim());
    await _preferences.setString(_modelKey, config.cloudModel.trim());

    if (apiKey != null) {
      final trimmed = apiKey.trim();
      if (trimmed.isEmpty) {
        await _secureStorage.delete(key: _apiKeyKey);
      } else {
        await _secureStorage.write(key: _apiKeyKey, value: trimmed);
      }
    }
  }
}
