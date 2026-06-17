import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/map_location_models.dart';

void main() {
  test('parses Nominatim locations and builds assistant prompt', () {
    final locations = mapLocationsFromNominatim('''
[
  {
    "display_name": "University Library, Wilhelmstraße, Tübingen",
    "lat": "48.525",
    "lon": "9.060",
    "type": "library"
  }
]
''');

    expect(locations, hasLength(1));
    final location = locations.single;
    expect(location.name, 'University Library');
    expect(location.coordinateText, '48.52500, 9.06000');

    final prompt = location.assistantPrompt();
    expect(prompt, contains('University Library'));
    expect(prompt, contains('48.52500, 9.06000'));
    expect(prompt, contains('navigation options'));
  });
}
