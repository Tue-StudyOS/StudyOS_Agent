import 'package:http/http.dart' as http;

import 'map_location_models.dart';

class MapSearchClient {
  MapSearchClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  static final sourceUri = Uri.parse(
    'https://nominatim.openstreetmap.org/search',
  );

  Future<List<MapLocation>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <MapLocation>[];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'limit': '8',
      'addressdetails': '1',
      'bounded': '1',
      'viewbox': '8.93,48.57,9.16,48.47',
      'q': '$trimmed Tuebingen',
    });
    final response = await _client
        .get(
          uri,
          headers: const <String, String>{
            'User-Agent': 'StudyOS Agent course prototype',
          },
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MapSearchException(
        'Search failed with HTTP ${response.statusCode}.',
      );
    }
    return mapLocationsFromNominatim(response.body);
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

class MapSearchException implements Exception {
  const MapSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}
