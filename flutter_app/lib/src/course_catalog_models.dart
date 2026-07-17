class CourseCatalogEntry {
  const CourseCatalogEntry({
    required this.catalogId,
    required this.ratingCourseId,
    required this.courseNumber,
    required this.title,
    required this.periodLabel,
    required this.ects,
    required this.lecturer,
    required this.types,
  });

  final String catalogId;
  final String ratingCourseId;
  final String courseNumber;
  final String title;
  final String periodLabel;
  final double? ects;
  final String? lecturer;
  final List<String> types;

  factory CourseCatalogEntry.fromJson(Map<String, Object?> json) {
    final rawTypes = json['types'];
    return CourseCatalogEntry(
      catalogId: json['courseId']?.toString() ?? '',
      ratingCourseId: json['ratingCourseId']?.toString() ?? '',
      courseNumber: json['courseNumber']?.toString().trim() ?? '',
      title: json['title']?.toString().trim() ?? '',
      periodLabel: json['periodLabel']?.toString().trim() ?? '',
      ects: json['ects'] is num ? (json['ects'] as num).toDouble() : null,
      lecturer: _optionalText(json['lecturer']),
      types: rawTypes is List
          ? rawTypes
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
    );
  }
}

String? _optionalText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
