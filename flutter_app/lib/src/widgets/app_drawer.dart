import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.sessions,
    required this.activeSessionId,
    required this.onSelectSession,
    required this.onSelectHome,
    required this.onCreateSession,
    required this.onDeleteSession,
    super.key,
  });

  final List<ChatSession> sessions;
  final String? activeSessionId;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onSelectHome;
  final VoidCallback onCreateSession;
  final ValueChanged<String> onDeleteSession;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: StudyOsColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(StudyOsSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Chats', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: StudyOsSpacing.lg),
              OutlinedButton.icon(
                onPressed: () {
                  onSelectHome();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.home_outlined),
                label: const Text('Back to home'),
              ),
              const SizedBox(height: StudyOsSpacing.sm),
              FilledButton.icon(
                onPressed: () {
                  onCreateSession();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('New chat'),
              ),
              const SizedBox(height: StudyOsSpacing.lg),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    for (final session in sessions)
                      _SessionTile(
                        session: session,
                        selected: session.id == activeSessionId,
                        onTap: () {
                          onSelectSession(session.id);
                          Navigator.of(context).pop();
                        },
                        onDelete: () => _confirmDeleteSession(context, session),
                      ),
                  ],
                ),
              ),
              Text(
                'Active ID: ${_activeShortId()}',
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _activeShortId() {
    for (final session in sessions) {
      if (session.id == activeSessionId) return session.shortId;
    }
    return 'none';
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
    return Padding(
      padding: const EdgeInsets.only(bottom: StudyOsSpacing.sm),
      child: ListTile(
        selected: selected,
        selectedTileColor: StudyOsColors.accent.withValues(alpha: 0.14),
        textColor: StudyOsColors.text,
        iconColor: selected ? StudyOsColors.accent : StudyOsColors.textMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StudyOsRadii.md),
        ),
        leading: const Icon(Icons.forum_outlined),
        title: Text(
          session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          session.shortId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Delete chat',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}
