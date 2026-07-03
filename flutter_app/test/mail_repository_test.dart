import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:studyos_agent/src/mail_client.dart';
import 'package:studyos_agent/src/mail_repository.dart';
import 'package:studyos_agent/src/models.dart';
import 'package:studyos_agent/src/profile_store.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('mailbox snapshot reuses one authenticated client', () async {
    final client = _CountingMailClient();
    final repository = MailRepository.test(
      profileStore: _FakeProfileStore(),
      clientFactory: () => client,
    );

    final snapshot = await repository.fetchMailboxSnapshot(
      _profile,
      mailbox: 'INBOX',
      limit: 20,
      unreadOnly: true,
    );

    expect(snapshot.mailboxes, hasLength(1));
    expect(snapshot.inbox.mailbox, 'INBOX');
    expect(client.loginCount, 1);
    expect(client.listCount, 1);
    expect(client.summaryCount, 1);
    expect(client.closeCount, 1);
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

class _FakeProfileStore extends ProfileStore {
  @override
  Future<String?> readPassword() async => 'secret';
}

class _CountingMailClient extends MailClient {
  int loginCount = 0;
  int listCount = 0;
  int summaryCount = 0;
  int closeCount = 0;

  @override
  Future<void> login(String username, String password) async {
    loginCount += 1;
    expect(username, 'ada42');
    expect(password, 'secret');
  }

  @override
  Future<List<MailboxSummary>> listMailboxes() async {
    listCount += 1;
    return const <MailboxSummary>[
      MailboxSummary(
        name: 'INBOX',
        label: 'Inbox',
        specialUse: 'inbox',
        messageCount: 3,
        unreadCount: 1,
      ),
    ];
  }

  @override
  Future<MailInboxSummary> fetchMailboxSummary({
    String mailbox = 'INBOX',
    int limit = 12,
    bool unreadOnly = false,
    String query = '',
    String sender = '',
    String since = '',
    int scanLimit = 200,
  }) async {
    summaryCount += 1;
    expect(mailbox, 'INBOX');
    expect(limit, 20);
    expect(unreadOnly, isTrue);
    return const MailInboxSummary(
      account: 'ada42',
      mailbox: 'INBOX',
      unreadCount: 1,
      messages: <MailMessageSummary>[],
    );
  }

  @override
  void close() {
    closeCount += 1;
  }
}
