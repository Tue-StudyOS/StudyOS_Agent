enum OfficialDocumentKind { enrollment, transcript, certificate }

class OfficialDocument {
  const OfficialDocument({
    required this.kind,
    required this.label,
    required this.trigger,
  });

  final OfficialDocumentKind kind;
  final String label;
  final String trigger;

  String get id => '${kind.name}:$trigger';
}
