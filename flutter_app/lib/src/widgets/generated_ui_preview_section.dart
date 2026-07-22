import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';
import 'deadline_card.dart';
import 'mail_triage_card.dart';

class GeneratedUiPreviewSection extends StatefulWidget {
  const GeneratedUiPreviewSection({super.key});

  @override
  State<GeneratedUiPreviewSection> createState() =>
      _GeneratedUiPreviewSectionState();
}

class _GeneratedUiPreviewSectionState extends State<GeneratedUiPreviewSection> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final validations = generativeUiFixturePayloads
        .map(GenerativeUiRegistry.validate)
        .toList(growable: false);
    final validation = validations[_selectedIndex % validations.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Generated component preview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Previous component',
              onPressed: () => _select(_selectedIndex - 1, validations.length),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Next component',
              onPressed: () => _select(_selectedIndex + 1, validations.length),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: StudyOsSpacing.sm),
        if (validation.component case final component?)
          switch (component.kind) {
            GeneratedComponentKind.mailList => MailTriageCard(
              component: component,
            ),
            GeneratedComponentKind.deadlineList => DeadlineCard(
              component: component,
            ),
            _ => _GeneratedComponentCard(component: component),
          }
        else
          _InvalidComponentCard(errors: validation.errors),
      ],
    );
  }

  void _select(int index, int length) {
    setState(() => _selectedIndex = (index + length) % length);
  }
}

class _GeneratedComponentCard extends StatelessWidget {
  const _GeneratedComponentCard({required this.component});

  final GeneratedUiComponent component;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudyOsColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: StudyOsColors.border),
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(_iconFor(component.kind), color: StudyOsColors.accent),
            const SizedBox(width: StudyOsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    component.title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: StudyOsSpacing.xs),
                  Text(
                    component.body,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: StudyOsSpacing.sm),
                  Text(
                    component.kind.wireName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: StudyOsColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(GeneratedComponentKind kind) {
    return switch (kind) {
      GeneratedComponentKind.nextAction => Icons.arrow_forward_rounded,
      GeneratedComponentKind.scheduleSummary => Icons.calendar_month_outlined,
      GeneratedComponentKind.routeHint => Icons.map_outlined,
      GeneratedComponentKind.deadlineCard => Icons.assignment_late_outlined,
      GeneratedComponentKind.quickReply => Icons.quickreply_outlined,
      GeneratedComponentKind.mailList => Icons.mail_outline_rounded,
      GeneratedComponentKind.deadlineList => Icons.assignment_late_outlined,
    };
  }
}

class _InvalidComponentCard extends StatelessWidget {
  const _InvalidComponentCard({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudyOsColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: StudyOsColors.warning),
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.lg),
        child: Text(
          errors.join('\n'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
