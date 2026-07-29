import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/studyos_tool_catalog.dart';

void main() {
  group('StudyOsToolSpec.toOpenApiFunctionDeclaration', () {
    test('wraps a no-argument tool with empty properties and required', () {
      final decl = readMemoriesTool.toOpenApiFunctionDeclaration();

      expect(decl['name'], 'read_memories');
      expect(decl['description'], isNotEmpty);
      final params = decl['parameters']! as Map<String, Object?>;
      expect(params['type'], 'object');
      expect(params['properties'], isEmpty);
      expect(params['required'], isEmpty);
    });

    test('carries JSON-schema properties and required for a tool with args', () {
      final decl = appendMemoryTool.toOpenApiFunctionDeclaration();

      expect(decl['name'], 'append_memory');
      final params = decl['parameters']! as Map<String, Object?>;
      final properties = params['properties']! as Map<String, Object?>;
      expect(properties.containsKey('text'), isTrue);
      final textSchema = properties['text']! as Map<String, Object?>;
      expect(textSchema['type'], 'string');
      expect(textSchema['description'], isNotEmpty);
      expect(params['required'], contains('text'));
    });

    test('every catalog tool serializes to valid, well-formed JSON', () {
      for (final tool in studyOsTools) {
        final json = tool.toOpenApiToolJson();
        final decoded = jsonDecode(json) as Map<String, Object?>;

        expect(decoded['name'], tool.name, reason: '${tool.name} name');
        final params = decoded['parameters']! as Map<String, Object?>;
        expect(params['type'], 'object', reason: '${tool.name} parameters.type');

        // Every declared required field must exist in properties.
        final properties = params['properties']! as Map<String, Object?>;
        final required = (params['required']! as List).cast<String>();
        for (final field in required) {
          expect(
            properties.containsKey(field),
            isTrue,
            reason: '${tool.name}: required "$field" missing from properties',
          );
        }
      }
    });
  });
}
