import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_shell_scope.dart';
import '../studyos_theme.dart';
import '../voice_controller.dart';
import '../widgets/voice_listening_overlay.dart';

class VoiceAssistView extends StatelessWidget {
  const VoiceAssistView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppShellScope.of(context);
    return ListenableBuilder(
      listenable: controller.voice,
      builder: (context, _) {
        final voice = controller.voice;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StudyOsSpacing.lg,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.only(
                      top: StudyOsSpacing.lg,
                      bottom: 96,
                    ),
                    children: <Widget>[
                      _VoiceHeader(onBack: () => context.go('/home')),
                      const SizedBox(height: StudyOsSpacing.lg),
                      VoiceListeningOverlay(voice: voice),
                      _VoiceControlCard(voice: voice),
                      const SizedBox(height: StudyOsSpacing.lg),
                      const _VoiceFeasibilityMatrix(),
                      const SizedBox(height: StudyOsSpacing.lg),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/chat'),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Open chat'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VoiceHeader extends StatelessWidget {
  const _VoiceHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        const SizedBox(width: StudyOsSpacing.sm),
        Expanded(
          child: Text(
            'Voice input spike',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ],
    );
  }
}

class _VoiceControlCard extends StatelessWidget {
  const _VoiceControlCard({required this.voice});

  final VoiceController voice;

  @override
  Widget build(BuildContext context) {
    final available = voice.available;
    return Material(
      color: StudyOsColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: StudyOsColors.border),
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              available ? 'Ready for local voice input' : 'Voice unavailable',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: StudyOsSpacing.sm),
            Text(
              available
                  ? 'Hold to dictate one request, or toggle conversation mode for repeated turns.'
                  : 'Speech recognition is unavailable or permission was denied on this platform.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: StudyOsSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: GestureDetector(
                    onLongPressStart: available
                        ? (_) => voice.startHold()
                        : null,
                    onLongPressEnd: available ? (_) => voice.stopHold() : null,
                    child: FilledButton.icon(
                      onPressed: available ? () {} : null,
                      icon: const Icon(Icons.mic_rounded),
                      label: const Text('Hold to talk'),
                    ),
                  ),
                ),
                const SizedBox(width: StudyOsSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: available ? voice.toggleConversation : null,
                    icon: const Icon(Icons.graphic_eq_rounded),
                    label: Text(
                      voice.conversationMode ? 'Stop loop' : 'Conversation',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceFeasibilityMatrix extends StatelessWidget {
  const _VoiceFeasibilityMatrix();

  @override
  Widget build(BuildContext context) {
    const rows = <_VoiceFeasibilityRow>[
      _VoiceFeasibilityRow(
        title: 'Push-to-talk',
        status: 'Prototype path',
        body:
            'Lowest battery risk. Reuses the existing chat pipeline and only records while the user presses the mic.',
      ),
      _VoiceFeasibilityRow(
        title: 'Conversation mode',
        status: 'Optional demo',
        body:
            'Hands-free after explicit opt-in. Good for testing turn-taking, but should stay foreground-only.',
      ),
      _VoiceFeasibilityRow(
        title: 'Custom hotword',
        status: 'Research gate',
        body:
            'Needs platform-specific checks for background mic access, battery, model size, and offline wake-word support.',
      ),
      _VoiceFeasibilityRow(
        title: 'Passive listener',
        status: 'Defer',
        body:
            'High battery and permission risk. Do not make it the default prototype path.',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Feasibility gates',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: StudyOsSpacing.md),
        for (final row in rows) ...<Widget>[
          _FeasibilityTile(row: row),
          if (row != rows.last) const SizedBox(height: StudyOsSpacing.sm),
        ],
      ],
    );
  }
}

class _VoiceFeasibilityRow {
  const _VoiceFeasibilityRow({
    required this.title,
    required this.status,
    required this.body,
  });

  final String title;
  final String status;
  final String body;
}

class _FeasibilityTile extends StatelessWidget {
  const _FeasibilityTile({required this.row});

  final _VoiceFeasibilityRow row;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudyOsColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: StudyOsColors.border),
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.check_circle_outline, color: StudyOsColors.accent),
            const SizedBox(width: StudyOsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    row.title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: StudyOsSpacing.xs),
                  Text(row.body, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: StudyOsSpacing.sm),
            Text(
              row.status,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: StudyOsColors.success),
            ),
          ],
        ),
      ),
    );
  }
}
