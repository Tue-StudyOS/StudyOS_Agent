import 'capability_result.dart';
import 'campus_client.dart';
import 'campus_models.dart';
import 'map_location_models.dart';
import 'map_search_client.dart';
import 'student_profile.dart';

typedef CapabilityClock = DateTime Function();

class MensaOptionsQuery {
  const MensaOptionsQuery({
    this.date,
    this.canteen = '',
    this.preference = FoodPreference.noPreference,
    this.limit = 12,
  });

  final DateTime? date;
  final String canteen;
  final FoodPreference preference;
  final int limit;
}

class MensaOption {
  const MensaOption({required this.canteen, required this.menu});

  final CampusCanteen canteen;
  final CampusMenu menu;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': menu.id.isEmpty
        ? '${canteen.id}:${menu.date}:${menu.line}'.toLowerCase()
        : '${canteen.id}:${menu.id}',
    'canteen_id': canteen.id,
    'canteen': canteen.name,
    'date': menu.date,
    'line': menu.line,
    'items': menu.items,
    'dietary_markers': menu.icons,
    'student_price': menu.studentPrice,
  };
}

class MensaOptionsCapability {
  MensaOptionsCapability({
    CampusClient? client,
    CapabilityClock? clock,
    this.ttl = const Duration(minutes: 15),
  }) : _client = client ?? CampusClient(),
       _clock = clock ?? DateTime.now;

  static final CapabilitySource source = CapabilitySource(
    id: 'my_stuwe_mensa',
    label: 'Studierendenwerk Tübingen-Hohenheim meal plans',
    url: CampusClient.sourceUri.toString(),
  );

  final CampusClient _client;
  final CapabilityClock _clock;
  final Duration ttl;
  _TimedValue<List<CampusCanteen>>? _cache;
  Future<List<CampusCanteen>>? _inFlight;

  Future<CapabilityResult<List<MensaOption>>> load(
    MensaOptionsQuery query,
  ) async {
    final fetchedAt = _clock();
    try {
      final canteens = await _loadCanteens(fetchedAt);
      final options = _filter(canteens.value, query);
      return CapabilityResult<List<MensaOption>>(
        state: canteens.stale
            ? CapabilityState.stale
            : options.isEmpty
            ? CapabilityState.empty
            : CapabilityState.fresh,
        policy: CapabilityPolicy.publicRead,
        source: source,
        fetchedAt: canteens.fetchedAt,
        expiresAt: canteens.expiresAt,
        data: options,
        message: canteens.message,
      );
    } on Object catch (error) {
      return CapabilityResult<List<MensaOption>>(
        state: CapabilityState.failed,
        policy: CapabilityPolicy.publicRead,
        source: source,
        fetchedAt: fetchedAt,
        message: boundedCapabilityMessage(error),
      );
    }
  }

  void invalidate() => _cache = null;

  void close() => _client.close();

  Future<_CapabilityValue<List<CampusCanteen>>> _loadCanteens(
    DateTime now,
  ) async {
    final cached = _cache;
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return cached.current;
    }
    try {
      final pending = _inFlight ??= _client.fetchTuebingenCanteens();
      final value = await pending;
      final stored = _TimedValue(value, fetchedAt: now, ttl: ttl);
      _cache = stored;
      return stored.current;
    } on Object catch (error) {
      if (cached == null) rethrow;
      return cached.stale(boundedCapabilityMessage(error));
    } finally {
      _inFlight = null;
    }
  }

  List<MensaOption> _filter(
    List<CampusCanteen> canteens,
    MensaOptionsQuery query,
  ) {
    final canteenFilter = query.canteen.trim().toLowerCase();
    final options = <MensaOption>[];
    for (final canteen in canteens) {
      if (canteenFilter.isNotEmpty &&
          canteen.id != canteenFilter &&
          !canteen.name.toLowerCase().contains(canteenFilter)) {
        continue;
      }
      final filtered = canteen.filteredFor(query.preference);
      for (final menu in filtered.menus) {
        if (query.date != null && !_sameDate(menu.parsedDate, query.date)) {
          continue;
        }
        options.add(MensaOption(canteen: canteen, menu: menu));
      }
    }
    options.sort((first, second) {
      final dateOrder = (first.menu.date).compareTo(second.menu.date);
      if (dateOrder != 0) return dateOrder;
      return first.canteen.name.compareTo(second.canteen.name);
    });
    return options.take(query.limit).toList(growable: false);
  }
}

