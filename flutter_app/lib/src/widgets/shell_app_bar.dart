import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_shell_scope.dart';
import '../assistant_copy.dart';
import '../models.dart';
import '../studyos_theme.dart';

class ShellAppBar extends StatelessWidget {
  const ShellAppBar({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final controller = AppShellScope.of(context);
    final profile = controller.profile;
    final isReady = assistantIsReady(controller.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, StudyOsSpacing.lg, 0, 10),
      child: Row(
        children: <Widget>[
          _HeaderIconButton(
            tooltip: 'Open menu',
            icon: Icons.menu_rounded,
            onPressed: Scaffold.of(context).openDrawer,
          ),
          const SizedBox(width: StudyOsSpacing.md),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          _StatusDot(
            isReady: isReady,
            label: assistantStatusLabel(controller.status),
          ),
          const SizedBox(width: StudyOsSpacing.sm),
          _AvatarMenu(profile: profile, onLogout: controller.onLogout),
        ],
      ),
    );
  }
}

class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({required this.profile, required this.onLogout});

  final OnboardingProfile? profile;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(profile?.displayName ?? 'StudyOS');
    return PopupMenuButton<_AvatarAction>(
      tooltip: 'Account',
      onSelected: (action) {
        switch (action) {
          case _AvatarAction.settings:
            context.push('/settings');
            break;
          case _AvatarAction.profile:
            context.push('/settings/profile');
            break;
          case _AvatarAction.logout:
            onLogout?.call();
            break;
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<_AvatarAction>>[
        const PopupMenuItem<_AvatarAction>(
          value: _AvatarAction.settings,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
          ),
        ),
        const PopupMenuItem<_AvatarAction>(
          value: _AvatarAction.profile,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_outline_rounded),
            title: Text('Edit profile'),
          ),
        ),
        PopupMenuItem<_AvatarAction>(
          value: _AvatarAction.logout,
          enabled: onLogout != null,
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded),
            title: Text('Log out'),
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 22,
        backgroundColor: StudyOsColors.accent,
        foregroundColor: Colors.white,
        child: Text(initials),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'S';
    return parts
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isReady, required this.label});

  final bool isReady;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = isReady ? StudyOsColors.success : StudyOsColors.warning;
    return Tooltip(
      message: label,
      child: Icon(Icons.circle, size: 10, color: color),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: IconButton(
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: StudyOsColors.surface,
          foregroundColor: StudyOsColors.text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
            side: const BorderSide(color: StudyOsColors.border),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

enum _AvatarAction { settings, profile, logout }
