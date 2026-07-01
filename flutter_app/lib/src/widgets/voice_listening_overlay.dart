import 'package:flutter/material.dart';

import '../studyos_theme.dart';
import '../voice_controller.dart';

/// A panel shown above the composer while voice input/output is active. Renders
/// a live amplitude bar, the interim transcript, and a cancel control. Hidden
/// when voice is idle or unavailable.
class VoiceListeningOverlay extends StatelessWidget {
  const VoiceListeningOverlay({required this.voice, super.key});

  final VoiceController voice;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) {
        final state = voice.state;
        final visible =
            state == VoiceState.listening ||
            state == VoiceState.processing ||
            state == VoiceState.speaking;
        if (!visible) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: StudyOsSpacing.sm),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: StudyOsColors.surfaceRaised,
              border: Border.all(color: StudyOsColors.border),
              borderRadius: BorderRadius.circular(StudyOsRadii.md),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                StudyOsSpacing.md,
                StudyOsSpacing.sm,
                StudyOsSpacing.sm,
                StudyOsSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  _StateGlyph(state: state, level: voice.soundLevel),
                  const SizedBox(width: StudyOsSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _label(state, voice.conversationMode),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: StudyOsColors.accent),
                        ),
                        if (voice.transcript.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              voice.transcript,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Stop',
                    onPressed: voice.stopConversation,
                    icon: const Icon(Icons.close_rounded),
                    color: StudyOsColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _label(VoiceState state, bool conversationMode) {
    switch (state) {
      case VoiceState.processing:
        return 'Thinking...';
      case VoiceState.speaking:
        return 'Speaking...';
      case VoiceState.listening:
        return conversationMode ? 'Listening (conversation)' : 'Listening...';
      case VoiceState.idle:
      case VoiceState.unavailable:
        return '';
    }
  }
}

/// A small leading indicator: an animated amplitude bar while listening, a
/// spinner while processing, and a speaker glyph while speaking.
class _StateGlyph extends StatelessWidget {
  const _StateGlyph({required this.state, required this.level});

  final VoiceState state;
  final double level;

  @override
  Widget build(BuildContext context) {
    if (state == VoiceState.processing) {
      return const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: StudyOsColors.accent,
        ),
      );
    }
    if (state == VoiceState.speaking) {
      return const Icon(
        Icons.volume_up_rounded,
        color: StudyOsColors.accent,
        size: 22,
      );
    }
    return _AmplitudeBars(level: level);
  }
}

/// Five bars whose heights scale with the smoothed microphone level.
class _AmplitudeBars extends StatelessWidget {
  const _AmplitudeBars({required this.level});

  final double level;

  // speech_to_text reports roughly -2..10 on Android; normalize to 0..1.
  double get _normalized => ((level + 2) / 12).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    const factors = <double>[0.45, 0.75, 1.0, 0.7, 0.5];
    final amp = _normalized;
    return SizedBox(
      width: 26,
      height: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          for (final factor in factors)
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 3,
              height: 4 + (18 * amp * factor),
              decoration: BoxDecoration(
                color: StudyOsColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
