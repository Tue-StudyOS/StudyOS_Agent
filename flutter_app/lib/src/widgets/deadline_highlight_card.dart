import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

/// Renders a `deadline_card` generative-UI component: a single highlighted
/// deadline the model calls out mid-conversation (distinct from the tool-backed
/// `deadline_list`, which lists many rows from `get_deadlines`). Shows the
/// course and due date with an urgency accent, plus an "Add reminder" action
/// that fires a native device reminder when the `due` value parses as a date.
class DeadlineHighlightCard extends StatelessWidget {
  const DeadlineHighlightCard({
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
    final theme = Theme.of(context);
    final course = component.arguments['course']?.toString().trim() ?? '';
    final due = DateTime.tryParse(
      component.arguments['due']?.toString() ?? '',
    )?.toLocal();
    final body = component.body.trim();
    final accent = _urgencyColor(due);

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.assignment_late_outlined,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: StudyOsSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            component.title,
                            style: theme.textTheme.labelLarge,
                          ),
                          if (course.isNotEmpty)
                            Text(
                              course,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: StudyOsColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (due != null || body.isNotEmpty) ...<Widget>[
                  const SizedBox(height: StudyOsSpacing.xs),
                  Text(
                    due != null ? 'Due ${_formatDue(due)}' : body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (onAction != null && due != null) ...<Widget>[
                  const SizedBox(height: StudyOsSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => onAction!(
                        ReminderComponentAction(
                          title: course.isEmpty ? component.title : course,
                          dueAt: due,
                        ),
                      ),
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                      ),
                      label: const Text('Add reminder'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _urgencyColor(DateTime? due) {
    if (due == null) return StudyOsColors.accent;
    final now = DateTime.now();
    if (due.isBefore(now)) return StudyOsColors.warning;
    return due.difference(now).inHours <= 48
        ? StudyOsColors.warning
        : StudyOsColors.accent;
  }

  static String _formatDue(DateTime due) {
    const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hh = due.hour.toString().padLeft(2, '0');
    final mm = due.minute.toString().padLeft(2, '0');
    return '${weekdays[due.weekday - 1]} ${due.day} '
        '${months[due.month - 1]}, $hh:$mm';
  }
}
