import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/map_location_models.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/widgets/maps_controls.dart';

void main() {
  testWidgets('map overlay shows selected result without map actions', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    var searched = false;
    var selected = false;
    addTearDown(controller.dispose);

    const location = MapLocation(
      name: 'Mensa Morgenstelle',
      latitude: 48.53882,
      longitude: 9.03531,
      address: 'Mensa Morgenstelle, Tuebingen, Germany',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MapOverlay(
              controller: controller,
              results: const <MapLocation>[location],
              selectedLocation: location,
              isSearching: false,
              searchError: null,
              hasSearched: true,
              onSearch: () => searched = true,
              onSelect: (_) => selected = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Where to?'), findsOneWidget);
    expect(find.text('Mensa Morgenstelle'), findsOneWidget);
    expect(find.textContaining('Tuebingen, Germany'), findsNothing);
    expect(find.text('Ask AI'), findsNothing);
    expect(find.text('Open in maps'), findsNothing);

    await tester.tap(find.text('Mensa Morgenstelle'));
    await tester.tap(find.byTooltip('Search destination'));

    expect(selected, isTrue);
    expect(searched, isTrue);
  });

  testWidgets('map overlay hides assistant action before selecting a result', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    const location = MapLocation(
      name: 'Neue Aula',
      latitude: 48.52562,
      longitude: 9.05989,
      address: 'Neue Aula, Tuebingen, Germany',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MapOverlay(
              controller: controller,
              results: const <MapLocation>[location],
              selectedLocation: null,
              isSearching: false,
              searchError: null,
              hasSearched: true,
              onSearch: () {},
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Neue Aula'), findsOneWidget);
    expect(find.text('Ask AI'), findsNothing);
    expect(find.text('Open in maps'), findsNothing);
  });
}
