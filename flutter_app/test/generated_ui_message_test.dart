import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/generated_ui_message.dart';

void main() {
  group('splitAssistantComponent', () {
    test('returns the text unchanged when no ui block is present', () {
      const raw = 'Here is a plain answer with no card.';
      final parts = splitAssistantComponent(raw);
      expect(parts.text, raw);
      expect(parts.component, isNull);
    });

    test('extracts a trailing ui block and strips it from the text', () {
      const raw =
          'Sure, want a plan?\n'
          '```ui\n'
          '{"type":"quick_reply","title":"Suggestion","body":"Plan?",'
          '"arguments":{"reply":"Plan a review block."}}\n'
          '```';
      final parts = splitAssistantComponent(raw);
      expect(parts.text, 'Sure, want a plan?');
      expect(parts.component, isNotNull);
      expect(parts.component!['type'], 'quick_reply');
      final arguments = parts.component!['arguments'] as Map<String, Object?>;
      expect(arguments['reply'], 'Plan a review block.');
    });

    test('strips the block but attaches no component on invalid JSON', () {
      const raw =
          'Here you go.\n'
          '```ui\n'
          'not valid json {{{\n'
          '```';
      final parts = splitAssistantComponent(raw);
      expect(parts.text, 'Here you go.');
      expect(parts.component, isNull);
    });

    test('leaves a non-ui code fence untouched', () {
      const raw = 'Run this:\n```dart\nvoid main() {}\n```';
      final parts = splitAssistantComponent(raw);
      expect(parts.text, raw);
      expect(parts.component, isNull);
    });
  });

  group('streamingVisibleText', () {
    test('returns the text unchanged before an opener appears', () {
      const raw = 'Streaming answer so far';
      expect(streamingVisibleText(raw), raw);
    });

    test('hides everything from the ui fence opener onward', () {
      const raw = 'Visible answer\n```ui\n{"type":"quick_re';
      expect(streamingVisibleText(raw), 'Visible answer');
    });
  });
}
