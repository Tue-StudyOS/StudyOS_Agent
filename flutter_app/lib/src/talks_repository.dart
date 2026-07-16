import 'talk_models.dart';
import 'talks_client.dart';

class TalksRepository {
  TalksRepository({TalksClient? client}) : _client = client ?? TalksClient();

  static const Duration _cacheLifetime = Duration(minutes: 15);

  final TalksClient _client;
  List<Talk>? _cachedTalks;
  DateTime? _loadedAt;
  Future<List<Talk>>? _inFlight;
  bool _disposed = false;

  Future<List<Talk>> load({bool refresh = false}) {
    if (_disposed) {
      return Future<List<Talk>>.error(
        StateError('TalksRepository has been disposed.'),
      );
    }
    final cached = _cachedTalks;
    final loadedAt = _loadedAt;
    if (!refresh &&
        cached != null &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < _cacheLifetime) {
      return Future<List<Talk>>.value(cached);
    }
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    late final Future<List<Talk>> request;
    request = _client
        .fetchUpcoming()
        .then((talks) {
          final result = List<Talk>.unmodifiable(talks);
          _cachedTalks = result;
          _loadedAt = DateTime.now();
          return result;
        })
        .whenComplete(() {
          if (identical(_inFlight, request)) _inFlight = null;
        });
    _inFlight = request;
    return request;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client.close();
  }
}
