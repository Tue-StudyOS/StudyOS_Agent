import 'dart:convert';

class MapLocation {
  const MapLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.category,
    this.source = 'nominatim',
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? category;
  final String source;

  String get coordinateText =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  String get mapsQuery => Uri.encodeComponent('$latitude,$longitude ($name)');

  String assistantPrompt() {
    final buffer = StringBuffer()
      ..writeln('I selected this destination in StudyOS Maps:')
      ..writeln('- Name: $name')
      ..writeln('- Coordinates: $coordinateText')
      ..writeln('- Source: $source');
    if (address != null && address!.isNotEmpty) {
      buffer.writeln('- Address: $address');
    }
    if (category != null && category!.isNotEmpty) {
      buffer.writeln('- Category: $category');
    }
    buffer
      ..writeln()
      ..writeln(
        'Please explain what is useful to know about this place, how I could get there from my current study context, and any navigation options or caveats.',
      );
    return buffer.toString().trim();
  }

  static MapLocation? fromNominatimJson(Map<String, Object?> json) {
    final lat = double.tryParse(json['lat']?.toString() ?? '');
    final lon = double.tryParse(json['lon']?.toString() ?? '');
    final displayName = json['display_name']?.toString().trim();
    if (lat == null ||
        lon == null ||
        displayName == null ||
        displayName.isEmpty) {
      return null;
    }
    final namedParts = displayName.split(',');
    final name = namedParts.first.trim();
    return MapLocation(
      name: name.isEmpty ? displayName : name,
      latitude: lat,
      longitude: lon,
      address: displayName,
      category: json['type']?.toString(),
    );
  }
}

List<MapLocation> mapLocationsFromNominatim(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) return const <MapLocation>[];
  return decoded
      .whereType<Map>()
      .map(
        (item) =>
            MapLocation.fromNominatimJson(Map<String, Object?>.from(item)),
      )
      .whereType<MapLocation>()
      .toList(growable: false);
}
