import 'package:flutter/material.dart';

import '../official_document_models.dart';
import '../studyos_theme.dart';

class OfficialDocumentsView extends StatelessWidget {
  const OfficialDocumentsView({
    required this.documents,
    required this.error,
    required this.isLoading,
    required this.openingDocumentId,
    required this.onRefresh,
    required this.onOpen,
    super.key,
  });

  final List<OfficialDocument> documents;
  final String? error;
  final bool isLoading;
  final String? openingDocumentId;
  final Future<void> Function() onRefresh;
  final Future<void> Function(OfficialDocument document) onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(StudyOsSpacing.xl),
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              const SizedBox(width: StudyOsSpacing.xs),
              Expanded(
                child: Text(
                  'Official documents',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Refresh documents',
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: StudyOsSpacing.sm),
          Text(
            'Current records provided by ALMA. Open any document to preview, share, or save its PDF.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: StudyOsSpacing.xxl),
          if (error != null)
            _Message(title: 'Couldn’t load documents', body: error!),
          if (isLoading && documents.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: StudyOsSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!isLoading && documents.isEmpty && error == null)
            _Message(
              title: 'No documents loaded',
              body:
                  'Refresh to retrieve the official documents available in ALMA.',
            ),
          for (final kind in OfficialDocumentKind.values) ...<Widget>[
            if (_forKind(kind).isNotEmpty) ...<Widget>[
              const SizedBox(height: StudyOsSpacing.xl),
              Text(
                _title(kind),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: StudyOsSpacing.sm),
              Material(
                color: StudyOsColors.surface,
                borderRadius: BorderRadius.circular(StudyOsRadii.md),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(StudyOsRadii.md),
                  child: Column(
                    children: <Widget>[
                      for (final document in _forKind(kind))
                        _DocumentRow(
                          document: document,
                          isOpening: openingDocumentId == document.id,
                          onTap: () => onOpen(document),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    ),
  );

  List<OfficialDocument> _forKind(OfficialDocumentKind kind) =>
      documents.where((document) => document.kind == kind).toList();

  String _title(OfficialDocumentKind kind) => switch (kind) {
    OfficialDocumentKind.enrollment => 'Registrations',
    OfficialDocumentKind.transcript => 'Transcript & examinations',
    OfficialDocumentKind.certificate => 'Certificates',
  };
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.document,
    required this.isOpening,
    required this.onTap,
  });

  final OfficialDocument document;
  final bool isOpening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: isOpening ? null : onTap,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: StudyOsSpacing.lg,
      vertical: StudyOsSpacing.xs,
    ),
    leading: const Icon(
      Icons.picture_as_pdf_outlined,
      color: StudyOsColors.accent,
    ),
    title: Text(document.label, style: Theme.of(context).textTheme.labelLarge),
    trailing: isOpening
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.chevron_right_rounded),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Material(
    color: StudyOsColors.surface,
    borderRadius: BorderRadius.circular(StudyOsRadii.md),
    child: Padding(
      padding: const EdgeInsets.all(StudyOsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StudyOsSpacing.xs),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}
