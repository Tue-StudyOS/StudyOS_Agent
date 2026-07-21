import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/capability_result.dart';
import 'package:studyos_agent/src/campus_client.dart';
import 'package:studyos_agent/src/map_search_client.dart';
import 'package:studyos_agent/src/public_study_capabilities.dart';
import 'package:studyos_agent/src/public_study_tools.dart';

void main() {
  test('get_mensa_options filters live menus and returns metadata', () async {
    var calls = 0;
    final now = DateTime.utc(2026, 7, 17, 12);
    final runner = _runner(
      now: () => now,
      campusClient: MockClient((request) async {
        calls += 1;
        expect(request.url, CampusClient.sourceUri);
        return http.Response(_mensaPayload, 200, request: request);
      }),
    );
    addTearDown(runner.close);

    final first = _json(
      await runner.execute(
        getMensaOptionsToolName,
        '{"date":"2026-07-18","preference":"vegan","limit":1}',
      ),
    );
    final second = _json(
      await runner.execute(getMensaOptionsToolName, '{"limit":2}'),
    );

    expect(first['state'], 'fresh');
    expect(_policy(first)['privacy'], 'public_external');
    expect(_source(first)['id'], 'my_stuwe_mensa');
    expect(_data(first), hasLength(1));
    expect(_data(first).single['canteen'], 'Mensa Wilhelmstraße');
    expect(_data(first).single['dietary_markers'], contains('vegan'));
    expect(_data(second), hasLength(2));
    expect(calls, 1, reason: 'the second tool call should reuse the TTL cache');
  });

  test('get_mensa_options serves stale cache when refresh fails', () async {
    var now = DateTime.utc(2026, 7, 17, 12);
    var calls = 0;
    final runner = _runner(
      now: () => now,
      campusClient: MockClient((request) async {
        calls += 1;
        return calls == 1
            ? http.Response(_mensaPayload, 200, request: request)
            : http.Response('upstream unavailable', 503, request: request);
      }),
    );
    addTearDown(runner.close);

    await runner.execute(getMensaOptionsToolName, '{}');
    now = now.add(const Duration(minutes: 16));
    final stale = _json(await runner.execute(getMensaOptionsToolName, '{}'));

    expect(stale['state'], 'stale');
    expect(_data(stale), isNotEmpty);
    expect(stale['message'], contains('HTTP 503'));
  });

  test('search_campus_locations returns bounded stable results', () async {
    Uri? requestedUri;
    final runner = _runner(
      now: () => DateTime.utc(2026, 7, 17, 12),
      mapClient: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode(<Object?>[
            <String, Object?>{
              'display_name': 'Neue Aula, Geschwister-Scholl-Platz, Tübingen',
              'lat': '48.52942',
              'lon': '9.04339',
              'type': 'university',
            },
            <String, Object?>{
              'display_name': 'Universitätsbibliothek, Tübingen',
              'lat': '48.52900',
              'lon': '9.04500',
              'type': 'library',
            },
          ]),
          200,
          request: request,
        );
      }),
    );
    addTearDown(runner.close);

    final result = _json(
      await runner.execute(
        searchCampusLocationsToolName,
        '{"query":"Neue Aula","limit":1}',
      ),
    );

    expect(result['state'], 'fresh');
    expect(_source(result)['id'], 'openstreetmap_nominatim');
    expect(_data(result), hasLength(1));
    expect(_data(result).single['id'], 'nominatim:48.529420,9.043390');
    expect(requestedUri!.queryParameters['bounded'], '1');
    expect(requestedUri!.queryParameters['q'], 'Neue Aula Tuebingen');
    expect(requestedUri!.queryParameters, isNot(contains('lat')));
    expect(requestedUri!.queryParameters, isNot(contains('lon')));
  });

  test(
    'public tools return explicit failed states for invalid input',
    () async {
      final runner = _runner(now: DateTime.now);
      addTearDown(runner.close);

      final badDate = _json(
        await runner.execute(getMensaOptionsToolName, '{"date":"2026-02-30"}'),
      );
      final badLocation = _json(
        await runner.execute(searchCampusLocationsToolName, '{bad json'),
      );

      expect(badDate['state'], 'failed');
      expect(badDate['message'], contains('YYYY-MM-DD'));
      expect(badLocation['state'], 'failed');
      expect(badLocation['message'], contains('JSON object'));
    },
  );

  test('capability error messages redact credential-shaped values', () {
    expect(
      boundedCapabilityMessage(
        'request failed password=hunter2 cookie=session-secret '
        'token=abc Bearer def',
      ),
      'request failed password=[redacted] cookie=[redacted] '
      'token=[redacted] Bearer [redacted]',
    );
  });
}

LivePublicStudyToolRunner _runner({
  required DateTime Function() now,
  http.Client? campusClient,
  http.Client? mapClient,
}) {
  return LivePublicStudyToolRunner(
    mensa: MensaOptionsCapability(
      client: CampusClient(httpClient: campusClient ?? MockClient(_emptyMensa)),
      clock: now,
    ),
    locations: CampusLocationCapability(
      client: MapSearchClient(client: mapClient ?? MockClient(_emptyLocations)),
      clock: now,
    ),
  );
}

Future<http.Response> _emptyMensa(http.Request request) async =>
    http.Response('{}', 200, request: request);

Future<http.Response> _emptyLocations(http.Request request) async =>
    http.Response('[]', 200, request: request);

Map<String, Object?> _json(String value) =>
    Map<String, Object?>.from(jsonDecode(value) as Map);

Map<String, Object?> _policy(Map<String, Object?> result) =>
    Map<String, Object?>.from(result['policy'] as Map);

Map<String, Object?> _source(Map<String, Object?> result) =>
    Map<String, Object?>.from(result['source'] as Map);

List<Map<String, Object?>> _data(Map<String, Object?> result) =>
    (result['data'] as List)
        .map((item) => Map<String, Object?>.from(item as Map))
        .toList();

final _mensaPayload = jsonEncode(<String, Object?>{
  '611': <String, Object?>{
    'canteen': 'Mensa Wilhelmstraße',
    'menus': <Object?>[
      <String, Object?>{
        'id': 'vegan-1',
        'menuLine': 'Vegan',
        'menuDate': '2026-07-18',
        'menu': <String>['Lentil curry'],
        'icons': <String>['vegan'],
        'studentPrice': '3,20',
      },
      <String, Object?>{
        'id': 'classic-1',
        'menuLine': 'Classic',
        'menuDate': '2026-07-18',
        'menu': <String>['Pasta'],
        'icons': <String>[],
        'studentPrice': '3,50',
      },
    ],
  },
});
