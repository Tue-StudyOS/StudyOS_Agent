import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/mail_models.dart';
import 'package:studyos_agent/src/mail_repository.dart';
import 'package:studyos_agent/src/mail_tools.dart';
import 'package:studyos_agent/src/models.dart';

void main() {
  test('recent mail tool returns bounded summaries without bodies', () async {
    final runner = MailToolRunner(
      repository: _ToolMailRepository(),
      profile: _profile,
    );

    final output = await runner.execute(
      'get_recent_mail',
      '{"limit":50,"unread_only":true}',
    );
    final decoded = jsonDecode(output) as Map<String, Object?>;
    final messages = decoded['messages'] as List<Object?>;

    expect(messages, hasLength(1));
    expect(output, contains('Deadline reminder'));
    expect(output, isNot(contains('Full private body')));
  });

  test('deadline tool marks results as heuristic with source UIDs', () async {
    final runner = MailToolRunner(
      repository: _ToolMailRepository(),
      profile: _profile,
    );

    final output = await runner.execute('find_mail_deadlines', '{}');
    final decoded = jsonDecode(output) as Map<String, Object?>;
    final messages = decoded['messages'] as List<Object?>;
    final first = messages.first as Map<String, Object?>;

    expect(decoded['heuristic'], isTrue);
    expect(first['uid'], '42');
    expect(first['date_mentions'], contains('2026-06-20'));
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

class _ToolMailRepository extends MailRepository {
  @override
  Future<MailInboxSummary> fetchMailboxSummary(
    OnboardingProfile? profile, {
    String mailbox = 'INBOX',
    int limit = 12,
    bool unreadOnly = false,
    String query = '',
    String sender = '',
    String since = '',
    int scanLimit = 200,
  }) async {
    expect(limit, lessThanOrEqualTo(10));
    return const MailInboxSummary(
      account: 'ada42',
      mailbox: 'INBOX',
      unreadCount: 1,
      messages: <MailMessageSummary>[
        MailMessageSummary(
          uid: '42',
          subject: 'Deadline reminder',
          fromName: 'Prof X',
          fromAddress: 'prof@example.edu',
          receivedAt: 'Tue, 16 Jun 2026 10:00:00 +0200',
          preview: 'Please submit by 2026-06-20.',
          isUnread: true,
        ),
      ],
    );
  }

  @override
  Future<List<MailboxSummary>> listMailboxes(OnboardingProfile? profile) async {
    return const <MailboxSummary>[];
  }

  @override
  Future<MailMessageDetail> fetchMessageDetail(
    OnboardingProfile? profile, {
    required String uid,
    String mailbox = 'INBOX',
  }) async {
    return const MailMessageDetail(
      uid: '42',
      mailbox: 'INBOX',
      subject: 'Deadline reminder',
      fromName: 'Prof X',
      fromAddress: 'prof@example.edu',
      toRecipients: <String>['ada@example.edu'],
      ccRecipients: <String>[],
      receivedAt: 'Tue, 16 Jun 2026 10:00:00 +0200',
      preview: 'Please submit by 2026-06-20.',
      bodyText: 'Full private body',
      attachmentNames: <String>[],
      isUnread: true,
    );
  }
}
