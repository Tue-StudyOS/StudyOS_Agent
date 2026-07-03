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
    downloadUrl:
        'https://huggingface.co/litert-community/'
        'gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    // No integrity check for now: the resolver did not expose a stable
    // SHA-256, and pinning the advertised size is too brittle (a re-upload
    // would break every download). The native download path still verifies
    // expectedSizeBytes/expectedSha256 when a future entry supplies them.
  ),
  LocalModelOption(
    id: 'qwen3-1-7b',
    label: 'Qwen3 1.7B',
    fileName: 'qwen3-1-7b.litertlm',
    description: 'Small agentic model for tool routing and RAG.',
    downloadUrl:
        'https://huggingface.co/litert-community/'
        'Qwen3-1.7B/resolve/main/Qwen3_1.7B.litertlm',
    // No integrity check for now (see gemma entry above).
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
