class Talk {
  const Talk({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.description,
    required this.location,
    required this.speakerName,
    required this.tags,
  });

  factory Talk.fromJson(Map<String, Object?> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null) {
      throw const FormatException('Talk data did not include a valid id.');
    }
    final title = json['title']?.toString().trim() ?? '';
    if (title.isEmpty) {
      throw const FormatException('Talk data did not include a title.');
    }
    return Talk(
      id: id,
      title: title,
      timestamp: json['timestamp']?.toString().trim() ?? '',
      description: _optionalText(json['description']),
      location: _optionalText(json['location']),
      speakerName: _optionalText(json['speaker_name']),
      tags: (json['tags'] as List? ?? const <Object?>[])
          .whereType<Map>()
          .map((tag) => tag['name']?.toString().trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toList(),
    );
  }

  final int id;
  final String title;
  final String timestamp;
  final String? description;
  final String? location;
  final String? speakerName;
  final List<String> tags;

  DateTime? get start => DateTime.tryParse(timestamp)?.toLocal();

  Uri get sourceUri =>
      Uri.parse('https://talks.tuebingen.ai/talks/talk/id=$id');

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return <String>[
      title,
      description ?? '',
      location ?? '',
      speakerName ?? '',
      tags.join(' '),
    ].join('\n').toLowerCase().contains(normalized);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'timestamp': timestamp,
    'speaker_name': speakerName,
    'location': location,
    'description': description,
    'tags': tags,
    'source_url': sourceUri.toString(),
  };
}

String? _optionalText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String talkMonthAbbreviation(int month) => const <String>[
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
][month - 1];
