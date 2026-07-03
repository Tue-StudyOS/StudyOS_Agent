import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/prompt_context.dart';

void main() {
  test('system prompt allows direct answers when context is sufficient', () {
    final prompt = const PromptContext(
      profile: null,
      memory: 'Prefers compact summaries.',
      worldState: <String, Object?>{'platform': 'test'},
    ).systemPrompt();

    expect(
      prompt,
      contains(
        'Use StudyOS tools when current data, actions, or durable memory updates are needed',
      ),
    );
    expect(
      prompt,
      isNot(
        contains('Call at least one available StudyOS tool before answering.'),
      ),
    );
    expect(prompt, contains('call append_memory'));
  });
}
