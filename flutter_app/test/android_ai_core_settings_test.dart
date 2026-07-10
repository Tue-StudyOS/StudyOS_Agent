import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/native_bridge.dart';
import 'package:studyos_agent/src/widgets/local_model_settings_card.dart';

void main() {
  testWidgets('shows supported AICore models and collapses custom controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _shell(
        LocalModelSettingsCard(
          config: const AgentConfig.defaults(),
          nativeBridge: _FakeNativeBridge(<Map<String, Object?>>[
            _model(
              id: 'android-aicore-stable-full',
              label: 'Gemini Nano · Stable · Full',
              status: 'available',
              baseModelName: 'nano-v3',
            ),
            _model(
              id: 'android-aicore-preview-full',
              label: 'Gemini Nano · Preview · Full',
              status: 'unavailable',
            ),
          ]),
          onSaveAgentConfig: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Android built-in AI'), findsOneWidget);
    expect(find.text('Gemini Nano · Stable · Full'), findsOneWidget);
    expect(find.text('Available · nano-v3'), findsOneWidget);
    expect(find.text('Gemini Nano · Preview · Full'), findsNothing);
    expect(find.text('Custom LiteRT-LM'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Direct model URL'), findsNothing);
  });

  testWidgets('reduces unsupported AICore to one compact status row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _shell(
        LocalModelSettingsCard(
          config: const AgentConfig.defaults(),
          nativeBridge: _FakeNativeBridge(<Map<String, Object?>>[
            _model(
              id: 'android-aicore-stable-full',
              label: 'Gemini Nano · Stable · Full',
              status: 'unavailable',
            ),
          ]),
          onSaveAgentConfig: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not supported on this device.'), findsOneWidget);
    expect(find.text('Built-in model'), findsNothing);
    expect(find.text('Custom LiteRT-LM'), findsOneWidget);
  });

  testWidgets('preselects an available AICore model for legacy local config', (
    tester,
  ) async {
    AgentConfig? saved;
    await tester.pumpWidget(
      _shell(
        LocalModelSettingsCard(
          config: const AgentConfig(
            provider: AgentProvider.local,
            cloudEndpoint: '',
            cloudModel: '',
            hasApiKey: false,
            localModelId: 'gemma-4-e2b-it',
            localModelPath: '',
          ),
          nativeBridge: _FakeNativeBridge(<Map<String, Object?>>[
            _model(
              id: 'android-aicore-stable-full',
              label: 'Gemini Nano · Stable · Full',
              status: 'available',
            ),
          ]),
          onSaveAgentConfig: (config, _) async => saved = config,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(saved?.localModelId, 'android-aicore-stable-full');
    expect(saved?.localModelPath, isEmpty);
  });

  testWidgets('keeps custom LiteRT controls expanded when a model is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      _shell(
        LocalModelSettingsCard(
          config: const AgentConfig(
            provider: AgentProvider.local,
            cloudEndpoint: '',
            cloudModel: '',
            hasApiKey: false,
            localModelId: 'gemma-4-e2b-it',
            localModelPath: '/tmp/gemma.litertlm',
          ),
          nativeBridge: _FakeNativeBridge(<Map<String, Object?>>[
            _model(
              id: 'android-aicore-stable-full',
              label: 'Gemini Nano · Stable · Full',
              status: 'unavailable',
            ),
          ]),
          onSaveAgentConfig: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Direct model URL'), findsOneWidget);
    expect(find.text('Accelerator'), findsOneWidget);
  });
}

Widget _shell(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Map<String, Object?> _model({
  required String id,
  required String label,
  required String status,
  String baseModelName = '',
}) {
  return <String, Object?>{
    'id': id,
    'label': label,
    'releaseStage': 'stable',
    'preference': 'full',
    'status': status,
    'baseModelName': baseModelName,
  };
}

class _FakeNativeBridge extends NativeBridge {
  _FakeNativeBridge(this.models);

  final List<Map<String, Object?>> models;

  @override
  Future<List<Map<String, Object?>>> listAndroidAiCoreModels() async => models;

  @override
  Future<List<Map<String, Object?>>> listLocalModels() async => const [];
}
