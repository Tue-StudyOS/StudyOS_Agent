import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/native_bridge.dart';
import 'package:studyos_agent/src/onboarding_flow.dart';
import 'package:studyos_agent/src/prompt_context.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/views/chat_view.dart';
import 'package:studyos_agent/src/views/memories_view.dart';
import 'package:studyos_agent/src/views/settings_view.dart';
import 'package:studyos_agent/src/widgets/conversation_list.dart';

void main() {
  testWidgets('chat view starts clean with suggestions and composer', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      _TestShell(
        child: ChatView(
          messages: const <ChatMessage>[],
          inputController: controller,
          messageScrollController: scrollController,
          isSending: false,
          compactMessages: false,
          onSuggestionSelected: (value) => controller.text = value,
          onSend: () {},
        ),
      ),
    );

    expect(
      find.text('Summarize my day and tell me what still needs attention.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Find my next lecture, including the room and when I should leave.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Plan a focused study block around my timetable and open tasks.',
      ),
      findsOneWidget,
    );
    expect(find.text('Message StudyOS...'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
    expect(find.text('Native'), findsNothing);
    expect(find.textContaining('Ask about lectures'), findsNothing);
  });

  testWidgets('conversation list exposes persisted chat sessions', (
    WidgetTester tester,
  ) async {
    final session = ChatSession.fresh().copyWith(
      title: 'Algorithms review',
      messages: const <ChatMessage>[
        ChatMessage(author: 'You', text: 'Review algorithms', isUser: true),
      ],
    );
    String? deletedSessionId;

    await tester.pumpWidget(
      _TestShell(
        child: ConversationList(
          sessions: <ChatSession>[session],
          activeSessionId: session.id,
          onSelectSession: (_) {},
          onCreateSession: () {},
          onDeleteSession: (value) => deletedSessionId = value,
        ),
      ),
    );

    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.psychology_alt_outlined), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    expect(find.text('Back to home'), findsNothing);
    expect(find.text('New'), findsOneWidget);
    expect(find.text(session.title), findsOneWidget);
    expect(find.text('Chats are stored on this device.'), findsOneWidget);
    expect(find.text('Capabilities'), findsNothing);
    expect(find.text('World State'), findsNothing);

    await tester.tap(find.byTooltip('Delete chat'));
    await tester.pumpAndSettle();

    expect(find.text('Delete chat?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(deletedSessionId, session.id);
  });

  testWidgets('assistant messages render markdown content', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);

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
          messageScrollController: scrollController,
          isSending: false,
          compactMessages: false,
          onSuggestionSelected: (_) {},
          onSend: () {},
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('StudyOS Agent'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is MarkdownBody && widget.data == '**Summary** with _focus_',
      ),
      findsOneWidget,
    );
    final assistantContainer = tester.widget<Container>(
      find.ancestor(
        of: find.byType(MarkdownBody),
        matching: find.byType(Container),
      ),
    );
    expect(assistantContainer.decoration, isNull);
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
          onSaveProfile: (_) async {},
          onSaveAgentConfig: (config, apiKey) async {
            savedConfig = config;
            savedKey = apiKey;
          },
          onCompactMessagesChanged: (_) {},
          nativeBridge: NativeBridge(),
        ),
      ),
    );

    await tester.tap(find.text('Custom'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Server URL'),
      'https://api.example.com/v1/chat/completions',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Model'), 'studyos');
    await tester.enterText(find.widgetWithText(TextField, 'API key'), 'secret');
    final saveButton = find.widgetWithText(
      FilledButton,
      'Save custom assistant',
    );
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(savedConfig?.provider, AgentProvider.cloud);
    expect(savedConfig?.cloudModel, 'studyos');
    expect(savedKey, 'secret');
    expect(find.text('Stored securely on this device.'), findsOneWidget);
    expect(find.text('Send feedback'), findsOneWidget);
  });

  testWidgets('settings profile editor updates onboarding preferences', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    OnboardingProfile? savedProfile;
    const profile = OnboardingProfile(
      displayName: 'Ada',
      username: 'ada42',
      email: 'ada@example.edu',
      degreeProgram: 'M.Sc. AI',
      semester: 2,
      livesInTuebingen: true,
      interests: <StudyInterest>{StudyInterest.schedule},
    );

    await tester.pumpWidget(
      _TestShell(
        child: SettingsView(
          config: const AgentConfig.defaults(),
          profile: profile,
          status: 'Ready',
          compactMessages: false,
          onLogout: null,
          onSaveProfile: (value) async => savedProfile = value,
          onSaveAgentConfig: (_, _) async {},
          onCompactMessagesChanged: (_) {},
          nativeBridge: NativeBridge(),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.text('Your profile'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ada L.');
    await tester.enterText(
      find.widgetWithText(TextField, 'Degree program'),
      'M.Sc. Computer Science',
    );
    await tester.ensureVisible(find.text('Mensa'));
    await tester.tap(find.text('Mensa'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Vegan'));
    await tester.tap(find.text('Vegan'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save profile'));
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();

    expect(savedProfile?.displayName, 'Ada L.');
    expect(savedProfile?.email, 'ada@example.edu');
    expect(savedProfile?.degreeProgram, 'M.Sc. Computer Science');
    expect(savedProfile?.interests, contains(StudyInterest.mensa));
    expect(savedProfile?.foodPreference, FoodPreference.vegan);
    expect(find.text('Profile saved.'), findsOneWidget);
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

    expect(find.text('Confirm profile'), findsOneWidget);
    expect(find.text('Personalize StudyOS'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('What should StudyOS help with?'), findsOneWidget);
    expect(find.text('Mensa preference'), findsNothing);

    await tester.enterText(find.byType(EditableText).at(1), 'M.Sc. AI');
    await tester.enterText(find.byType(EditableText).at(2), '4');
    await tester.tap(find.text('Mensa'));
    await tester.pumpAndSettle();
    expect(find.text('Mensa preference'), findsOneWidget);
    await tester.ensureVisible(find.text('Vegetarian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vegetarian'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Deadline reminders'), findsOneWidget);
    await tester.ensureVisible(find.text('Next lecture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next lecture'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start StudyOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start StudyOS'));
    await tester.pumpAndSettle();

    expect(profile?.displayName, 'Zxabc12');
    expect(profile?.email, isNull);
    expect(profile?.degreeProgram, 'M.Sc. AI');
    expect(profile?.semester, 4);
    expect(profile?.interests, contains(StudyInterest.mensa));
    expect(profile?.interests, contains(StudyInterest.notifications));
    expect(profile?.foodPreference, FoodPreference.vegetarian);
    expect(
      profile?.notificationPreferences,
      contains(NotificationPreference.nextLecture),
    );
  });

  testWidgets('onboarding uses profile prefill from login', (
    WidgetTester tester,
  ) async {
    OnboardingProfile? profile;

    await tester.pumpWidget(
      _TestShell(
        child: OnboardingPage(
          session: const UserSession(
            username: 'zxabc12',
            displayName: 'Sebastian Böhler',
            degreeProgram: 'Master Informatik / Computer Science',
            profileWarning: 'Could not load email from ALMA.',
          ),
          onComplete: (value) => profile = value,
        ),
      ),
    );

    expect(find.text('Sebastian Böhler'), findsOneWidget);
    expect(find.text('Master Informatik / Computer Science'), findsOneWidget);
    expect(find.text('Could not load email from ALMA.'), findsOneWidget);
    expect(find.text('What should StudyOS help with?'), findsOneWidget);

    await tester.ensureVisible(find.text('Start StudyOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start StudyOS'));
    await tester.pumpAndSettle();

    expect(profile?.displayName, 'Sebastian Böhler');
    expect(profile?.email, isNull);
    expect(profile?.degreeProgram, 'Master Informatik / Computer Science');
  });

  test('prompt context injects profile and memory', () {
    final now = DateTime.now();
    final context = PromptContext(
      profile: const OnboardingProfile(
        displayName: 'Ada',
        username: 'ada42',
        email: 'ada@example.edu',
        degreeProgram: 'M.Sc. AI',
        semester: 2,
        livesInTuebingen: true,
        interests: <StudyInterest>{StudyInterest.mensa},
        foodPreference: FoodPreference.vegan,
        notificationPreferences: <NotificationPreference>{
          NotificationPreference.deadlineReminders,
        },
      ),
      memory: '- Prefers morning study blocks.',
      worldState: <String, Object?>{'weekday': 'Thursday'},
      timetable: TimetableSnapshot(
        refreshedAt: now.subtract(const Duration(hours: 1)),
        sourceTerm: 'Sommer 2026',
        events: <LectureEvent>[
          LectureEvent(
            id: 'lecture-1',
            title: 'Algorithms',
            start: now.add(const Duration(hours: 1)),
            end: now.add(const Duration(hours: 3)),
            location: 'Room 101',
          ),
        ],
      ),
    );

    final prompt = context.systemPrompt();

    expect(prompt, contains('Current local timestamp:'));
    expect(prompt, contains('Ada'));
    expect(prompt, contains('ada@example.edu'));
    expect(prompt, contains('M.Sc. AI'));
    expect(prompt, contains('Mensa'));
    expect(prompt, contains('Vegan'));
    expect(prompt, contains('Deadline reminders'));
    expect(prompt, contains('Cached timetable summary'));
    expect(prompt, contains('Algorithms'));
    expect(prompt, contains('Prefers morning study blocks'));
    expect(prompt, contains('Thursday'));
    expect(prompt, contains('call append_memory'));
  });

  testWidgets('memories view edits the memory document', (
    WidgetTester tester,
  ) async {
    String? savedText;

    await tester.pumpWidget(
      _TestShell(
        child: MemoriesView(
          worldState: const <String, Object?>{'platform': 'ios'},
          memoryText: '- Favorite food: lasagne',
          onSaveMemory: (value) async => savedText = value,
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      '- Favorite food: lasagne\n- Prefers focused mornings',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(savedText, contains('Favorite food: lasagne'));
    expect(savedText, contains('Prefers focused mornings'));
    expect(find.text('Notes saved.'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
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
