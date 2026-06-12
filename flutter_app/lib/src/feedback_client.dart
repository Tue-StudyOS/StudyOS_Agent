import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const studyOsFeedbackRepository = 'Tue-StudyOS/StudyOS_Agent';

class FeedbackCredentialStore {
  FeedbackCredentialStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _tokenKey = 'studyos.feedback.githubToken.v1';

  final FlutterSecureStorage _secureStorage;

  Future<String?> readToken() {
    return _secureStorage.read(key: _tokenKey);
  }

  Future<void> saveToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;
    await _secureStorage.write(key: _tokenKey, value: trimmed);
  }
}

class FeedbackClient {
  FeedbackClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<void> submit({
    required String token,
    required String message,
    required String status,
    String repository = studyOsFeedbackRepository,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw const FeedbackException('Write a short feedback note first.');
    }
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) {
      throw const FeedbackException('Add a GitHub issue token first.');
    }
    if (!repository.contains('/')) {
      throw const FeedbackException('Feedback repository is invalid.');
    }

    final response = await _httpClient.post(
      Uri.https('api.github.com', '/repos/$repository/issues'),
      headers: <String, String>{
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $trimmedToken',
        'Content-Type': 'application/json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      body: jsonEncode(<String, Object?>{
        'title': _titleFrom(trimmedMessage),
        'body': _bodyFrom(trimmedMessage, status),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FeedbackException(
        'Feedback failed with HTTP ${response.statusCode}.',
      );
    }
  }

  String _bodyFrom(String message, String status) {
    final buffer = StringBuffer()
      ..writeln(message)
      ..writeln()
      ..writeln('---')
      ..writeln('- Source: StudyOS mobile app');
    final trimmedStatus = status.trim();
    if (trimmedStatus.isNotEmpty) {
      buffer.writeln('- App status: $trimmedStatus');
    }
    return buffer.toString().trimRight();
  }

  String _titleFrom(String message) {
    final firstLine = message.split('\n').first.trim();
    if (firstLine.length <= 72) return firstLine;
    return '${firstLine.substring(0, 69)}...';
  }
}

class FeedbackException implements Exception {
  const FeedbackException(this.message);

  final String message;

  @override
  String toString() => message;
}
