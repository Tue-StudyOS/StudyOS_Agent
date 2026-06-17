import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/map_location_models.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/widgets/maps_controls.dart';

void main() {
  testWidgets('map overlay keeps search and assistant actions at the bottom', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    var searched = false;
    var selected = false;
    var asked = false;
    var opened = false;
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

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
              focusNode: focusNode,
              results: const <MapLocation>[location],
              selectedLocation: location,
              isSearching: false,
              searchError: null,
              hasSearched: true,
              showAssistantAction: true,
              onSearch: () => searched = true,
              onSelect: (_) => selected = true,
              onAskAssistant: () => asked = true,
              onOpenExternalMaps: () => opened = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Where to?'), findsOneWidget);
    expect(find.text('Ask AI'), findsNothing);
    expect(find.byTooltip('Ask AI'), findsOneWidget);
    expect(find.text('Mensa Morgenstelle'), findsOneWidget);
    expect(find.textContaining('Tuebingen, Germany'), findsNothing);

    await tester.tap(find.text('Mensa Morgenstelle'));
    await tester.tap(find.byTooltip('Open in maps'));
    await tester.tap(find.byTooltip('Ask AI'));
    await tester.tap(find.byTooltip('Search destination'));

    expect(selected, isTrue);
    expect(opened, isTrue);
    expect(asked, isTrue);
    expect(searched, isTrue);
  });

  testWidgets(
    'map overlay hides the assistant action until search is focused',
    (WidgetTester tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildStudyOsTheme(),
          home: Scaffold(
            body: MapOverlay(
              controller: controller,
              focusNode: focusNode,
              results: const <MapLocation>[],
              selectedLocation: null,
              isSearching: false,
              searchError: null,
              hasSearched: false,
              showAssistantAction: false,
              onSearch: () {},
              onSelect: (_) {},
              onAskAssistant: () {},
              onOpenExternalMaps: () {},
            ),
          ),
        ),
      );

      expect(find.byTooltip('Ask AI'), findsNothing);
      expect(find.byTooltip('Search destination'), findsOneWidget);
    },
  );
}
