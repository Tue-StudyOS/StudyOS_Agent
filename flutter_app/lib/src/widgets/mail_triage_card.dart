import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

/// Renders a `mail_list` generative-UI component as an inbox triage card: one
/// row per message with sender/subject/preview and two quick actions. Actions
/// don't mutate mail directly — they submit a follow-up prompt through
/// [onAction] (reusing the normal send path), so the agent stays in the loop
/// and anything side-effecting (like a reply) surfaces as a draft to confirm.
class MailTriageCard extends StatelessWidget {
  const MailTriageCard({
    required this.component,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final GeneratedUiComponent component;

  /// Emits the action a row requested (a prompt to send). Null in read-only
  /// contexts such as the settings preview.
  final ValueChanged<GeneratedComponentAction>? onAction;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mailbox = component.arguments['mailbox']?.toString() ?? 'INBOX';
    final messages = _messages(component.arguments['messages']);
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
                      Icons.mail_outline_rounded,
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
                const SizedBox(height: StudyOsSpacing.xs),
                Text(
                  component.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: StudyOsColors.textMuted,
                  ),
                ),
                const SizedBox(height: StudyOsSpacing.sm),
                for (var i = 0; i < messages.length; i++) ...<Widget>[
                  if (i > 0)
                    const Divider(height: 1, color: StudyOsColors.border),
                  _MailRow(
                    message: messages[i],
                    mailbox: mailbox,
                    onAction: onAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<Map<String, Object?>> _messages(Object? raw) {
    if (raw is! List) return const <Map<String, Object?>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }
}

class _MailRow extends StatelessWidget {
  const _MailRow({
    required this.message,
    required this.mailbox,
    required this.onAction,
  });

  final Map<String, Object?> message;
  final String mailbox;
  final ValueChanged<GeneratedComponentAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = message['subject']?.toString() ?? '(no subject)';
    final sender = message['sender']?.toString() ?? 'Unknown sender';
    final preview = message['preview']?.toString().trim() ?? '';
    final isUnread = message['is_unread'] == true;
    final isBroadcast = message['is_approved_broadcast'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: StudyOsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 6, right: StudyOsSpacing.sm),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isUnread
                        ? StudyOsColors.accent
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isUnread
                        ? null
                        : Border.all(color: StudyOsColors.border),
                  ),
                  child: const SizedBox.square(dimension: 8),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: StudyOsColors.text,
                            ),
                          ),
                        ),
                        if (isBroadcast) const _BroadcastBadge(),
                      ],
                    ),
                    Text(
                      subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: StudyOsColors.text,
                      ),
                    ),
                    if (preview.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          preview,
                          maxLines: 1,
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
          if (onAction != null)
            Padding(
              padding: const EdgeInsets.only(top: StudyOsSpacing.xs, left: 16),
              child: Wrap(
                spacing: StudyOsSpacing.sm,
                children: <Widget>[
                  _MailAction(
                    icon: Icons.summarize_outlined,
                    label: 'Summarize',
                    onPressed: () => onAction!(
                      PromptComponentAction(_summarizePrompt(sender, subject)),
                    ),
                  ),
                  _MailAction(
                    icon: Icons.reply_outlined,
                    label: 'Draft reply',
                    onPressed: () => onAction!(
                      PromptComponentAction(_replyPrompt(sender, subject)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String get _uidRef {
    final uid = message['uid']?.toString();
    return uid == null ? '' : ' (mail uid $uid in $mailbox)';
  }

  String _summarizePrompt(String sender, String subject) {
    return 'Summarize the email "$subject" from $sender$_uidRef. '
        'Open the full message if you need the details.';
  }

  String _replyPrompt(String sender, String subject) {
    return 'Draft a reply to the email "$subject" from $sender$_uidRef. '
        'Show me the draft only — do not send anything.';
  }
}

class _BroadcastBadge extends StatelessWidget {
  const _BroadcastBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: StudyOsSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: StudyOsColors.success.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(StudyOsRadii.sm),
      ),
      child: Text(
        'Official',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: StudyOsColors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MailAction extends StatelessWidget {
  const _MailAction({
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
