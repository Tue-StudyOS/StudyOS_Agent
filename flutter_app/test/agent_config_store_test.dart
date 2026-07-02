import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:studyos_agent/src/agent_config_store.dart';
import 'package:studyos_agent/src/demo_agent_config.dart';
import 'package:studyos_agent/src/models.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('load seeds the OpenRouter preset on first run', () async {
    final store = AgentConfigStore();

    final config = await store.load();

    expect(config.provider, AgentProvider.cloud);
    expect(config.cloudEndpoint, demoOpenRouterEndpoint);
    expect(config.cloudModel, demoOpenRouterModel);
    expect(config.hasApiKey, isFalse);
    expect(await store.readApiKey(), isNull);
  });

  test('saved local configuration suppresses the demo preset', () async {
    final store = AgentConfigStore();

    await store.save(config: const AgentConfig.defaults(), apiKey: '');
    final config = await store.load();

    expect(config.provider, AgentProvider.local);
    expect(config.cloudEndpoint, isEmpty);
    expect(config.cloudModel, isEmpty);
    expect(config.hasApiKey, isFalse);
    expect(await store.readApiKey(), isNull);
  });
}
