import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.selectedView,
    required this.sessions,
    required this.activeSessionId,
    required this.onSelectView,
    required this.onSelectSession,
    required this.onCreateSession,
    required this.onDeleteSession,
    super.key,
  });

  final AppView selectedView;
  final List<ChatSession> sessions;
  final String? activeSessionId;
  final ValueChanged<AppView> onSelectView;
  final ValueChanged<String> onSelectSession;
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
              Text(
                'StudyOS Agent',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: StudyOsSpacing.xs),
              Text(
                'Study companion',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: StudyOsSpacing.xl),
              Row(
                children: <Widget>[
                  _ViewIconButton(
                    tooltip: 'Chat',
                    icon: Icons.chat_bubble_outline_rounded,
                    selected: selectedView == AppView.chat,
                    onTap: () => _select(context, AppView.chat),
                  ),
                  const SizedBox(width: StudyOsSpacing.sm),
                  _ViewIconButton(
                    tooltip: 'Memories',
                    icon: Icons.psychology_alt_outlined,
                    selected: selectedView == AppView.memories,
                    onTap: () => _select(context, AppView.memories),
                  ),
                  const SizedBox(width: StudyOsSpacing.sm),
                  _ViewIconButton(
                    tooltip: 'Settings',
                    icon: Icons.settings_outlined,
                    selected: selectedView == AppView.settings,
                    onTap: () => _select(context, AppView.settings),
                  ),
                ],
              ),
              const SizedBox(height: StudyOsSpacing.xl),
              FilledButton.icon(
                onPressed: () {
                  onCreateSession();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('New chat'),
              ),
              const SizedBox(height: StudyOsSpacing.lg),
              Text('Chats', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: StudyOsSpacing.sm),
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

  void _select(BuildContext context, AppView view) {
    onSelectView(view);
    Navigator.of(context).pop();
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

class _ViewIconButton extends StatelessWidget {
  const _ViewIconButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected
              ? StudyOsColors.accent.withValues(alpha: 0.18)
              : StudyOsColors.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: selected ? StudyOsColors.accent : StudyOsColors.border,
            ),
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
            onTap: onTap,
            child: SizedBox(
              height: 48,
              child: Icon(
                icon,
                color: selected
                    ? StudyOsColors.accent
                    : StudyOsColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
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
