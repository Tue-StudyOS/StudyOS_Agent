import 'package:flutter/material.dart';

import '../studyos_theme.dart';

class StudyBottomBar extends StatelessWidget {
  const StudyBottomBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: StudyOsColors.surface,
      child: SizedBox(
        height: 72,
        child: Row(
          children: <Widget>[
            _BarItem(
              selected: selectedIndex == 0,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
              onTap: () => onDestinationSelected(0),
            ),
            _BarItem(
              selected: selectedIndex == 1,
              icon: Icons.calendar_month_outlined,
              selectedIcon: Icons.calendar_month_rounded,
              label: 'Schedule',
              onTap: () => onDestinationSelected(1),
            ),
            const SizedBox(width: 76),
            _BarItem(
              selected: selectedIndex == 2,
              icon: Icons.mail_outline_rounded,
              selectedIcon: Icons.mail_rounded,
              label: 'Mail',
              onTap: () => onDestinationSelected(2),
            ),
            _BarItem(
              selected: selectedIndex == 3,
              icon: Icons.restaurant_outlined,
              selectedIcon: Icons.restaurant_rounded,
              label: 'Campus',
              onTap: () => onDestinationSelected(3),
            ),
          ],
        ),
      ),
    );
  }
}

class AskFab extends StatelessWidget {
  const AskFab({required this.onPressed, required this.onLongPress, super.key});

  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      tooltip: 'Ask StudyOS',
      onPressed: onPressed,
      onLongPress: onLongPress,
      icon: const Icon(Icons.auto_awesome),
      label: const Text('Ask'),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? StudyOsColors.accent : StudyOsColors.textMuted;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(selected ? selectedIcon : icon, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
