import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';

void main() {
  GeneratedUiValidation validateBlocks(Object? blocks) {
    return GenerativeUiRegistry.validate(<String, Object?>{
      'type': 'custom_view',
      'title': 'View',
      'body': 'Body',
      'arguments': <String, Object?>{'blocks': blocks},
    });
  }

  Map<String, Object?> leaf(String text) => <String, Object?>{
    'node': 'paragraph',
    'text': text,
  };

  // A chain of [n] nested groups, innermost holding a single leaf.
  Map<String, Object?> nestedGroups(int n) {
    Map<String, Object?> current = leaf('deep');
    for (var i = 0; i < n; i++) {
      current = <String, Object?>{
        'node': 'group',
        'blocks': <Map<String, Object?>>[current],
      };
    }
    return current;
  }

  test('the fixture custom_view validates', () {
    final fixture = generativeUiFixturePayloads.firstWhere(
      (payload) => payload['type'] == 'custom_view',
    );
    final validation = GenerativeUiRegistry.validate(fixture);
    expect(validation.errors, isEmpty);
    expect(validation.component, isNotNull);
    expect(validation.component!.kind, GeneratedComponentKind.customView);
  });

  test('rejects missing, empty, or non-list blocks', () {
    expect(validateBlocks(null).isValid, isFalse);
    expect(validateBlocks(<Object?>[]).isValid, isFalse);
    expect(validateBlocks('not a list').isValid, isFalse);
    expect(
      validateBlocks(null).errors.single,
      'Missing non-empty list argument: blocks',
    );
  });

  test('accepts a flat valid tree', () {
    final validation = validateBlocks(<Map<String, Object?>>[
      leaf('one'),
      leaf('two'),
    ]);
    expect(validation.errors, isEmpty);
    expect(validation.isValid, isTrue);
  });

  test('rejects a container with more than the child cap', () {
    final tooMany = <Map<String, Object?>>[
      for (var i = 0; i < customViewMaxChildrenPerContainer + 1; i++)
        leaf('n$i'),
    ];
    final validation = validateBlocks(tooMany);
    expect(validation.isValid, isFalse);
    expect(validation.errors.single, contains('children'));
  });

  test('rejects a tree past the total node cap', () {
    // 20 groups × (itself + 2 leaves) = 60 nodes, but no container exceeds the
    // child cap and nothing nests past depth 2 — isolating the node-count rule.
    final blocks = <Map<String, Object?>>[
      for (var i = 0; i < 20; i++)
        <String, Object?>{
          'node': 'group',
          'blocks': <Map<String, Object?>>[leaf('a$i'), leaf('b$i')],
        },
    ];
    final validation = validateBlocks(blocks);
    expect(validation.isValid, isFalse);
    expect(validation.errors.single, contains('nodes'));
  });

  test('depth exactly at the cap is allowed', () {
    // 3 nested groups → the leaf sits at depth 4 (== customViewMaxDepth).
    expect(customViewMaxDepth, 4);
    final validation = validateBlocks(<Map<String, Object?>>[nestedGroups(3)]);
    expect(validation.errors, isEmpty);
    expect(validation.isValid, isTrue);
  });

  test('nesting one level past the cap is rejected', () {
    final validation = validateBlocks(<Map<String, Object?>>[nestedGroups(4)]);
    expect(validation.isValid, isFalse);
    expect(validation.errors.single, contains('depth'));
  });
}
