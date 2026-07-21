import 'dart:convert';

import 'capability_result.dart';
import 'public_study_capabilities.dart';
import 'student_profile.dart';

const getMensaOptionsToolName = 'get_mensa_options';
const searchCampusLocationsToolName = 'search_campus_locations';

abstract interface class PublicStudyToolRunner {
  Future<String> execute(String toolName, String arguments);

  void close();
}

class LivePublicStudyToolRunner implements PublicStudyToolRunner {
  LivePublicStudyToolRunner({
    MensaOptionsCapability? mensa,
    CampusLocationCapability? locations,
  }) : _mensa = mensa ?? MensaOptionsCapability(),
       _locations = locations ?? CampusLocationCapability();

  final MensaOptionsCapability _mensa;
  final CampusLocationCapability _locations;

  @override
  Future<String> execute(String toolName, String arguments) async {
    final Map<String, Object?> args;
    try {
      args = _decodeArguments(arguments);
    } on FormatException {
      return _failure(toolName, 'Tool arguments must be a JSON object.');
    }
    return switch (toolName) {
      getMensaOptionsToolName => _mensas(args),
      searchCampusLocationsToolName => _campusLocations(args),
      _ => _failure(toolName, 'Public study tool is not available.'),
    };
  }

  Future<String> _mensas(Map<String, Object?> args) async {
    final preference = _preference(args['preference']);
    if (preference == null) {
      return _failure(
        getMensaOptionsToolName,
        'Preference must be any, vegetarian, or vegan.',
      );
    }
    final dateValue = _string(args, 'date');
    final date = dateValue.isEmpty ? null : _isoDate(dateValue);
    if (dateValue.isNotEmpty && date == null) {
      return _failure(
        getMensaOptionsToolName,
        'Date must use a valid YYYY-MM-DD value.',
      );
    }
    final result = await _mensa.load(
      MensaOptionsQuery(
        date: date,
        canteen: _string(args, 'canteen'),
        preference: preference,
        limit: _boundedInt(args, 'limit', fallback: 12, max: 30),
      ),
    );
    return jsonEncode(
      result.toJson(
        (items) => items.map((item) => item.toJson()).toList(growable: false),
      ),
    );
  }

  Future<String> _campusLocations(Map<String, Object?> args) async {
    final query = _string(args, 'query');
    if (query.isEmpty) {
      return _failure(
        searchCampusLocationsToolName,
        'A non-empty campus location query is required.',
      );
    }
    if (query.length > 120) {
      return _failure(
        searchCampusLocationsToolName,
        'Campus location queries are limited to 120 characters.',
      );
    }
    final result = await _locations.search(
      query,
      limit: _boundedInt(args, 'limit', fallback: 8, max: 8),
    );
    return jsonEncode(
      result.toJson(
        (items) => items.map((item) => item.toJson()).toList(growable: false),
      ),
    );
  }

  String _failure(String toolName, String message) {
    final now = DateTime.now();
    final source = toolName == getMensaOptionsToolName
        ? MensaOptionsCapability.source
        : CampusLocationCapability.source;
    return jsonEncode(
      CapabilityResult<List<Object?>>(
        state: CapabilityState.failed,
        policy: CapabilityPolicy.publicRead,
        source: source,
        fetchedAt: now,
        message: message,
      ).toJson((items) => items),
    );
  }

  @override
  void close() {
    _mensa.close();
    _locations.close();
  }
}

Map<String, Object?> _decodeArguments(String arguments) {
  if (arguments.trim().isEmpty) return const <String, Object?>{};
  final decoded = jsonDecode(arguments);
  if (decoded is! Map) throw const FormatException('Expected a JSON object.');
  return Map<String, Object?>.from(decoded);
}

String _string(Map<String, Object?> args, String key) =>
    args[key]?.toString().trim() ?? '';

int _boundedInt(
  Map<String, Object?> args,
  String key, {
  required int fallback,
  required int max,
}) {
  final value = args[key];
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  return (parsed ?? fallback).clamp(1, max).toInt();
}

FoodPreference? _preference(Object? value) {
  return switch (value?.toString().trim().toLowerCase() ?? 'any') {
    '' || 'any' => FoodPreference.noPreference,
    'vegetarian' => FoodPreference.vegetarian,
    'vegan' => FoodPreference.vegan,
    _ => null,
  };
}

DateTime? _isoDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  final canonical =
      '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  return canonical == value ? parsed : null;
}
