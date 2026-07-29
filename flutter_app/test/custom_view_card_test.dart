import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/generated_ui_message.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/widgets/custom_view_card.dart';
import 'package:studyos_agent/src/widgets/message_list.dart';

void main() {
  GeneratedUiComponent componentFor(List<Object?> blocks) {
    final validation = GenerativeUiRegistry.validate(<String, Object?>{
      'type': 'custom_view',
      'title': 'View',
      'body': 'Body',
      'arguments': <String, Object?>{'blocks': blocks},
    });
    expect(
      validation.component,
      isNotNull,
      reason: validation.errors.join(', '),
    );
    return validation.component!;
  }

  Widget host(
    GeneratedUiComponent component, {
    ValueChanged<GeneratedComponentAction>? onAction,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CustomViewCard(component: component, onAction: onAction),
        ),
      ),
    );
  }

  testWidgets('renders text-bearing leaf nodes', (tester) async {
    await tester.pumpWidget(
      host(
        componentFor(<Object?>[
          <String, Object?>{'node': 'heading', 'text': 'My heading'},
          <String, Object?>{'node': 'paragraph', 'text': 'A paragraph.'},
          <String, Object?>{
            'node': 'bullets',
            'items': <String>['First point', 'Second point'],
          },
        ]),
      ),
    );

    expect(find.text('My heading'), findsOneWidget);
    expect(find.text('A paragraph.'), findsOneWidget);
    expect(find.text('First point'), findsOneWidget);
    expect(find.text('Second point'), findsOneWidget);
  });

  testWidgets('renders a table with headers and cells', (tester) async {
    await tester.pumpWidget(
      host(
        componentFor(<Object?>[
          <String, Object?>{
            'node': 'table',
            'columns': <String>['Aspect', 'A', 'B'],
            'rows': <List<String>>[
              <String>['Cost', 'Low', 'High'],
            ],
          },
        ]),
      ),
    );

    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Aspect'), findsOneWidget);
    expect(find.text('Cost'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
  });

  testWidgets('renders ragged table rows without crashing', (tester) async {
    await tester.pumpWidget(
      host(
        componentFor(<Object?>[
          <String, Object?>{
            'node': 'table',
            'columns': <String>['One', 'Two', 'Three'],
            'rows': <Object?>[
              <String>['only-one'], // short row is padded
              <String>['a', 'b', 'c', 'd'], // long row is truncated
              'not-a-row', // skipped
            ],
          },
        ]),
      ),
    );

    expect(find.byType(Table), findsOneWidget);
    expect(find.text('only-one'), findsOneWidget);
    expect(find.text('d'), findsNothing);
  });

  testWidgets('renders stats, badges, key_values and divider', (tester) async {
    await tester.pumpWidget(
      host(
        componentFor(<Object?>[
          <String, Object?>{
            'node': 'stats',
            'items': <Map<String, Object?>>[
              <String, Object?>{'value': '42', 'label': 'Points'},
            ],
          },
          <String, Object?>{
            'node': 'badges',
            'items': <Map<String, Object?>>[
              <String, Object?>{'text': 'Urgent', 'tone': 'warning'},
            ],
          },
          <String, Object?>{
            'node': 'key_values',
            'rows': <Map<String, Object?>>[
              <String, Object?>{'label': 'Due', 'value': 'Friday'},
            ],
          },
          <String, Object?>{'node': 'divider'},
        ]),
      ),
    );

    expect(find.text('42'), findsOneWidget);
    expect(find.text('Points'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('Due'), findsOneWidget);
    expect(find.text('Friday'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('skips unknown and malformed nodes but keeps valid ones', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        componentFor(<Object?>[
          <String, Object?>{'node': 'mystery_widget', 'text': 'nope'},
          <String, Object?>{'node': 'bullets'}, // no items → skipped
          <String, Object?>{'node': 'paragraph', 'text': 'Survivor'},
        ]),
      ),
    );

    expect(find.text('nope'), findsNothing);
    expect(find.text('Survivor'), findsOneWidget);
  });

  testWidgets('renders a nested group indented', (tester) async {
    await tester.pumpWidget(
      host(
        componentFor(<Object?>[
          <String, Object?>{
            'node': 'group',
            'blocks': <Map<String, Object?>>[
              <String, Object?>{'node': 'paragraph', 'text': 'Inside group'},
            ],
          },
        ]),
      ),
    );

    expect(find.text('Inside group'), findsOneWidget);
  });

  testWidgets('a button with a prompt action dispatches it', (tester) async {
    GeneratedComponentAction? action;
    await tester.pumpWidget(
      host(
        componentFor(<Object?>[
          <String, Object?>{
            'node': 'button',
            'label': 'Explain',
            'action': <String, Object?>{
              'type': 'prompt',
              'prompt': 'Explain option A.',
            },
          },
        ]),
        onAction: (value) => action = value,
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Explain'));
    await tester.pump();
    expect(action, isA<PromptComponentAction>());
    expect((action! as PromptComponentAction).prompt, 'Explain option A.');
  });

  testWidgets('a button with a reminder action dispatches it', (tester) async {
    GeneratedComponentAction? action;
    await tester.pumpWidget(
      host(
        componentFor(<Object?>[
          <String, Object?>{
            'node': 'button',
            'label': 'Remind me',
            'action': <String, Object?>{
              'type': 'reminder',
              'title': 'Submit sheet',
              'due': '2026-07-30T18:00:00',
            },
          },
        ]),
        onAction: (value) => action = value,
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Remind me'));
    await tester.pump();
    expect(action, isA<ReminderComponentAction>());
    expect((action! as ReminderComponentAction).title, 'Submit sheet');
  });

  testWidgets('a button with a map action dispatches it', (tester) async {
    GeneratedComponentAction? action;
    await tester.pumpWidget(
      host(
        componentFor(<Object?>[
          <String, Object?>{
            'node': 'button',
            'label': 'Open map',
            'action': <String, Object?>{
              'type': 'map',
              'name': 'Library',
              'latitude': 48.5296,
              'longitude': 9.0596,
            },
          },
        ]),
        onAction: (value) => action = value,
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Open map'));
    await tester.pump();
    expect(action, isA<MapComponentAction>());
    expect((action! as MapComponentAction).name, 'Library');
  });

  testWidgets('a button with an unknown action type is dropped', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        componentFor(<Object?>[
          <String, Object?>{
            'node': 'button',
            'label': 'Danger',
            'action': <String, Object?>{'type': 'delete_everything'},
          },
          <String, Object?>{'node': 'paragraph', 'text': 'Safe content'},
        ]),
      ),
    );

    expect(find.text('Danger'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('Safe content'), findsOneWidget);
  });

  testWidgets('renderer stops at the depth guard on an over-nested tree', (
    tester,
  ) async {
    // Built directly, bypassing validation, to prove the renderer guards depth
    // even if an invalid tree reaches it.
    Map<String, Object?> group(Map<String, Object?> child) => <String, Object?>{
      'node': 'group',
      'blocks': <Map<String, Object?>>[child],
    };
    var deep = <String, Object?>{'node': 'paragraph', 'text': 'DEEPLEAF'};
    for (var i = 0; i < 6; i++) {
      deep = group(deep);
    }
    final component = GeneratedUiComponent(
      kind: GeneratedComponentKind.customView,
      title: 'View',
      body: 'Body',
      arguments: <String, Object?>{
        'blocks': <Object?>[
          <String, Object?>{'node': 'paragraph', 'text': 'SHALLOW'},
          deep,
        ],
      },
    );

    await tester.pumpWidget(host(component));

    expect(find.text('SHALLOW'), findsOneWidget);
    expect(find.text('DEEPLEAF'), findsNothing);
  });

  testWidgets('end to end: a ui block parses, validates and renders', (
    tester,
  ) async {
    const raw =
        'Here is a comparison:\n'
        '```ui\n'
        '{"type":"custom_view","title":"Compare","body":"A vs B",'
        '"arguments":{"blocks":[{"node":"paragraph","text":"End to end works."}]}}\n'
        '```';
    final parts = splitAssistantComponent(raw);
    expect(parts.text, 'Here is a comparison:');
    expect(parts.component, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageList(
            messages: <ChatMessage>[
              ChatMessage(
                author: 'StudyOS Agent',
                text: parts.text,
                isUser: false,
                component: parts.component,
              ),
            ],
            compact: false,
            controller: ScrollController(),
          ),
        ),
      ),
    );

    expect(find.byType(CustomViewCard), findsOneWidget);
    expect(find.text('End to end works.'), findsOneWidget);
    expect(find.text('Here is a comparison:'), findsOneWidget);
  });
}
