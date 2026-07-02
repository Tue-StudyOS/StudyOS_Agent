import 'models.dart';

const demoOpenRouterEndpoint = String.fromEnvironment(
  'STUDYOS_DEMO_OPENROUTER_ENDPOINT',
  defaultValue: 'https://openrouter.ai/api/v1/chat/completions',
);

const demoOpenRouterModel = String.fromEnvironment(
  'STUDYOS_DEMO_OPENROUTER_MODEL',
  defaultValue: 'nvidia/nemotron-3-ultra-550b-a55b:free',
);

const demoOpenRouterApiKey = String.fromEnvironment(
  'STUDYOS_DEMO_OPENROUTER_API_KEY',
  defaultValue: '',
);

AgentConfig demoAgentConfig() {
  return AgentConfig(
    provider: AgentProvider.cloud,
    cloudEndpoint: demoOpenRouterEndpoint,
    cloudModel: demoOpenRouterModel,
    hasApiKey: demoOpenRouterApiKey.isNotEmpty,
    localModelId: const AgentConfig.defaults().localModelId,
    localModelPath: '',
  );
}
