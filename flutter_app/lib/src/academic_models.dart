class AcademicEntry {
  const AcademicEntry({
    required this.category,
    required this.title,
    this.status,
    this.detail,
  });

  final String category;
  final String title;
  final String? status;
  final String? detail;

  Map<String, Object?> toJson() => <String, Object?>{
    'category': category,
    'title': title,
    if (status != null) 'status': status,
    if (detail != null) 'detail': detail,
  };
}

class AcademicStatusSnapshot {
  const AcademicStatusSnapshot({
    required this.term,
    required this.entries,
    required this.refreshedAt,
    this.notice,
  });

  final String? term;
  final List<AcademicEntry> entries;
  final DateTime refreshedAt;
  final String? notice;
}
