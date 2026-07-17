import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'feedback_models.dart';
import 'feedback_token_store.dart';

const studyOsFeedbackApiUrl = String.fromEnvironment(
  'STUDYOS_FEEDBACK_API_URL',
);

class FeedbackClient {
  FeedbackClient({
    String baseUrl = studyOsFeedbackApiUrl,
    http.Client? httpClient,
    FeedbackTokenStore? tokenStore,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _baseUri = _parseBaseUri(baseUrl),
       _httpClient = httpClient ?? http.Client(),
       _tokenStore = tokenStore ?? SecureFeedbackTokenStore();

  final Uri? _baseUri;
  final http.Client _httpClient;
  final FeedbackTokenStore _tokenStore;
  final Duration requestTimeout;

  bool get isConfigured => _baseUri != null;

  Future<FeedbackPublicSnapshot> loadPublic({required String courseId}) async {
    final response = await _response(
      _httpClient.get(
        _uri('/v1/courses/${Uri.encodeComponent(courseId)}/feedback/public'),
        headers: _headers(),
      ),
    );
    final json = _successfulJson(response);
    return FeedbackPublicSnapshot.fromJson(json);
  }

  Future<FeedbackSubmission?> loadOwn({required String courseId}) async {
    final token = await _tokenStore.read();
    if (token == null || token.isEmpty) return null;
    final response = await _response(
      _httpClient.get(
        _uri('/v1/courses/${Uri.encodeComponent(courseId)}/feedback/mine'),
        headers: _headers(token: token),
      ),
    );
    if (response.statusCode == 401) {
      await _tokenStore.clear();
      return null;
    }
    if (response.statusCode == 404) return null;
    return FeedbackSubmission.fromJson(_successfulJson(response));
  }

  Future<FeedbackSubmission> submit({
    required int rating,
    required String courseId,
    String? comment,
  }) async {
    if (rating < 1 || rating > 5) {
      throw const FeedbackException('Choose a rating from 1 to 5 stars.');
    }
    final trimmedComment = comment?.trim() ?? '';
    if (trimmedComment.length > 1000) {
      throw const FeedbackException(
        'Keep the feedback comment under 1,000 characters.',
      );
    }
    final body = jsonEncode(<String, Object?>{
      'rating': rating,
      'comment': trimmedComment.isEmpty ? null : trimmedComment,
    });
    var token = await _installationToken();
    var response = await _response(
      _httpClient.put(
        _uri('/v1/courses/${Uri.encodeComponent(courseId)}/feedback/mine'),
        headers: _headers(token: token),
        body: body,
      ),
    );
    if (response.statusCode == 401) {
      await _tokenStore.clear();
      token = await _installationToken();
      response = await _response(
        _httpClient.put(
          _uri('/v1/courses/${Uri.encodeComponent(courseId)}/feedback/mine'),
          headers: _headers(token: token),
          body: body,
        ),
      );
    }
    return FeedbackSubmission.fromJson(_successfulJson(response));
  }

  Future<void> deleteOwn({required String courseId}) async {
    final token = await _tokenStore.read();
    if (token == null || token.isEmpty) {
      throw const FeedbackException('There is no saved feedback to delete.');
    }
    final response = await _response(
      _httpClient.delete(
        _uri('/v1/courses/${Uri.encodeComponent(courseId)}/feedback/mine'),
        headers: _headers(token: token),
      ),
    );
    if (response.statusCode != 204) _successfulJson(response);
  }

  Future<void> report({
    required String feedbackId,
    required String courseId,
    String? reason,
  }) async {
    final body = jsonEncode(<String, Object?>{'reason': reason?.trim()});
    var token = await _installationToken();
    final course = Uri.encodeComponent(courseId);
    final feedback = Uri.encodeComponent(feedbackId);
    var response = await _response(
      _httpClient.post(
        _uri('/v1/courses/$course/feedback/$feedback/reports'),
        headers: _headers(token: token),
        body: body,
      ),
    );
    if (response.statusCode == 401) {
      await _tokenStore.clear();
      token = await _installationToken();
      response = await _response(
        _httpClient.post(
          _uri('/v1/courses/$course/feedback/$feedback/reports'),
          headers: _headers(token: token),
          body: body,
        ),
      );
    }
    _successfulJson(response);
  }

  Future<String> _installationToken() async {
    final existing = await _tokenStore.read();
    if (existing != null && existing.isNotEmpty) return existing;
    final response = await _response(
      _httpClient.post(_uri('/v1/installations'), headers: _headers()),
    );
    final json = _successfulJson(response);
    final token = json['installation_token']?.toString() ?? '';
    if (token.length < 32) {
      throw const FeedbackException(
        'The feedback service returned an invalid installation token.',
      );
    }
    await _tokenStore.write(token);
    return token;
  }

  Uri _uri(String path) {
    final baseUri = _baseUri;
    if (baseUri == null) {
      throw const FeedbackException('Feedback is not configured yet.');
    }
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    return baseUri.replace(path: '$basePath$relativePath');
  }

  Map<String, String> _headers({String? token}) => <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<http.Response> _response(Future<http.Response> request) async {
    try {
      return await request.timeout(requestTimeout);
    } on TimeoutException {
      throw const FeedbackException('The feedback service timed out.');
    } on http.ClientException {
      throw const FeedbackException('The feedback service is unreachable.');
    }
  }

  Map<String, Object?> _successfulJson(http.Response response) {
    Map<String, Object?> json = const <String, Object?>{};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) json = Map<String, Object?>.from(decoded);
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw const FeedbackException(
            'The feedback service returned an invalid response.',
          );
        }
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawDetail = json['detail']?.toString().trim();
      final detail = rawDetail != null && rawDetail.length > 240
          ? '${rawDetail.substring(0, 237)}...'
          : rawDetail;
      throw FeedbackException(
        detail == null || detail.isEmpty
            ? 'Feedback failed with HTTP ${response.statusCode}.'
            : detail,
      );
    }
    return json;
  }

  static Uri? _parseBaseUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final loopback =
        uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
    if (uri.scheme != 'https' && !(loopback && uri.scheme == 'http')) {
      return null;
    }
    return uri;
  }
}

class FeedbackException implements Exception {
  const FeedbackException(this.message);

  final String message;

  @override
  String toString() => message;
}
