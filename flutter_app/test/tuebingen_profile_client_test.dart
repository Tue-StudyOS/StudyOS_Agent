import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/tuebingen_profile_client.dart';

void main() {
  test('parses confirmed ALMA profile fields', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('hisinoneStartPage.faces')) {
        return http.Response(
          '''
          <form id="loginForm" action="/alma/rds">
            <input name="csrf" value="token">
          </form>
          ''',
          200,
          headers: <String, String>{'set-cookie': 'JSESSIONID=start; Path=/'},
          request: request,
        );
      }
      if (request.url.path.endsWith('/alma/rds')) {
        return http.Response(
          '<html>authenticated</html>',
          200,
          headers: <String, String>{
            'set-cookie': 'oam.Flash.RENDERMAP.TOKEN=render; Path=/',
          },
          request: request,
        );
      }
      if (request.url.path.endsWith('/enrollment/info/start.xhtml')) {
        return http.Response(
          '''
          <form id="studyserviceForm">
            <h2>Personendaten: Ada Lovelace</h2>
          </form>
          ''',
          200,
          request: request,
        );
      }
      if (request.url.query.contains('studyPlanner-flow')) {
        return http.Response(
          '''
          <html>
            <head>
              <title>
                Studienplaner Master Informatik / Computer Science (H-2021-7) - Eberhard Karls Universität Tübingen
              </title>
            </head>
          </html>
          ''',
          200,
          request: request,
        );
      }
      return http.Response('not found', 404, request: request);
    });
    final profileClient = TuebingenProfileClient(httpClient: client);

    final profile = await profileClient.fetch(
      username: 'zxabc12',
      password: 'secret',
    );

    expect(profile.displayName, 'Ada Lovelace');
    expect(profile.email, isNull);
    expect(profile.degreeProgram, 'Master Informatik / Computer Science');
    expect(profile.warning, isNull);
  });
}
