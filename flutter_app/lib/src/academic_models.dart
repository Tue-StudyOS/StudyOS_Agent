import 'private_study_models.dart' show safePortalTarget;

class AcademicEntry {
  const AcademicEntry({
    required this.category,
    required this.title,
    this.status,
    this.detail,
    this.eventType,
    this.number,
    this.semester,
    this.scheduleText,
    this.detailUrl,
    this.attempt,
  });

  final String category;
  final String title;
  final String? status;
  final String? detail;
  final String? eventType;
  final String? number;
  final String? semester;
  final String? scheduleText;
  final String? detailUrl;
  final String? attempt;

  Map<String, Object?> toJson() => <String, Object?>{
    'category': category,
    'title': title,
    if (status != null) 'status': status,
    if (detail != null) 'detail': detail,
    if (eventType != null) 'eventType': eventType,
    if (number != null) 'number': number,
    if (semester != null) 'semester': semester,
    if (scheduleText != null) 'scheduleText': scheduleText,
    if (detailUrl != null) 'detailUrl': safePortalTarget(detailUrl!),
    if (attempt != null) 'attempt': attempt,
  };
}

class AcademicStatusSnapshot {
  const AcademicStatusSnapshot({
    required this.term,
    required this.entries,
    required this.refreshedAt,
    this.notice,
    this.availableTerms = const <String>[],
  });

  final String? term;
  final List<AcademicEntry> entries;
  final DateTime refreshedAt;
  final String? notice;
  final List<String> availableTerms;
}
