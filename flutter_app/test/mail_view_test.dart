import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/mail_repository.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/views/mail_view.dart';

void main() {
  Future<void> pumpMailView(
    WidgetTester tester,
    _RecordingMailRepository repository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MailView(profile: _profile, repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('search field forwards the debounced query to the repository', (
    tester,
  ) async {
    final repository = _RecordingMailRepository();
    await pumpMailView(tester, repository);

    expect(repository.lastQuery, '');

    await tester.enterText(find.byType(TextField), 'exam');
    // Wait past the 400ms debounce window.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(repository.lastQuery, 'exam');
    expect(find.text('Exam registration'), findsOneWidget);
    expect(find.text('Cafeteria menu'), findsNothing);
  });

  testWidgets('clearing the search resets the query', (tester) async {
    final repository = _RecordingMailRepository();
    await pumpMailView(tester, repository);

    await tester.enterText(find.byType(TextField), 'exam');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(repository.lastQuery, 'exam');

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(repository.lastQuery, '');
    expect(find.text('Cafeteria menu'), findsOneWidget);
  });

  testWidgets('pull to refresh forces a live reload', (tester) async {
    final repository = _RecordingMailRepository();
    await pumpMailView(tester, repository);

    expect(repository.forceRefreshCount, 0);

    await tester.fling(
      find.byType(ListView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(repository.forceRefreshCount, 1);
  });
}

const _profile = OnboardingProfile(
  displayName: 'Ada',
  username: 'ada42',
  email: 'ada@example.edu',
  degreeProgram: 'M.Sc. AI',
  semester: 2,
  livesInTuebingen: true,
);

const _mailboxes = <MailboxSummary>[
  MailboxSummary(
    name: 'INBOX',
    label: 'Inbox',
    specialUse: 'inbox',
    messageCount: 2,
    unreadCount: 1,
  ),
];

const _allMessages = <MailMessageSummary>[
  MailMessageSummary(
    uid: '1',
    subject: 'Exam registration',
    fromName: 'Prof X',
    fromAddress: 'prof@example.edu',
    receivedAt: 'Tue, 16 Jun 2026 10:00:00 +0200',
    preview: 'Please register for the exam.',
    isUnread: true,
  ),
  MailMessageSummary(
    uid: '2',
    subject: 'Cafeteria menu',
    fromName: 'Studentenwerk',
    fromAddress: 'mensa@example.edu',
    receivedAt: 'Mon, 15 Jun 2026 09:00:00 +0200',
    preview: 'Today at the Mensa.',
    isUnread: false,
  ),
];

class _RecordingMailRepository extends MailRepository {
  _RecordingMailRepository() : super.test();

  String lastQuery = '';
  int forceRefreshCount = 0;

  @override
  Future<MailMailboxSnapshot> fetchMailboxSnapshot(
    OnboardingProfile? profile, {
    String mailbox = 'INBOX',
    int limit = 12,
    bool unreadOnly = false,
    String query = '',
    String sender = '',
    String since = '',
    int scanLimit = 200,
    bool forceRefresh = false,
  }) async {
    lastQuery = query;
    if (forceRefresh) forceRefreshCount += 1;
    final needle = query.trim().toLowerCase();
    final messages = needle.isEmpty
        ? _allMessages
        : _allMessages
              .where((m) => m.subject.toLowerCase().contains(needle))
              .toList();
    return MailMailboxSnapshot(
      mailboxes: _mailboxes,
      inbox: MailInboxSummary(
        account: 'ada42',
        mailbox: mailbox,
        unreadCount: 1,
        messages: messages,
      ),
    );
  }
}
