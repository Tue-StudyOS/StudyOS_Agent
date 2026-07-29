part of 'mail_view.dart';

class _MailControls extends StatelessWidget {
  const _MailControls({
    required this.mailboxes,
    required this.mailbox,
    required this.unreadOnly,
    required this.queryController,
    required this.onQueryChanged,
    required this.onQuerySubmitted,
    required this.onClearQuery,
    required this.onMailboxChanged,
    required this.onUnreadOnlyChanged,
  });

  final List<MailboxSummary> mailboxes;
  final String mailbox;
  final bool unreadOnly;
  final TextEditingController queryController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onQuerySubmitted;
  final VoidCallback onClearQuery;
  final ValueChanged<String> onMailboxChanged;
  final ValueChanged<bool> onUnreadOnlyChanged;

  @override
  Widget build(BuildContext context) {
    final options = mailboxes.isEmpty
        ? const <MailboxSummary>[
            MailboxSummary(
              name: 'INBOX',
              label: 'Inbox',
              specialUse: 'inbox',
              messageCount: null,
              unreadCount: null,
            ),
          ]
        : mailboxes;
    return Container(
      padding: const EdgeInsets.all(StudyOsSpacing.md),
      decoration: BoxDecoration(
        color: StudyOsColors.surface,
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
      ),
      child: Column(
        children: <Widget>[
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: queryController,
            builder: (context, value, _) {
              return TextField(
                controller: queryController,
                textInputAction: TextInputAction.search,
                onChanged: onQueryChanged,
                onSubmitted: onQuerySubmitted,
                decoration: InputDecoration(
                  labelText: 'Search mail',
                  hintText: 'Subject, sender, or keyword',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: onClearQuery,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: StudyOsSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: mailbox,
                  decoration: const InputDecoration(labelText: 'Mailbox'),
                  items: options
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.name,
                          child: Text(
                            item.unreadCount == null || item.unreadCount == 0
                                ? item.label
                                : '${item.label} (${item.unreadCount})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onMailboxChanged(value);
                  },
                ),
              ),
              const SizedBox(width: StudyOsSpacing.sm),
              IconButton(
                tooltip: unreadOnly ? 'Show all messages' : 'Show unread only',
                onPressed: () => onUnreadOnlyChanged(!unreadOnly),
                icon: Icon(
                  unreadOnly
                      ? Icons.mark_email_unread_rounded
                      : Icons.mark_email_read_outlined,
                  color: unreadOnly
                      ? StudyOsColors.accent
                      : StudyOsColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MailSummaryCard extends StatelessWidget {
  const _MailSummaryCard({
    required this.message,
    required this.selected,
    required this.onTap,
  });

  final MailMessageSummary message;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? StudyOsColors.accent.withValues(alpha: 0.08)
          : StudyOsColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: StudyOsSpacing.md,
            vertical: StudyOsSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                message.isUnread ? Icons.mark_email_unread : Icons.mail_outline,
                color: message.isUnread
                    ? StudyOsColors.accent
                    : StudyOsColors.textMuted,
              ),
              const SizedBox(width: StudyOsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      message.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: StudyOsSpacing.xs),
                    Text(
                      message.senderLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (message.preview != null)
                      Text(
                        message.preview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    if (message.approvalNotice != null)
                      const Padding(
                        padding: EdgeInsets.only(top: StudyOsSpacing.xs),
                        child: _ApprovalBadge(),
                      ),
                  ],
                ),
              ),
              if (message.receivedAt?.isNotEmpty == true) ...<Widget>[
                const SizedBox(width: StudyOsSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 72),
                  child: Text(
                    message.receivedAt!,
                    maxLines: 2,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: StudyOsColors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MailDetailCard extends StatelessWidget {
  const _MailDetailCard({required this.message, required this.onClose});

  final MailMessageDetail message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: StudyOsSpacing.md),
      width: double.infinity,
      padding: const EdgeInsets.all(StudyOsSpacing.lg),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  message.subject,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Close message',
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: StudyOsSpacing.xs),
          Text(
            '${message.senderLabel} · ${message.receivedAt ?? 'Unknown date'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (message.approvalNotice != null) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.sm),
            const _ApprovalBadge(showMessage: true),
          ],
          const SizedBox(height: StudyOsSpacing.md),
          Text(message.bodyText ?? 'No readable plaintext body found.'),
          if (message.attachmentNames.isNotEmpty) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.md),
            Text(
              'Attachments: ${message.attachmentNames.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({this.showMessage = false});

  final bool showMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.verified_rounded, size: 16, color: Colors.green),
        const SizedBox(width: StudyOsSpacing.xs),
        Flexible(
          child: Text(
            showMessage
                ? approvedBroadcastNotice.message
                : approvedBroadcastNotice.title,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

class _MailMessageCard extends StatelessWidget {
  const _MailMessageCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudyOsSpacing.lg),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: StudyOsColors.textMuted),
          const SizedBox(height: StudyOsSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StudyOsSpacing.xs),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

final _cardDecoration = BoxDecoration(
  color: StudyOsColors.surface,
  borderRadius: BorderRadius.circular(StudyOsRadii.md),
);
