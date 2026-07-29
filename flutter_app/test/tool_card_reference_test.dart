import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/generated_ui_message.dart';

void main() {
  Map<String, Object?> plannerCard() => <String, Object?>{
    'type': 'study_progress',
    'title': 'M.Sc. Machine Learning',
    'body': '78 / 120 ECTS',
    'arguments': <String, Object?>{'modules': <Object?>[]},
  };

  Map<String, Map<String, Object?>> captured() =>
      <String, Map<String, Object?>>{'get_study_planner': plannerCard()};

  group('resolveComponentPayload', () {
    test('a tool_card reference resolves to the captured tool payload', () {
      final resolved = resolveComponentPayload(<String, Object?>{
        'type': 'tool_card',
        'tool': 'get_study_planner',
      }, captured());
      expect(resolved, plannerCard());
    });

    test('a reference to a tool not called this turn resolves to null', () {
      final resolved = resolveComponentPayload(<String, Object?>{
        'type': 'tool_card',
        'tool': 'get_recent_mail',
      }, captured());
      expect(resolved, isNull);
    });

    test('a tool_card reference without a tool name resolves to null', () {
      expect(
        resolveComponentPayload(<String, Object?>{
          'type': 'tool_card',
        }, captured()),
        isNull,
      );
    });

    test('a composed A/B component passes through unchanged', () {
      final quickReply = <String, Object?>{
        'type': 'quick_reply',
        'title': 'Suggestion',
        'body': 'Plan?',
        'arguments': <String, Object?>{'reply': 'Plan a block.'},
      };
      expect(resolveComponentPayload(quickReply, captured()), quickReply);
    });

    test('null stays null', () {
      expect(resolveComponentPayload(null, captured()), isNull);
    });
  });

  group('end to end split + resolve', () {
    test('an explicit tool_card reference surfaces the captured card', () {
      const raw =
          'Here is your study progress:\n'
          '```ui\n'
          '{"type":"tool_card","tool":"get_study_planner"}\n'
          '```';
      final parts = splitAssistantComponent(raw);
      final component = resolveComponentPayload(parts.component, captured());

      expect(parts.text, 'Here is your study progress:');
      expect(component, plannerCard());
    });

    test(
      'a pivot reply that ran the tool but omits the block shows no card',
      () {
        // The model called get_study_planner while answering something else and
        // did not reference it — the decoupling fix: no card, full text kept.
        const raw =
            'The Mensa has Gemüse-Lasagne and Rindergulasch today. '
            'Both are available at lunch.';
        final parts = splitAssistantComponent(raw);
        final component = resolveComponentPayload(parts.component, captured());

        expect(parts.text, raw);
        expect(component, isNull);
      },
    );
  });

  group('isPresentationalLeadIn', () {
    test('a short single-line lead-in is presentational', () {
      expect(
        isPresentationalLeadIn('Here is the breakdown of requirements:'),
        isTrue,
      );
    });

    test('a two-line lead-in is still presentational', () {
      expect(isPresentationalLeadIn('Here you go:\nTake a look:'), isTrue);
    });

    test('a long multi-sentence answer is not a lead-in', () {
      expect(
        isPresentationalLeadIn(
          'Managing first-semester stress starts with a routine. Block fixed '
          'study hours, take real breaks, and keep your sleep steady. Talk to '
          'peers and the student counselling service if it builds up.',
        ),
        isFalse,
      );
    });

    test('empty or whitespace text is not a lead-in', () {
      expect(isPresentationalLeadIn('   \n  '), isFalse);
    });
  });

  group('resolveMessageComponent', () {
    Map<String, Object?>? resolve(
      String reply, {
      Map<String, Object?>? emitted,
      Map<String, Map<String, Object?>>? capturedComponents,
    }) {
      return resolveMessageComponent(
        emitted: emitted,
        capturedToolComponents: capturedComponents ?? captured(),
        replyText: reply,
      );
    }

    test('a lead-in with a captured tool card shows the most recent one', () {
      expect(resolve('Here is your study progress:'), plannerCard());
    });

    test('a long pivot answer shows no card even though a tool ran', () {
      expect(
        resolve(
          'You are in your first semester, so focus on building good habits '
          'early: attend every lecture, start assignments the day they are set, '
          'and review notes weekly rather than cramming before exams.',
        ),
        isNull,
      );
    });

    test('a lead-in with no captured tool card shows nothing', () {
      expect(
        resolve(
          'Here is your study progress:',
          capturedComponents: <String, Map<String, Object?>>{},
        ),
        isNull,
      );
    });

    test('a composed A/B component always wins', () {
      final quickReply = <String, Object?>{
        'type': 'quick_reply',
        'title': 'Suggestion',
        'body': 'Plan?',
        'arguments': <String, Object?>{'reply': 'Plan a block.'},
      };
      expect(resolve('A full answer.', emitted: quickReply), quickReply);
    });

    test('a bad reference falls back to the lead-in card', () {
      // Model referenced a tool it did not call, but the reply is a lead-in and
      // a card was captured — robustness fallback surfaces it anyway.
      expect(
        resolve(
          'Here is your progress:',
          emitted: <String, Object?>{
            'type': 'tool_card',
            'tool': 'get_recent_mail',
          },
        ),
        plannerCard(),
      );
    });

    test('the most recent tool of several is shown for a bare lead-in', () {
      final mailCard = <String, Object?>{
        'type': 'mail_list',
        'title': 'INBOX',
        'body': '1 message',
        'arguments': <String, Object?>{'messages': <Object?>[]},
      };
      final ordered = <String, Map<String, Object?>>{
        'get_study_planner': plannerCard(),
        'get_recent_mail': mailCard,
      };
      expect(resolve('Here you go:', capturedComponents: ordered), mailCard);
    });
  });
}
