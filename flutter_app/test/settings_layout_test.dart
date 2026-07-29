import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/native_bridge.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/views/settings_view.dart';

/// Guards against layout overflow on narrow phones. The settings "Assistant"
/// card nests dropdowns, segmented buttons and a button row; a model dropdown
/// once overflowed its row by 274px (missing `isExpanded`), painting the label
/// across neighbouring widgets. These pump the full view at real phone widths
/// with the LiteRT section expanded and assert no RenderFlex overflows.
void main() {
  for (final width in <double>[320, 360]) {
    for (final provider in AgentProvider.values) {
      testWidgets('settings has no overflow for $provider at ${width}px', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          overflows.add(details.exceptionAsString());
        };
        addTearDown(() => FlutterError.onError = previous);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildStudyOsTheme(),
            home: Scaffold(
              body: Center(
                child: ConstrainedBox(
                  // Mirror the real route scaffold's width clamp + padding.
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SettingsView(
                      config: AgentConfig.defaults().copyWith(
                        provider: provider,
                        // Non-empty path forces the LiteRT ExpansionTile open so
                        // its dropdown/segmented/switch content is laid out.
                        localModelPath: '/data/model.litertlm',
                        localToolProtocol:
                            LocalToolProtocol.nativeFunctionCalling,
                      ),
                      profile: null,
                      status: 'Ready',
                      compactMessages: false,
                      onLogout: () {},
                      onSaveProfile: (_) async {},
                      onSaveAgentConfig: (_, _) async {},
                      onCompactMessagesChanged: (_) {},
                      nativeBridge: NativeBridge(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        expect(
          overflows,
          isEmpty,
          reason: 'Settings overflowed at ${width}px:\n${overflows.join('\n')}',
        );
      });
    }
  }
}
