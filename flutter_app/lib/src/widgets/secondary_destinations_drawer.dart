import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../studyos_theme.dart';

class SecondaryDestinationsDrawer extends StatelessWidget {
  const SecondaryDestinationsDrawer({super.key});

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
              Text('StudyOS', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: StudyOsSpacing.lg),
              _DrawerDestination(
                icon: Icons.psychology_alt_outlined,
                label: 'Notes',
                path: '/memories',
              ),
              _DrawerDestination(
                icon: Icons.map_outlined,
                label: 'Map',
                path: '/maps',
              ),
              const Spacer(),
              const Divider(color: StudyOsColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline_rounded),
                title: const Text('About StudyOS'),
                subtitle: const Text('Course assistant shell'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'StudyOS',
                  applicationVersion: 'Flutter shell',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerDestination extends StatelessWidget {
  const _DrawerDestination({
    required this.icon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop();
        context.push(path);
      },
    );
  }
}
