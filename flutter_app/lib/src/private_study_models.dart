enum StudyPortalSource { ilias, moodle }

class PortalTask {
  const PortalTask({
    required this.source,
    required this.id,
    required this.title,
    required this.url,
    this.courseTitle,
    this.itemType,
    this.startAt,
    this.dueAt,
    this.rawStartHint,
    this.rawDueHint,
    this.status,
    this.actionable = true,
  });

  final StudyPortalSource source;
  final String id;
  final String title;
  final String url;
  final String? courseTitle;
  final String? itemType;
  final DateTime? startAt;
  final DateTime? dueAt;
  final String? rawStartHint;
  final String? rawDueHint;
  final String? status;
  final bool actionable;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': '${source.name}:$id',
    'source': source.name,
    'title': title,
    if (courseTitle != null) 'courseTitle': courseTitle,
    if (itemType != null) 'itemType': itemType,
    if (startAt != null) 'startAt': startAt!.toUtc().toIso8601String(),
    if (dueAt != null) 'dueAt': dueAt!.toUtc().toIso8601String(),
    if (rawStartHint != null) 'rawStartHint': rawStartHint,
    if (rawDueHint != null) 'rawDueHint': rawDueHint,
    if (status != null) 'status': status,
    'actionable': actionable,
    'target': safePortalTarget(url),
  };
}

class PortalDeadline {
  const PortalDeadline({
    required this.source,
    required this.id,
    required this.title,
    required this.dueAt,
    required this.url,
    this.courseTitle,
    this.dueHint,
    this.requirement,
    this.status,
  });

  final StudyPortalSource source;
  final String id;
  final String title;
  final DateTime dueAt;
  final String url;
  final String? courseTitle;
  final String? dueHint;
  final String? requirement;
  final String? status;

  String get deduplicationKey =>
      '${source.name}|$url|${title.toLowerCase()}|${dueAt.toUtc().toIso8601String()}';

  Map<String, Object?> toJson() => <String, Object?>{
    'id': '${source.name}:$id',
    'source': source.name,
    'title': title,
    if (courseTitle != null) 'courseTitle': courseTitle,
    'dueAt': dueAt.toUtc().toIso8601String(),
    if (dueHint != null) 'dueHint': dueHint,
    if (requirement != null) 'requirement': requirement,
    if (status != null) 'status': status,
    'target': safePortalTarget(url),
  };
}

String safePortalTarget(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return '';
  const sensitiveKeys = <String>{
    'sesskey',
    'token',
    'access_token',
    'samlresponse',
    'relaystate',
  };
  final filtered = <String, String>{};
  for (final entry in uri.queryParameters.entries) {
    if (!sensitiveKeys.contains(entry.key.toLowerCase())) {
      filtered[entry.key] = entry.value;
    }
  }
  return uri
      .replace(queryParameters: filtered.isEmpty ? null : filtered)
      .toString();
}

class PortalAuthenticationException implements Exception {
  const PortalAuthenticationException([
    this.message = 'University portal authentication is required.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class PortalException implements Exception {
  const PortalException(this.message);

  final String message;

  @override
  String toString() => message;
}
