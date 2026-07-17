import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/course_catalog_client.dart';

void main() {
  test(
    'searches the ratings service catalog proxy and parses courses',
    () async {
      late http.Request captured;
      final client = CourseCatalogClient(
        baseUrl: 'https://feedback.studyos.test',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(<String, Object?>{
              'courses': <Object?>[
                <String, Object?>{
                  'courseId': '598',
                  'ratingCourseId': 'SU5GTTEyMzQ',
                  'courseNumber': 'INFM1234',
                  'title': 'Machine Learning',
                  'periodLabel': 'Sommer 2026',
                  'ects': 6.0,
                  'lecturer': 'Ada Example',
                  'types': <String>['Lecture'],
                },
              ],
            }),
            200,
          );
        }),
      );

      final courses = await client.search('machine learning');

      expect(captured.method, 'POST');
      expect(captured.url.path, '/v1/courses/search');
      expect(captured.body, contains('machine learning'));
      expect(courses.single.courseNumber, 'INFM1234');
      expect(courses.single.ratingCourseId, 'SU5GTTEyMzQ');
    },
  );

  test('does not call the catalog for a one-character query', () async {
    final client = CourseCatalogClient(
      baseUrl: 'https://feedback.studyos.test',
      httpClient: MockClient((_) async => throw StateError('not expected')),
    );

    expect(await client.search('x'), isEmpty);
  });
}
