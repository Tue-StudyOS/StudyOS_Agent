import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/feedback_client.dart';

void main() {
  test('feedback client creates a GitHub issue directly', () async {
    late Uri requestUri;
    late String authorization;
    late String requestBody;
    final client = FeedbackClient(
      httpClient: MockClient((request) async {
        requestUri = request.url;
        authorization = request.headers['Authorization'] ?? '';
        requestBody = request.body;
        return http.Response('{}', 201);
      }),
    );

    await client.submit(
      token: 'github-token',
      message: 'Mensa widget would be useful',
      status: 'Ready',
    );

    expect(requestUri.host, 'api.github.com');
    expect(requestUri.path, '/repos/Tue-StudyOS/StudyOS_Agent/issues');
    expect(authorization, 'Bearer github-token');
    expect(requestBody, contains('Mensa widget would be useful'));
    expect(requestBody, contains('StudyOS mobile app'));
  });

  test('feedback client rejects missing token', () async {
    final client = FeedbackClient();

    expect(
      () => client.submit(token: '', message: 'Hello', status: 'Ready'),
      throwsA(isA<FeedbackException>()),
    );
  });
}
