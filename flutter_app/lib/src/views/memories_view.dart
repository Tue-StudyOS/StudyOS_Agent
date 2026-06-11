import 'package:flutter/material.dart';

import '../studyos_theme.dart';

class MemoriesView extends StatelessWidget {
  const MemoriesView({
    required this.worldState,
    required this.memoryText,
    super.key,
  });

  final Map<String, Object?> worldState;
  final String memoryText;

  @override
  Widget build(BuildContext context) {
    final hasWorldState = worldState.isNotEmpty;
    final hasMemory = memoryText.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.only(top: StudyOsSpacing.sm),
      children: <Widget>[
        _SectionHeader(
          title: 'Memories',
          description: 'Saved, personalized study context will appear here.',
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        _MemoryCard(hasMemory: hasMemory, memoryText: memoryText),
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

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.hasMemory, required this.memoryText});

  final bool hasMemory;
  final String memoryText;

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
          const Icon(
            Icons.psychology_alt_outlined,
            color: StudyOsColors.accent,
            size: 30,
          ),
          const SizedBox(height: StudyOsSpacing.lg),
          Text(
            hasMemory ? 'Saved memory document' : 'No saved memories yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StudyOsSpacing.sm),
          Text(
            hasMemory
                ? memoryText.trim()
                : 'The agent can append durable study preferences, habits, and context here.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
