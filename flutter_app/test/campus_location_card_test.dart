import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:studyos_agent/src/app_shell_controller.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/widgets/campus_location_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GeneratedUiComponent locationComponent() {
    final payload = generativeUiFixturePayloads.firstWhere(
      (payload) => payload['type'] == 'campus_locations',
    );
    return GenerativeUiRegistry.validate(payload).component!;
  }

  group('campusMapsUri', () {
    test('builds a Google Maps search deep link for coordinates', () {
      final uri = campusMapsUri(48.5296, 9.0596);
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['query'], '48.5296,9.0596');
    });
  });

  group('CampusLocationCard', () {
    testWidgets('renders places with address and category', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampusLocationCard(component: locationComponent()),
          ),
        ),
      );

      expect(find.text('2 places'), findsOneWidget);
      expect(find.text('Universitätsbibliothek Tübingen'), findsOneWidget);
      expect(find.text('library'), findsOneWidget);
    });

    testWidgets('Open in Maps emits a MapComponentAction with coordinates', (
      tester,
    ) async {
      final actions = <GeneratedComponentAction>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampusLocationCard(
              component: locationComponent(),
              onAction: actions.add,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open in Maps').first);
      await tester.pump();

      expect(actions, hasLength(1));
      final action = actions.single as MapComponentAction;
      expect(action.name, 'Universitätsbibliothek Tübingen');
      expect(action.latitude, 48.5296);
      expect(action.longitude, 9.0596);
    });
  });

  group('AppShellController maps dispatch', () {
    test('routes a map action to the injected url launcher', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = null);

      final launched = <Uri>[];
      final controller = AppShellController(
        initialProfile: null,
        initialOnLogout: null,
        initialOnSaveProfile: null,
        urlLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      );
      addTearDown(controller.dispose);

      controller.handleComponentAction(
        const MapComponentAction(
          name: 'Library',
          latitude: 48.5296,
          longitude: 9.0596,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(launched, hasLength(1));
      expect(launched.single.queryParameters['query'], '48.5296,9.0596');
    });
  });
}
