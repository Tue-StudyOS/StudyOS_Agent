import 'package:flutter/material.dart';

import '../studyos_theme.dart';

class MemoriesView extends StatelessWidget {
  const MemoriesView({required this.worldState, super.key});

  final Map<String, Object?> worldState;

  @override
  Widget build(BuildContext context) {
    final hasWorldState = worldState.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.only(top: StudyOsSpacing.sm),
      children: <Widget>[
        _SectionHeader(
          title: 'Memories',
          description: 'Saved, personalized study context will appear here.',
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        _EmptyStateCard(
          icon: Icons.psychology_alt_outlined,
          title: 'No saved memories yet',
          description:
              'When memory storage is connected, StudyOS can show durable preferences, courses, and study habits here.',
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        _ContextPreviewCard(
          hasWorldState: hasWorldState,
          worldState: worldState,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: StudyOsSpacing.xs),
        Text(description, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(StudyOsSpacing.lg),
      decoration: BoxDecoration(
        color: StudyOsColors.surface,
        border: Border.all(color: StudyOsColors.border),
        borderRadius: BorderRadius.circular(StudyOsRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: StudyOsColors.accent, size: 30),
          const SizedBox(height: StudyOsSpacing.lg),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StudyOsSpacing.sm),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ContextPreviewCard extends StatelessWidget {
  const _ContextPreviewCard({
    required this.hasWorldState,
    required this.worldState,
  });

  final bool hasWorldState;
  final Map<String, Object?> worldState;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(StudyOsSpacing.lg),
      decoration: BoxDecoration(
        color: StudyOsColors.surfaceRaised,
        border: Border.all(color: StudyOsColors.border),
        borderRadius: BorderRadius.circular(StudyOsRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Current context',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StudyOsSpacing.sm),
          Text(
            hasWorldState
                ? 'Live local signals are available for this session.'
                : 'No live local context has been received yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
