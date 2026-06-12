import 'package:flutter/material.dart';

import '../studyos_theme.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({required this.children, super.key});

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
