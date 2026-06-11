import 'package:flutter/material.dart';

import '../studyos_theme.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({
    required this.status,
    required this.compactMessages,
    required this.onCompactMessagesChanged,
    super.key,
  });

  final String status;
  final bool compactMessages;
  final ValueChanged<bool> onCompactMessagesChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: StudyOsSpacing.sm),
      children: <Widget>[
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: StudyOsSpacing.xs),
        Text(
          'Profile, session, and app-wide preferences.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        _SettingsCard(
          children: <Widget>[
            _ProfileRow(),
            const Divider(color: StudyOsColors.border),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Logout'),
              subtitle: const Text('No active profile session'),
              enabled: false,
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        _SettingsCard(
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Compact message layout'),
              subtitle: const Text(
                'Use tighter chat spacing on small screens.',
              ),
              value: compactMessages,
              onChanged: onCompactMessagesChanged,
            ),
          ],
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        _SettingsCard(
          children: <Widget>[
            Text(
              'Device bridge',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: StudyOsSpacing.sm),
            Text(status, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudyOsColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: StudyOsColors.border),
        borderRadius: BorderRadius.circular(StudyOsRadii.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.lg),
        child: Column(children: children),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: StudyOsColors.accent.withValues(alpha: 0.14),
        child: const Icon(Icons.person_outline_rounded),
      ),
      title: const Text('Profile not connected'),
      subtitle: const Text('Sign-in data is not available in this shell yet.'),
    );
  }
}