class CampusLocationResult {
  const CampusLocationResult(this.location);

  final MapLocation location;

  Map<String, Object?> toJson() => <String, Object?>{
    'id':
        '${location.source}:${location.latitude.toStringAsFixed(6)},${location.longitude.toStringAsFixed(6)}',
    'name': location.name,
    'address': location.address,
    'latitude': location.latitude,
    'longitude': location.longitude,
    'category': location.category,
  };
}

class CampusLocationCapability {
  CampusLocationCapability({
    MapSearchClient? client,
    CapabilityClock? clock,
    this.ttl = const Duration(minutes: 10),
  }) : _client = client ?? MapSearchClient(),
       _clock = clock ?? DateTime.now;

  static final CapabilitySource source = CapabilitySource(
    id: 'openstreetmap_nominatim',
    label: 'OpenStreetMap Nominatim',
    url: MapSearchClient.sourceUri.toString(),
  );

  final MapSearchClient _client;
  final CapabilityClock _clock;
  final Duration ttl;
  final Map<String, _TimedValue<List<MapLocation>>> _cache = {};

  Future<CapabilityResult<List<CampusLocationResult>>> search(
    String query, {
    int limit = 8,
  }) async {
    final now = _clock();
    final key = query.trim().toLowerCase();
    try {
      final cached = _cache[key];
      late final _CapabilityValue<List<MapLocation>> locations;
      if (cached != null && now.isBefore(cached.expiresAt)) {
        locations = cached.current;
      } else {
        try {
          final value = await _client.search(query);
          final stored = _TimedValue(value, fetchedAt: now, ttl: ttl);
          _cache[key] = stored;
          locations = stored.current;
          if (_cache.length > 32) _cache.remove(_cache.keys.first);
        } on Object catch (error) {
          if (cached == null) rethrow;
          locations = cached.stale(boundedCapabilityMessage(error));
        }
      }
      final data = locations.value
          .take(limit)
          .map(CampusLocationResult.new)
          .toList(growable: false);
      return CapabilityResult<List<CampusLocationResult>>(
        state: locations.stale
            ? CapabilityState.stale
            : data.isEmpty
            ? CapabilityState.empty
            : CapabilityState.fresh,
        policy: CapabilityPolicy.publicRead,
        source: source,
        fetchedAt: locations.fetchedAt,
        expiresAt: locations.expiresAt,
        data: data,
        message: locations.message,
      );
    } on Object catch (error) {
      return CapabilityResult<List<CampusLocationResult>>(
        state: CapabilityState.failed,
        policy: CapabilityPolicy.publicRead,
        source: source,
        fetchedAt: now,
        message: boundedCapabilityMessage(error),
      );
    }
  }

  void invalidate() => _cache.clear();

  void close() => _client.close();
}

class _TimedValue<T> {
  _TimedValue(this.value, {required this.fetchedAt, required Duration ttl})
    : expiresAt = fetchedAt.add(ttl);

  final T value;
  final DateTime fetchedAt;
  final DateTime expiresAt;

  _CapabilityValue<T> get current =>
      _CapabilityValue(value, fetchedAt: fetchedAt, expiresAt: expiresAt);

  _CapabilityValue<T> stale(String message) => _CapabilityValue(
    value,
    fetchedAt: fetchedAt,
    expiresAt: expiresAt,
    stale: true,
    message: message,
  );
}

class _CapabilityValue<T> {
  const _CapabilityValue(
    this.value, {
    required this.fetchedAt,
    required this.expiresAt,
    this.stale = false,
    this.message,
  });

  final T value;
  final DateTime fetchedAt;
  final DateTime expiresAt;
  final bool stale;
  final String? message;
}

bool _sameDate(DateTime? first, DateTime? second) =>
    first != null &&
    second != null &&
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
