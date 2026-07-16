import 'timetable_models.dart';

List<LectureEvent> mergeLectureOccurrences(Iterable<LectureEvent> occurrences) {
  final groups = <String, List<LectureEvent>>{};
  for (final occurrence in occurrences) {
    groups
        .putIfAbsent(_occurrenceKey(occurrence), () => <LectureEvent>[])
        .add(occurrence);
  }

  final merged = groups.values.map(_mergeGroup).toList()
    ..sort((first, second) {
      final byStart = first.start.compareTo(second.start);
      if (byStart != 0) return byStart;
      final byTitle = first.title.compareTo(second.title);
      if (byTitle != 0) return byTitle;
      final byEnd = _instant(first.end).compareTo(_instant(second.end));
      if (byEnd != 0) return byEnd;
      final byDetail = (first.detail ?? '').compareTo(second.detail ?? '');
      if (byDetail != 0) return byDetail;
      return first.id.compareTo(second.id);
    });
  return merged;
}

int _instant(DateTime? value) => value?.microsecondsSinceEpoch ?? -1;

LectureEvent _mergeGroup(List<LectureEvent> group) {
  final sourceIds = <String>{
    for (final occurrence in group) ...occurrence.allSourceIds,
  }.toList()..sort();
  final canonicalId = sourceIds.first;
  final representative = group.firstWhere(
    (occurrence) => occurrence.id == canonicalId,
    orElse: () => group.first,
  );
  final locationSet = <String>{};
  for (final occurrence in group) {
    final location = _clean(occurrence.location);
    if (location != null) locationSet.add(location);
  }
  final locations = locationSet.toList()..sort();

  return LectureEvent(
    id: canonicalId,
    sourceIds: sourceIds.skip(1).toList(growable: false),
    title: representative.title,
    start: representative.start,
    end: representative.end,
    location: _mergeLocations(locations),
    detail: representative.detail,
  );
}

// Location is excluded because ALMA emits one VEVENT per assigned room.
String _occurrenceKey(LectureEvent event) => <Object?>[
  _clean(event.title),
  event.start.microsecondsSinceEpoch,
  event.end?.microsecondsSinceEpoch,
  _clean(event.detail),
].join('\u0001');

String? _clean(String? value) {
  final cleaned = value?.split(RegExp(r'\s+')).join(' ').trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}

String? _mergeLocations(List<String> locations) {
  if (locations.isEmpty) return null;
  if (locations.length == 1) return locations.single;

  final words = locations
      .map((location) => location.split(RegExp(r'\s+')))
      .toList();
  var commonSuffixLength = 0;
  while (words.every((parts) => parts.length > commonSuffixLength)) {
    final candidate = words.first[words.first.length - commonSuffixLength - 1];
    if (!words.every(
      (parts) => parts[parts.length - commonSuffixLength - 1] == candidate,
    )) {
      break;
    }
    commonSuffixLength += 1;
  }

  final label = '${locations.length} locations';
  if (commonSuffixLength < 2 ||
      words.any((parts) => parts.length == commonSuffixLength)) {
    return '$label\n${locations.join(' · ')}';
  }
  final suffix = words.first
      .sublist(words.first.length - commonSuffixLength)
      .join(' ');
  final rooms = words
      .map(
        (parts) =>
            parts.sublist(0, parts.length - commonSuffixLength).join(' '),
      )
      .join(' · ');
  return '$label · $suffix\n$rooms';
}
