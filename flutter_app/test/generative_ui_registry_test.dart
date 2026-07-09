import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';

void main() {
  test('fixture payloads validate for every supported component kind', () {
    final validatedKinds = <GeneratedComponentKind>{};

    for (final payload in generativeUiFixturePayloads) {
      final validation = GenerativeUiRegistry.validate(payload);
      expect(validation.errors, isEmpty);
      expect(validation.component, isNotNull);
      validatedKinds.add(validation.component!.kind);
    }

    expect(validatedKinds, GeneratedComponentKind.values.toSet());
  });

  test('registry rejects unknown component types and missing arguments', () {
    final unknown = GenerativeUiRegistry.validate(<String, Object?>{
      'type': 'freeform_screen',
      'title': 'Unsafe',
      'body': 'Do anything',
    });
    expect(unknown.isValid, isFalse);
    expect(unknown.errors.single, contains('Unsupported component type'));

    final missingArgument = GenerativeUiRegistry.validate(<String, Object?>{
      'type': 'route_hint',
      'title': 'Route',
      'body': 'Leave now',
      'arguments': <String, Object?>{'destination': 'Library'},
    });
    expect(missingArgument.isValid, isFalse);
    expect(missingArgument.errors, contains('Missing string argument: mode'));
  });

  test('registry rejects non-object arguments', () {
    final validation = GenerativeUiRegistry.validate(<String, Object?>{
      'type': 'quick_reply',
      'title': 'Reply',
      'body': 'Ask',
      'arguments': 'reply=hello',
    });

    expect(validation.isValid, isFalse);
    expect(
      validation.errors,
      contains('Field arguments must be an object when present'),
    );
  });
}
