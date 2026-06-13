class LocalModelOption {
  const LocalModelOption({
    required this.id,
    required this.label,
    required this.fileName,
    required this.description,
    this.downloadUrl = '',
  });

  final String id;
  final String label;
  final String fileName;
  final String description;
  final String downloadUrl;

  bool get needsCustomUrl => downloadUrl.isEmpty;
}

const List<LocalModelOption> localModelCatalog = <LocalModelOption>[
  LocalModelOption(
    id: 'gemma-4-e2b-it',
    label: 'Gemma 4 E2B Instruct',
    fileName: 'gemma-4-e2b-it.litertlm',
    description: 'Balanced default for mid-range Android phones.',
  ),
  LocalModelOption(
    id: 'qwen3-1-7b',
    label: 'Qwen3 1.7B',
    fileName: 'qwen3-1-7b.task',
    description: 'Small agentic model candidate for tool routing and RAG.',
  ),
  LocalModelOption(
    id: 'lfm2-5-1-2b',
    label: 'LFM2.5 1.2B',
    fileName: 'lfm2-5-1-2b.task',
    description: 'Fast low-memory candidate for smaller devices.',
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
