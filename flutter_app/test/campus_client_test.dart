import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyos_agent/src/campus_client.dart';
import 'package:studyos_agent/src/campus_models.dart';
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

  test('campus menus are flattened and sorted by closest date first', () {
    final canteens = <CampusCanteen>[
      CampusCanteen(
        id: '621',
        name: 'Mensa Morgenstelle',
        menus: <CampusMenu>[
          _menu(id: 'later', date: '2026-07-07', item: 'Pasta'),
        ],
      ),
      CampusCanteen(
        id: '611',
        name: 'Mensa Wilhelmstraße',
        menus: <CampusMenu>[
          _menu(id: 'soon', date: '2026-07-03', item: 'Curry'),
          _menu(id: 'unknown', date: '', item: 'Salad'),
        ],
      ),
    ];

    final entries = sortedCampusMenuEntries(canteens);

    expect(entries.map((entry) => entry.menu.id), <String>[
      'soon',
      'later',
      'unknown',
    ]);
  });

  test('known Tübingen canteens expose website and navigation actions', () {
    final wilhelm = actionForCanteen(
      CampusCanteen(
        id: '611',
        name: 'Mensa Wilhelmstraße',
        menus: <CampusMenu>[_menu(id: '1', date: '2026-07-03')],
      ),
    );
    final morgenstelle = actionForCanteen(
      CampusCanteen(
        id: '621',
        name: 'Mensa Morgenstelle',
        menus: <CampusMenu>[_menu(id: '2', date: '2026-07-03')],
      ),
    );
    final prinzKarl = actionForCanteen(
      CampusCanteen(
        id: '623',
        name: 'Mensa Prinz Karl',
        menus: <CampusMenu>[_menu(id: '3', date: '2026-07-03')],
      ),
    );

    expect(wilhelm?.website.toString(), contains('mensa-wilhelmstrasse'));
    expect(morgenstelle?.website.toString(), contains('mensa-morgenstelle'));
    expect(prinzKarl?.website.toString(), contains('mensa-prinz-karl'));
    expect(wilhelm?.navigation.host, 'www.google.com');
  });
}

CampusMenu _menu({
  required String id,
  required String date,
  String item = 'Meal',
}) {
  return CampusMenu(
    id: id,
    line: 'Tagesmenü',
    date: date,
    items: <String>[item],
    icons: const <String>[],
    studentPrice: '3,70',
  );
}
