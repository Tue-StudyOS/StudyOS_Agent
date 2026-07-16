import 'package:flutter/material.dart';

import '../academic_models.dart';
import '../studyos_theme.dart';

class AcademicStatusSection extends StatelessWidget {
  const AcademicStatusSection({
    required this.snapshot,
    required this.error,
    required this.isRefreshing,
    required this.onRefresh,
    required this.reportError,
    required this.isOpeningReport,
    required this.onOpenReport,
    super.key,
  });

  final AcademicStatusSnapshot? snapshot;
  final String? error;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final String? reportError;
  final bool isOpeningReport;
  final Future<void> Function() onOpenReport;

  @override
  Widget build(BuildContext context) {
    final entries = snapshot?.entries ?? const <AcademicEntry>[];
    return Material(
      color: StudyOsColors.surface,
      borderRadius: BorderRadius.circular(StudyOsRadii.md),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey<String>('academic-status-expansion'),
        initiallyExpanded: false,
        maintainState: true,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          'Academic status',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          _summary(entries),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        children: <Widget>[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              StudyOsSpacing.md,
              StudyOsSpacing.xs,
              StudyOsSpacing.md,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton.icon(
                  onPressed: isOpeningReport ? null : onOpenReport,
                  icon: isOpeningReport
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('View PDF'),
                ),
                TextButton.icon(
                  onPressed: isRefreshing ? null : onRefresh,
                  icon: isRefreshing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
          if (error != null)
            _Message(title: 'Couldn’t refresh ALMA status', body: error!)
          else if (snapshot == null)
            const _Message(
              title: 'No academic status yet',
              body: 'Refresh to load your registrations from ALMA.',
            )
          else if (entries.isEmpty)
            _Message(
              title: 'No registrations shown',
              body:
                  snapshot!.notice ??
                  'Open the official ALMA report for the complete view.',
            )
          else
            for (var index = 0; index < entries.length; index++) ...<Widget>[
              _EntryRow(entry: entries[index]),
              if (index < entries.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: StudyOsSpacing.xxl),
                  child: Divider(height: 1),
                ),
            ],
          if (snapshot?.notice != null && entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(StudyOsSpacing.lg),
              child: Text(
                snapshot!.notice!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (reportError != null)
            _Message(title: 'Couldn’t open ALMA report', body: reportError!),
          const SizedBox(height: StudyOsSpacing.sm),
        ],
      ),
    );
  }

  String _summary(List<AcademicEntry> entries) {
    if (isRefreshing) return 'Refreshing registrations…';
    if (error != null) return 'Registrations unavailable';
    if (snapshot == null) return 'Not loaded';
    if (entries.isEmpty) return 'No registrations shown';
    return entries.length == 1
        ? '1 current registration'
        : '${entries.length} current registrations';
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final AcademicEntry entry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(StudyOsSpacing.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          entry.category == 'Prüfung'
              ? Icons.assignment_outlined
              : Icons.menu_book_outlined,
          color: StudyOsColors.accent,
          size: 20,
        ),
        const SizedBox(width: StudyOsSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(entry.title, style: Theme.of(context).textTheme.labelLarge),
              if (entry.status != null || entry.detail != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  <String?>[
                    entry.status,
                    entry.detail,
                  ].whereType<String>().join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        Text(entry.category, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(StudyOsSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: StudyOsSpacing.xs),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
