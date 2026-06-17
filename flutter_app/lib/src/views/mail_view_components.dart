part of 'mail_view.dart';

class _MailControls extends StatelessWidget {
  const _MailControls({
    required this.mailboxes,
    required this.mailbox,
    required this.unreadOnly,
    required this.onMailboxChanged,
    required this.onUnreadOnlyChanged,
  });

  final List<MailboxSummary> mailboxes;
  final String mailbox;
  final bool unreadOnly;
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
      decoration: _cardDecoration,
      child: Row(
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
          const SizedBox(width: StudyOsSpacing.md),
          FilterChip(
            label: const Text('Unread'),
            selected: unreadOnly,
            onSelected: onUnreadOnlyChanged,
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
    return Container(
      margin: const EdgeInsets.only(bottom: StudyOsSpacing.md),
      decoration: _cardDecoration.copyWith(
        border: Border.all(
          color: selected ? StudyOsColors.accent : StudyOsColors.border,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          message.isUnread ? Icons.mark_email_unread : Icons.mail_outline,
          color: message.isUnread
              ? StudyOsColors.accent
              : StudyOsColors.textMuted,
        ),
        title: Text(
          message.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message.senderLabel),
            if (message.preview != null)
              Text(
                message.preview!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (message.approvalNotice != null)
              const Padding(
                padding: EdgeInsets.only(top: StudyOsSpacing.xs),
                child: _ApprovalBadge(),
              ),
          ],
        ),
        trailing: Text(
          message.receivedAt ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _MailDetailCard extends StatelessWidget {
  const _MailDetailCard({required this.message});

  final MailMessageDetail message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudyOsSpacing.lg),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(message.subject, style: Theme.of(context).textTheme.titleMedium),
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
  border: Border.all(color: StudyOsColors.border),
  borderRadius: BorderRadius.circular(StudyOsRadii.md),
);
