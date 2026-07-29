import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

/// Renders a `talk_list` generative-UI component: upcoming Tübingen talks with a
/// date chip, speaker, and location. "Remind me" fires a native reminder ahead
/// of the talk through the shared [GeneratedComponentAction] seam.
class TalkCard extends StatelessWidget {
  const TalkCard({
    required this.component,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final GeneratedUiComponent component;
  final ValueChanged<GeneratedComponentAction>? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final talks = _talks(component.arguments['talks']);
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: EdgeInsets.symmetric(vertical: compact ? 5 : 8),
        child: Material(
          color: StudyOsColors.surface,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: StudyOsColors.border),
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(StudyOsSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.forum_outlined,
                      size: 18,
                      color: StudyOsColors.accent,
                    ),
                    const SizedBox(width: StudyOsSpacing.sm),
                    Expanded(
                      child: Text(
                        component.title,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: StudyOsSpacing.sm),
                for (var i = 0; i < talks.length; i++) ...<Widget>[
                  if (i > 0)
                    const Divider(height: 1, color: StudyOsColors.border),
                  _TalkRow(talk: talks[i], onAction: onAction),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<Map<String, Object?>> _talks(Object? raw) {
    if (raw is! List) return const <Map<String, Object?>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }
}

class _TalkRow extends StatelessWidget {
  const _TalkRow({required this.talk, required this.onAction});

  final Map<String, Object?> talk;
  final ValueChanged<GeneratedComponentAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = talk['title']?.toString() ?? 'Talk';
    final speaker = talk['speaker']?.toString().trim() ?? '';
    final location = talk['location']?.toString().trim() ?? '';
    final start = DateTime.tryParse(
      talk['timestamp']?.toString() ?? '',
    )?.toLocal();
    final meta = <String>[
      if (speaker.isNotEmpty) speaker,
      if (location.isNotEmpty) location,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: StudyOsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _DateChip(start: start),
              const SizedBox(width: StudyOsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: StudyOsColors.text,
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          meta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: StudyOsColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (onAction != null && start != null)
            Padding(
              padding: const EdgeInsets.only(top: StudyOsSpacing.xs, left: 52),
              child: TextButton.icon(
                onPressed: () => onAction!(
                  ReminderComponentAction(title: title, dueAt: start),
                ),
                icon: const Icon(Icons.notifications_active_outlined, size: 16),
                label: const Text('Remind me'),
                style: TextButton.styleFrom(
                  foregroundColor: StudyOsColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: StudyOsSpacing.sm,
                    vertical: 2,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.labelLarge,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.start});

  final DateTime? start;

  static const _months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final start = this.start;
    final theme = Theme.of(context);
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: StudyOsColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(StudyOsRadii.sm),
        border: Border.all(color: StudyOsColors.border),
      ),
      child: Column(
        children: <Widget>[
          Text(
            start == null ? '—' : start.day.toString(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: StudyOsColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            start == null ? '' : _months[start.month - 1],
            style: theme.textTheme.labelSmall?.copyWith(
              color: StudyOsColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
