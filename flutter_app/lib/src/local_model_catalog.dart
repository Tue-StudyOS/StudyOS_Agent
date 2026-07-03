class LocalModelOption {
  const LocalModelOption({
    required this.id,
    required this.label,
    required this.fileName,
    required this.description,
    this.downloadUrl = '',
    this.expectedSizeBytes,
    this.expectedSha256,
  });

  final String id;
  final String label;
  final String fileName;
  final String description;
  final String downloadUrl;
  final int? expectedSizeBytes;
  final String? expectedSha256;

  bool get needsCustomUrl => downloadUrl.isEmpty;
  bool get hasIntegrityCheck =>
      expectedSizeBytes != null || expectedSha256?.isNotEmpty == true;
}

const List<LocalModelOption> localModelCatalog = <LocalModelOption>[
  LocalModelOption(
    id: 'gemma-4-e2b-it',
    label: 'Gemma 4 E2B Instruct',
    fileName: 'gemma-4-e2b-it.litertlm',
    description: 'Balanced default for mid-range Android phones.',
    downloadUrl: 'https://huggingface.co/litert-community/'
        'gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    expectedSizeBytes: 2588147712,
  ),
  LocalModelOption(
    id: 'custom',
    label: 'Custom .litertlm / .task URL',
    fileName: 'custom-local-model.task',
    description:
        'Paste a direct model URL from AI Edge Gallery or Hugging Face.',
  ),
];

LocalModelOption localModelById(String id) {
  return localModelCatalog.firstWhere(
    (model) => model.id == id,
    orElse: () => localModelCatalog.first,
  );
}
