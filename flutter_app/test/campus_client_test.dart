import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/campus_client.dart';
import 'package:studyos_agent/src/student_profile.dart';

void main() {
  test('campus client decodes Tübingen canteen menus', () async {
    final client = CampusClient(
      httpClient: MockClient((request) async {
        expect(request.url.host, 'www.my-stuwe.de');
        return http.Response(
          jsonEncode(<String, Object?>{
            '611': <String, Object?>{
              'canteenId': '611',
              'canteen': 'Mensa Wilhelmstraße',
              'menus': <Object?>[
                <String, Object?>{
                  'id': '516',
                  'menuLine': 'Tagesmenü vegan',
                  'menuDate': '2026-06-17',
                  'menu': <String>['Hackbällchen [vegan]', 'Cous-Cous'],
                  'icons': <String>['vegan'],
                  'filtersInclude': <String>['vegan'],
                  'studentPrice': '3,70',
                },
              ],
            },
          }),
          200,
          request: request,
        );
      }),
    );

    final canteens = await client.fetchTuebingenCanteens();
    final filtered = canteens.single.filteredFor(FoodPreference.vegan);

    expect(filtered.name, 'Mensa Wilhelmstraße');
    expect(filtered.menus.single.items, contains('Cous-Cous'));
    expect(filtered.menus.single.studentPrice, '3,70');
  });
}
