import 'dart:convert';

import 'package:http/http.dart' as http;

import 'campus_models.dart';

class CampusClient {
  CampusClient({
    http.Client? httpClient,
    this.cacheTtl = const Duration(hours: 6),
  }) : _httpClient = httpClient ?? http.Client();

  static const _mealplanUrl =
      'https://www.my-stuwe.de/wp-json/mealplans/v1/canteens?lang=de';
  static const _tuebingenCanteenIds = <String>{
    '611',
    '621',
    '623',
    '715',
    '724',
  };

  final http.Client _httpClient;
  final Duration cacheTtl;
  static List<CampusCanteen>? _cachedCanteens;
  static DateTime? _cachedAt;

  Future<List<CampusCanteen>> fetchTuebingenCanteens({
    bool forceRefresh = false,
  }) async {
    final cached = _cachedCanteens;
    final cachedAt = _cachedAt;
    if (!forceRefresh && cached != null && cachedAt != null) {
      final age = DateTime.now().difference(cachedAt);
      if (age <= cacheTtl) return cached;
    }
    final response = await _httpClient.get(Uri.parse(_mealplanUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CampusException('Mensa data returned HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const CampusException('Mensa data has an unexpected format.');
    }
    final canteens = _tuebingenCanteenIds
        .where(decoded.containsKey)
        .map((id) => _canteenFromJson(id, decoded[id]))
        .whereType<CampusCanteen>()
        .toList();
    _cachedCanteens = canteens;
    _cachedAt = DateTime.now();
    return canteens;
  }

  void close() => _httpClient.close();
}

CampusCanteen? _canteenFromJson(String id, Object? value) {
  if (value is! Map<String, Object?>) return null;
  final menus = (value['menus'] as List? ?? const <Object?>[])
      .map(_menuFromJson)
      .whereType<CampusMenu>()
      .toList();
  return CampusCanteen(
    id: id,
    name: value['canteen']?.toString().trim() ?? 'Mensa',
    menus: menus,
  );
}

CampusMenu? _menuFromJson(Object? value) {
  if (value is! Map<String, Object?>) return null;
  final items = _stringList(value['menu']);
  if (items.isEmpty) return null;
  return CampusMenu(
    id: value['id']?.toString() ?? '',
    line: value['menuLine']?.toString().trim() ?? 'Meal',
    date: value['menuDate']?.toString().trim() ?? '',
    items: items,
    icons: <String>{
      ..._stringList(value['icons']),
      ..._stringList(value['filtersInclude']),
    }.toList(),
    studentPrice: value['studentPrice']?.toString().trim(),
  );
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

class CampusException implements Exception {
  const CampusException(this.message);

  final String message;

  @override
  String toString() => message;
}
