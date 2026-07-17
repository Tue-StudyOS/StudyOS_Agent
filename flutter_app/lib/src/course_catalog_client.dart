import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'course_catalog_models.dart';
import 'feedback_client.dart';

class CourseCatalogClient {
  CourseCatalogClient({
    String baseUrl = studyOsFeedbackApiUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 12),
  }) : _baseUri = _parseBaseUri(baseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri? _baseUri;
  final http.Client _httpClient;
  final Duration requestTimeout;

  bool get isConfigured => _baseUri != null;

  Future<List<CourseCatalogEntry>> search(
    String query, {
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const <CourseCatalogEntry>[];
    final baseUri = _baseUri;
    if (baseUri == null) {
      throw const CourseCatalogException('Course lookup is not configured.');
    }
    try {
      final response = await _httpClient
          .post(
            _uri(baseUri, '/v1/courses/search'),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object>{
              'query': trimmed,
              'limit': limit.clamp(1, 25),
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CourseCatalogException(
          'Course lookup failed with HTTP ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['courses'] is! List) {
        throw const CourseCatalogException(
          'Course lookup returned an invalid response.',
        );
      }
      return (decoded['courses'] as List)
          .whereType<Map>()
          .map(
            (item) =>
                CourseCatalogEntry.fromJson(Map<String, Object?>.from(item)),
          )
          .where(
            (course) =>
                course.catalogId.isNotEmpty &&
                course.ratingCourseId.isNotEmpty &&
                course.courseNumber.isNotEmpty &&
                course.title.isNotEmpty,
          )
          .toList(growable: false);
    } on TimeoutException {
      throw const CourseCatalogException('Course lookup timed out.');
    } on http.ClientException {
      throw const CourseCatalogException('Course lookup is unreachable.');
    } on FormatException {
      throw const CourseCatalogException(
        'Course lookup returned an invalid response.',
      );
    }
  }

  static Uri? _parseBaseUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasAuthority || uri.userInfo.isNotEmpty) {
      return null;
    }
    final loopback =
        uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
    if (uri.scheme != 'https' && !(loopback && uri.scheme == 'http')) {
      return null;
    }
    if (uri.hasQuery || uri.hasFragment) return null;
    return uri;
  }

  static Uri _uri(Uri baseUri, String path) {
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    return baseUri.replace(path: '$basePath$relativePath');
  }
}

class CourseCatalogException implements Exception {
  const CourseCatalogException(this.message);

  final String message;
}
