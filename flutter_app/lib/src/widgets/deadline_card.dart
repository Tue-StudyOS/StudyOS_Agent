import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

/// Renders a `deadline_list` generative-UI component: one row per upcoming
/// deadline with course, due date, and urgency accent. Two actions per row —
/// "Add reminder" fires a native device reminder (a side effect, but always
/// user-initiated), and "Plan block" asks the agent to schedule study time.
/// Both flow through the single [GeneratedComponentAction] callback.
class DeadlineCard extends StatelessWidget {
  const DeadlineCard({
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
    final deadlines = _deadlines(component.arguments['deadlines']);
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
                      Icons.assignment_late_outlined,
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
                for (var i = 0; i < deadlines.length; i++) ...<Widget>[
                  if (i > 0)
                    const Divider(height: 1, color: StudyOsColors.border),
                  _DeadlineRow(deadline: deadlines[i], onAction: onAction),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<Map<String, Object?>> _deadlines(Object? raw) {
    if (raw is! List) return const <Map<String, Object?>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }
}

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({required this.deadline, required this.onAction});

  final Map<String, Object?> deadline;
  final ValueChanged<GeneratedComponentAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = deadline['title']?.toString() ?? 'Deadline';
    final course = deadline['course']?.toString().trim() ?? '';
    final requirement = deadline['requirement']?.toString().trim() ?? '';
    final due = DateTime.tryParse(deadline['due_at']?.toString() ?? '')
        ?.toLocal();
    final urgency = _urgencyFor(due);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: StudyOsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 5, right: StudyOsSpacing.sm),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: urgency.color,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 8),
                ),
              ),
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
                    if (course.isNotEmpty)
                      Text(
                        course,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: StudyOsColors.textMuted,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _dueLabel(due, urgency, requirement),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: urgency.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onAction != null && due != null)
            Padding(
              padding: const EdgeInsets.only(top: StudyOsSpacing.xs, left: 16),
              child: Wrap(
                spacing: StudyOsSpacing.sm,
                children: <Widget>[
                  _DeadlineAction(
                    icon: Icons.notifications_active_outlined,
                    label: 'Add reminder',
                    onPressed: () => onAction!(
                      ReminderComponentAction(title: title, dueAt: due),
                    ),
                  ),
                  _DeadlineAction(
                    icon: Icons.event_note_outlined,
                    label: 'Plan block',
                    onPressed: () => onAction!(
                      PromptComponentAction(_planPrompt(title, course, due)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _planPrompt(String title, String course, DateTime due) {
    final courseRef = course.isEmpty ? '' : ' for $course';
    return 'Plan a focused study block$courseRef ahead of the deadline '
        '"$title" (due ${due.toIso8601String()}). Suggest a specific time '
        'that fits around my schedule.';
  }

  String _dueLabel(DateTime? due, _Urgency urgency, String requirement) {
    if (due == null) return requirement.isEmpty ? 'No due date' : requirement;
    final suffix = requirement.isEmpty ? '' : ' · $requirement';
    return 'Due ${_formatDue(due)} (${urgency.label})$suffix';
  }

  static String _formatDue(DateTime due) {
    const weekdays = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
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

  static _Urgency _urgencyFor(DateTime? due) {
    if (due == null) return const _Urgency(StudyOsColors.textMuted, 'no date');
    final now = DateTime.now();
    if (due.isBefore(now)) return const _Urgency(StudyOsColors.warning, 'overdue');
    final hours = due.difference(now).inHours;
    if (hours <= 48) {
      return const _Urgency(StudyOsColors.warning, 'soon');
    }
    final days = due.difference(now).inDays;
    return _Urgency(StudyOsColors.accent, 'in $days days');
  }
}

class _Urgency {
  const _Urgency(this.color, this.label);

  final Color color;
  final String label;
}

class _DeadlineAction extends StatelessWidget {
  const _DeadlineAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: StudyOsColors.accent,
        padding: const EdgeInsets.symmetric(
          horizontal: StudyOsSpacing.sm,
          vertical: 2,
        ),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}
