import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'talk_models.dart';

class TalksClient {
  TalksClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static final Uri sourceUri = Uri.parse('https://talks.tuebingen.ai/talks');
  static final Uri _upcomingUri = Uri.parse(
    'https://talks.tuebingen.ai/api/talks',
  );

  final http.Client _httpClient;

  Future<List<Talk>> fetchUpcoming({int limit = 100}) async {
    final http.Response response;
    try {
      response = await _httpClient
          .get(
            _upcomingUri,
            headers: const <String, String>{
              'Accept': 'application/json, text/plain, */*',
            },
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TalksException('Tübingen Talks timed out.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TalksException(
        'Tübingen Talks returned HTTP ${response.statusCode}.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const TalksException('Tübingen Talks returned invalid data.');
    }
    if (decoded is! Map<String, Object?> || decoded['talks'] is! List) {
      throw const TalksException(
        'Tübingen Talks returned an unexpected format.',
      );
    }

    try {
      final talks = (decoded['talks'] as List)
          .whereType<Map>()
          .where((item) => item['disabled'] != true)
          .map((item) => Talk.fromJson(Map<String, Object?>.from(item)))
          .toList();
      talks.sort(_compareStart);
      return talks.take(limit.clamp(1, 100).toInt()).toList();
    } on FormatException catch (error) {
      throw TalksException(error.message);
    }
  }

  void close() => _httpClient.close();
}

int _compareStart(Talk first, Talk second) {
  final firstStart = first.start;
  final secondStart = second.start;
  if (firstStart == null) return secondStart == null ? 0 : 1;
  if (secondStart == null) return -1;
  return firstStart.compareTo(secondStart);
}

class TalksException implements Exception {
  const TalksException(this.message);

  final String message;

  @override
  String toString() => message;
}
