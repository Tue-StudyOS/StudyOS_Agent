part of 'ics_parser.dart';

class _IcsProperty {
  const _IcsProperty({
    required this.name,
    required this.parameters,
    required this.value,
  });

  final String name;
  final Map<String, String> parameters;
  final String value;

  _IcsProperty copyWith({String? value}) => _IcsProperty(
    name: name,
    parameters: parameters,
    value: value ?? this.value,
  );
}

List<String> _unfold(String raw) {
  final lines = <String>[];
  for (final line
      in raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    if ((line.startsWith(' ') || line.startsWith('\t')) && lines.isNotEmpty) {
      lines[lines.length - 1] = '${lines.last}${line.substring(1)}';
    } else {
      lines.add(line);
    }
  }
  return lines;
}

_IcsProperty? _parseLine(String line) {
  final separator = line.indexOf(':');
  if (separator < 1) return null;
  final keyParts = line.substring(0, separator).split(';');
  final parameters = <String, String>{};
  for (final part in keyParts.skip(1)) {
    final split = part.split('=');
    if (split.length == 2) parameters[split.first.toUpperCase()] = split.last;
  }
  return _IcsProperty(
    name: keyParts.first.toUpperCase(),
    parameters: parameters,
    value: line.substring(separator + 1),
  );
}

DateTime? _parseDate(_IcsProperty property) =>
    _parseIcsDate(property.value, property.parameters);

DateTime? _parseUntil(String? value) =>
    value == null ? null : _parseIcsDate(value, const <String, String>{});

DateTime? _parseIcsDate(String value, Map<String, String> parameters) {
  final raw = value.trim();
  if (raw.length == 8 || parameters['VALUE'] == 'DATE') {
    return DateTime.tryParse(
      '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}',
    );
  }
  final year = int.tryParse(raw.substring(0, 4));
  final month = int.tryParse(raw.substring(4, 6));
  final day = int.tryParse(raw.substring(6, 8));
  final hour = raw.length >= 11 ? int.tryParse(raw.substring(9, 11)) : 0;
  final minute = raw.length >= 13 ? int.tryParse(raw.substring(11, 13)) : 0;
  final second = raw.length >= 15 ? int.tryParse(raw.substring(13, 15)) : 0;
  if ([year, month, day, hour, minute, second].contains(null)) return null;
  if (raw.endsWith('Z')) {
    return DateTime.utc(year!, month!, day!, hour!, minute!, second!).toLocal();
  }
  return DateTime(year!, month!, day!, hour!, minute!, second!);
}

String? _text(_IcsProperty? property) {
  final value = property?.value;
  if (value == null || value.isEmpty) return null;
  return value
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', r'\')
      .trim();
}

Set<int> _weekdays(String? raw, int fallback) {
  const map = <String, int>{
    'MO': 1,
    'TU': 2,
    'WE': 3,
    'TH': 4,
    'FR': 5,
    'SA': 6,
    'SU': 7,
  };
  if (raw == null || raw.isEmpty) return <int>{fallback};
  return raw
      .split(',')
      .map((day) => map[day.substring(day.length - 2).toUpperCase()])
      .whereType<int>()
      .toSet();
}
