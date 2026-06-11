import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/onboarding_flow.dart';
import 'package:studyos_agent/src/prompt_context.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/views/chat_view.dart';
import 'package:studyos_agent/src/views/settings_view.dart';
import 'package:studyos_agent/src/widgets/app_drawer.dart';

void main() {
  testWidgets('chat view starts clean with suggestions and composer', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _TestShell(
        child: ChatView(
          messages: const <ChatMessage>[],
          inputController: controller,
          isSending: false,
          compactMessages: false,
          onSuggestionSelected: (value) => controller.text = value,
          onSend: () {},
        ),
      ),
    );

    expect(find.text('Summarize today'), findsOneWidget);
    expect(find.text('Find next lecture'), findsOneWidget);
    expect(find.text('Plan study block'), findsOneWidget);
    expect(find.text('Nachricht an Jarvis...'), findsOneWidget);
    expect(find.text('Native'), findsNothing);
    expect(find.textContaining('Ask about lectures'), findsNothing);
  });

  testWidgets('drawer exposes view icons and persisted chat sessions', (
    WidgetTester tester,
  ) async {
    final session = ChatSession.fresh().copyWith(title: 'Algorithms review');

    await tester.pumpWidget(
      _TestShell(
        child: AppDrawer(
          selectedView: AppView.chat,
          sessions: <ChatSession>[session],
          activeSessionId: session.id,
          onSelectView: (_) {},
          onSelectSession: (_) {},
          onCreateSession: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.psychology_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('New chat'), findsOneWidget);
    expect(find.text(session.title), findsOneWidget);
    expect(find.textContaining('Active ID:'), findsOneWidget);
    expect(find.text('Capabilities'), findsNothing);
    expect(find.text('World State'), findsNothing);
  });

  testWidgets('assistant messages render markdown content', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _TestShell(
        child: ChatView(
          messages: const <ChatMessage>[
            ChatMessage(
              author: 'StudyOS Agent',
              text: '**Summary** with _focus_',
              isUser: false,
            ),
          ],
          inputController: controller,
          isSending: false,
          compactMessages: false,
          onSuggestionSelected: (_) {},
          onSend: () {},
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is MarkdownBody && widget.data == '**Summary** with _focus_',
      ),
      findsOneWidget,
    );
  });

  testWidgets('settings expose cloud provider and secure key fields', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AgentConfig? savedConfig;
    String? savedKey;

    await tester.pumpWidget(
      _TestShell(
        child: SettingsView(
          config: const AgentConfig.defaults(),
          profile: null,
          status: 'Ready',
          compactMessages: false,
          onLogout: null,
          onSaveAgentConfig: (config, apiKey) async {
            savedConfig = config;
            savedKey = apiKey;
          },
          onCompactMessagesChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.cloud_outlined));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Cloud endpoint'),
      'https://api.example.com/v1/chat/completions',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Model'), 'studyos');
    await tester.enterText(find.widgetWithText(TextField, 'API key'), 'secret');
    final saveButton = find.widgetWithText(FilledButton, 'Save agent settings');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(savedConfig?.provider, AgentProvider.cloud);
    expect(savedConfig?.cloudModel, 'studyos');
    expect(savedKey, 'secret');
    expect(find.text('Stored with the platform secure store.'), findsOneWidget);
  });

  testWidgets('login and onboarding collect student profile context', (
    WidgetTester tester,
  ) async {
    UserSession? session;
    OnboardingProfile? profile;

    await tester.pumpWidget(
      _TestShell(
        child: LoginPage(
          onLogin: (value, _) async {
            session = value;
          },
        ),
      ),
    );

    expect(find.text('Connect your student workspace'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).at(0), 'zxabc12');
    await tester.enterText(find.byType(EditableText).at(1), 'local-secret');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(session?.username, 'zxabc12');

    await tester.pumpWidget(
      _TestShell(
        child: OnboardingPage(
          session: session!,
          onComplete: (value) => profile = value,
        ),
      ),
    );

    expect(find.text('Set up profile'), findsOneWidget);
    expect(find.text('zxabc12'), findsOneWidget);

    await tester.enterText(
      find.byType(EditableText).at(1),
      'zxabc12@student.uni-tuebingen.de',
    );
    await tester.enterText(find.byType(EditableText).at(2), 'M.Sc. AI');
    await tester.enterText(find.byType(EditableText).at(3), '4');
    await tester.tap(find.text('Start StudyOS'));
    await tester.pumpAndSettle();

    expect(profile?.displayName, 'Zxabc12');
    expect(profile?.email, 'zxabc12@student.uni-tuebingen.de');
    expect(profile?.degreeProgram, 'M.Sc. AI');
    expect(profile?.semester, 4);
  });

  test('prompt context injects profile and memory', () {
    const context = PromptContext(
      profile: OnboardingProfile(
        displayName: 'Ada',
        username: 'ada42',
        email: 'ada@example.edu',
        degreeProgram: 'M.Sc. AI',
        semester: 2,
        livesInTuebingen: true,
      ),
      memory: '- Prefers morning study blocks.',
      worldState: <String, Object?>{'weekday': 'Thursday'},
    );

    final prompt = context.systemPrompt();

    expect(prompt, contains('Ada'));
    expect(prompt, contains('ada@example.edu'));
    expect(prompt, contains('M.Sc. AI'));
    expect(prompt, contains('Prefers morning study blocks'));
    expect(prompt, contains('Thursday'));
  });
}

class _TestShell extends StatelessWidget {
  const _TestShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildStudyOsTheme(),
      home: Scaffold(body: child),
    );
  }
}
