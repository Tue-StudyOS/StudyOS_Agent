import 'package:flutter/material.dart';

import '../studyos_theme.dart';

class StudyHeader extends StatelessWidget {
  const StudyHeader({required this.status, this.onCreateSession, super.key});

  final String status;
  final VoidCallback? onCreateSession;

  bool get _isReady {
    final lower = status.toLowerCase();
    return lower.contains('ready') || lower.contains('initialized');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, StudyOsSpacing.lg, 0, 10),
      child: Row(
        children: <Widget>[
          Builder(
            builder: (context) {
              return _HeaderIconButton(
                tooltip: 'Open study context',
                icon: Icons.menu_rounded,
                onPressed: Scaffold.of(context).openDrawer,
              );
            },
          ),
          const Spacer(),
          const SizedBox(width: StudyOsSpacing.md),
          if (onCreateSession == null)
            _StatusChip(label: _isReady ? 'Ready' : status, isReady: _isReady)
          else
            _HeaderIconButton(
              tooltip: 'New chat',
              icon: Icons.add_comment_outlined,
              onPressed: onCreateSession!,
            ),
        ],
      ),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.isReady});

  final String label;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final color = isReady ? StudyOsColors.success : StudyOsColors.warning;

    return Semantics(
      label: 'Native bridge status: $label',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.32)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: color, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
