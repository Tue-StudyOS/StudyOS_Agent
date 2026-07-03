import 'package:flutter/material.dart';

import '../studyos_theme.dart';
import '../voice_controller.dart';

class ComposerBar extends StatelessWidget {
  const ComposerBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    this.onStop,
    this.voice,
    super.key,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  /// Invoked when the user taps Stop while a reply is in flight.
  final VoidCallback? onStop;

  /// Optional voice controller. When present and available, a mic button is
  /// shown next to send (hold to dictate, tap for hands-free conversation).
  final VoiceController? voice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StudyOsColors.surface,
          border: Border.all(color: StudyOsColors.border),
          borderRadius: BorderRadius.circular(StudyOsRadii.lg),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 22,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(StudyOsSpacing.md, 6, 6, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Message StudyOS...',
                    hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: StudyOsColors.textMuted,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: StudyOsSpacing.sm),
              if (voice != null) _MicArea(voice: voice!),
              SizedBox.square(
                dimension: 46,
                child: FilledButton(
                  onPressed: isSending ? onStop : onSend,
                  style: FilledButton.styleFrom(
                    backgroundColor: StudyOsColors.accent,
                    foregroundColor: const Color(0xFF06101F),
                    disabledBackgroundColor: StudyOsColors.border,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(StudyOsRadii.md),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: isSending
                      ? Semantics(
                          button: true,
                          label: 'Stop generating',
                          child: const Icon(Icons.stop_rounded),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reactively shows the mic button only while voice is available, and a
/// trailing gap so it sits left of the send button.
class _MicArea extends StatelessWidget {
  const _MicArea({required this.voice});

  final VoiceController voice;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) {
        if (!voice.available) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: StudyOsSpacing.sm),
          child: _MicButton(voice: voice),
        );
      },
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.voice});

  final VoiceController voice;

  @override
  Widget build(BuildContext context) {
    final state = voice.state;
    final active =
        state == VoiceState.listening ||
        state == VoiceState.speaking ||
        voice.conversationMode;
    final IconData icon;
    if (state == VoiceState.listening) {
      icon = Icons.mic_rounded;
    } else if (voice.conversationMode) {
      icon = Icons.graphic_eq_rounded;
    } else {
      icon = Icons.mic_none_rounded;
    }
    return GestureDetector(
      onTap: voice.toggleConversation,
      onLongPressStart: (_) => voice.startHold(),
      onLongPressEnd: (_) => voice.stopHold(),
      child: Semantics(
        button: true,
        label: 'Voice input. Tap for conversation mode, hold to dictate.',
        child: SizedBox.square(
          dimension: 46,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active
                  ? StudyOsColors.accent
                  : StudyOsColors.surfaceRaised,
              borderRadius: BorderRadius.circular(StudyOsRadii.md),
              border: Border.all(color: StudyOsColors.border),
            ),
            child: Icon(
              icon,
              color: active ? const Color(0xFF06101F) : StudyOsColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
