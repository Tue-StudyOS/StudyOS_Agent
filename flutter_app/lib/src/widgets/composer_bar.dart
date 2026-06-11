import 'package:flutter/material.dart';

import '../studyos_theme.dart';

class ComposerBar extends StatelessWidget {
  const ComposerBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    super.key,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

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
                    hintText: 'Nachricht an Jarvis...',
                    hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: StudyOsColors.textMuted,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: StudyOsSpacing.sm),
              SizedBox.square(
                dimension: 46,
                child: FilledButton(
                  onPressed: isSending ? null : onSend,
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
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
