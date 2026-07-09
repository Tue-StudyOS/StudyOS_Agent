import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_shell_scope.dart';
import '../assistant_copy.dart';
import '../models.dart';
import '../studyos_theme.dart';

class ShellAppBar extends StatelessWidget {
  const ShellAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppShellScope.of(context);
    final profile = controller.profile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, StudyOsSpacing.lg, 0, 8),
      child: Row(
        children: <Widget>[
          Text(
            'StudyOS',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          _MoreMenu(status: controller.status),
          const SizedBox(width: StudyOsSpacing.sm),
          _AvatarMenu(profile: profile, onLogout: controller.onLogout),
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MoreAction>(
      tooltip: 'More',
      onSelected: (action) {
        switch (action) {
          case _MoreAction.notes:
            context.push('/memories');
            break;
          case _MoreAction.map:
            context.push('/maps');
            break;
          case _MoreAction.assistant:
            context.push('/settings');
            break;
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<_MoreAction>>[
        PopupMenuItem<_MoreAction>(
          value: _MoreAction.notes,
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.notes_outlined),
            title: Text('Notes'),
          ),
        ),
        const PopupMenuItem<_MoreAction>(
          value: _MoreAction.map,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.map_outlined),
            title: Text('Map'),
          ),
        ),
        PopupMenuItem<_MoreAction>(
          value: _MoreAction.assistant,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              assistantIsReady(status)
                  ? Icons.auto_awesome_outlined
                  : Icons.error_outline_rounded,
            ),
            title: const Text('Assistant settings'),
          ),
        ),
      ],
      child: const _HeaderIconButton(
        tooltip: 'More',
        icon: Icons.more_horiz_rounded,
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

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.tooltip, required this.icon});

  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: StudyOsColors.surface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 21, color: StudyOsColors.text),
      ),
    );
  }
}

enum _AvatarAction { settings, profile, logout }

enum _MoreAction { notes, map, assistant }
