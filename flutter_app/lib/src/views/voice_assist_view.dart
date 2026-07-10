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
                    horizontal: StudyOsSpacing.xl,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.only(
                      top: StudyOsSpacing.md,
                      bottom: StudyOsSpacing.xxl,
                    ),
                    children: <Widget>[
                      _VoiceHeader(onBack: () => context.go('/home')),
                      const SizedBox(height: StudyOsSpacing.xxl),
                      Text(
                        'Voice',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: StudyOsSpacing.xs),
                      Text(
                        'Speak to StudyOS when typing is inconvenient.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: StudyOsSpacing.xxl),
                      VoiceListeningOverlay(voice: voice),
                      _VoiceControlSurface(voice: voice),
                      const SizedBox(height: StudyOsSpacing.xxl),
                      Text(
                        'Voice options',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: StudyOsSpacing.sm),
                      const _VoiceOptions(),
                      const SizedBox(height: StudyOsSpacing.xl),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/chat'),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('Continue in chat'),
                        ),
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
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: IconButton(
      tooltip: 'Back',
      onPressed: onBack,
      style: IconButton.styleFrom(
        backgroundColor: StudyOsColors.surface,
        foregroundColor: StudyOsColors.text,
      ),
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
    ),
  );
}

class _VoiceControlSurface extends StatelessWidget {
  const _VoiceControlSurface({required this.voice});
  final VoiceController voice;

  @override
  Widget build(BuildContext context) {
    final available = voice.available;
    return Material(
      color: StudyOsColors.text,
      borderRadius: BorderRadius.circular(StudyOsRadii.lg),
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              available ? Icons.mic_rounded : Icons.mic_off_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: StudyOsSpacing.lg),
            Text(
              available ? 'Ready to listen' : 'Voice is unavailable',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: StudyOsSpacing.xs),
            Text(
              available
                  ? 'Hold the button for one request, or start a conversation for repeated turns.'
                  : 'Speech recognition is unavailable or permission was denied.',
              style: const TextStyle(
                color: Color(0xFFD1D1D6),
                fontSize: 15,
                height: 1.3,
              ),
            ),
            const SizedBox(height: StudyOsSpacing.xl),
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
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: StudyOsColors.text,
                      ),
                      icon: const Icon(Icons.mic_rounded),
                      label: const Text('Hold to talk'),
                    ),
                  ),
                ),
                const SizedBox(width: StudyOsSpacing.md),
                IconButton.filled(
                  tooltip: voice.conversationMode
                      ? 'Stop conversation'
                      : 'Start conversation',
                  onPressed: available ? voice.toggleConversation : null,
                  style: IconButton.styleFrom(
                    backgroundColor: StudyOsColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(
                    voice.conversationMode
                        ? Icons.stop_rounded
                        : Icons.graphic_eq_rounded,
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

class _VoiceOptions extends StatelessWidget {
  const _VoiceOptions();

  @override
  Widget build(BuildContext context) {
    const options = <(IconData, String, String)>[
      (
        Icons.mic_none_rounded,
        'Push-to-talk',
        'Speak while you hold the microphone button.',
      ),
      (
        Icons.graphic_eq_rounded,
        'Conversation',
        'Keep listening for a short, hands-free exchange.',
      ),
      (
        Icons.record_voice_over_outlined,
        'Custom hotword',
        'Requires additional device support.',
      ),
      (
        Icons.privacy_tip_outlined,
        'Passive listener',
        'Not enabled to protect battery and privacy.',
      ),
    ];
    return Material(
      color: StudyOsColors.surface,
      borderRadius: BorderRadius.circular(StudyOsRadii.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
        child: Column(
          children: <Widget>[
            for (var index = 0; index < options.length; index++) ...<Widget>[
              _VoiceOption(
                icon: options[index].$1,
                title: options[index].$2,
                body: options[index].$3,
              ),
              if (index < options.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: StudyOsSpacing.xl),
                  child: Divider(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VoiceOption extends StatelessWidget {
  const _VoiceOption({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(StudyOsSpacing.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: StudyOsColors.accent, size: 20),
        const SizedBox(width: StudyOsSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}
