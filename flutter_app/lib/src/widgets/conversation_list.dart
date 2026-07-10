import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

class ConversationList extends StatelessWidget {
  const ConversationList({
    required this.sessions,
    required this.activeSessionId,
    required this.onSelectSession,
    required this.onCreateSession,
    required this.onDeleteSession,
    super.key,
  });

  final List<ChatSession> sessions;
  final String? activeSessionId;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onCreateSession;
  final ValueChanged<String> onDeleteSession;

  @override
  Widget build(BuildContext context) {
    final visibleSessions = sessions
        .where((session) => session.hasTurns)
        .toList(growable: false);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Conversations',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    onCreateSession();
                    Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New'),
                ),
              ],
            ),
            const SizedBox(height: StudyOsSpacing.xxl),
            Expanded(
              child: Material(
                color: StudyOsColors.surface,
                borderRadius: BorderRadius.circular(StudyOsRadii.md),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(StudyOsRadii.md),
                  child: ListView(
                    children: <Widget>[
                      for (
                        var index = 0;
                        index < visibleSessions.length;
                        index++
                      ) ...<Widget>[
                        _SessionTile(
                          session: visibleSessions.elementAt(index),
                          selected:
                              visibleSessions.elementAt(index).id ==
                              activeSessionId,
                          onTap: () {
                            onSelectSession(
                              visibleSessions.elementAt(index).id,
                            );
                            Navigator.of(context).maybePop();
                          },
                          onDelete: () => _confirmDeleteSession(
                            context,
                            visibleSessions.elementAt(index),
                          ),
                        ),
                        if (index < visibleSessions.length - 1)
                          const Padding(
                            padding: EdgeInsets.only(left: StudyOsSpacing.xl),
                            child: Divider(),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: StudyOsSpacing.md),
            Text(
              'Chats are stored on this device.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSession(
    BuildContext context,
    ChatSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text('Delete "${session.title}" from this device?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDeleteSession(session.id);
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final ChatSession session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: StudyOsColors.accent.withValues(alpha: 0.14),
      textColor: StudyOsColors.text,
      iconColor: selected ? StudyOsColors.accent : StudyOsColors.textMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
      ),
      leading: const Icon(Icons.forum_outlined),
      title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: const Text(
        'Saved conversation',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Delete chat',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}
