import 'package:flutter/material.dart';

import '../assistant_copy.dart';
import '../models.dart';
import '../studyos_theme.dart';
import 'settings_card.dart';

class AssistantStatusCard extends StatelessWidget {
  const AssistantStatusCard({
    required this.status,
    required this.config,
    super.key,
  });

  final String status;
  final AgentConfig config;

  @override
  Widget build(BuildContext context) {
    final ready = assistantIsReady(status);
    final color = ready ? StudyOsColors.success : StudyOsColors.warning;
    return SettingsCard(
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.auto_awesome_outlined, color: color),
          title: const Text('Assistant'),
          subtitle: Text(
            '${assistantStatusLabel(status)} · ${assistantSetupLabel(config)}',
          ),
        ),
      ],
    );
  }
}
