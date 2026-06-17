import 'dart:convert';

import 'mail_repository.dart';
import 'models.dart';

class MailToolRunner {
  MailToolRunner({required this.repository, required this.profile});

  final MailRepository repository;
  final OnboardingProfile? profile;

  Future<String> execute(String toolName, String arguments) async {
    final args = _decodeArgs(arguments);
    return switch (toolName) {
      'list_mailboxes' => _listMailboxes(),
      'get_recent_mail' => _getRecentMail(args),
      'search_mail' => _searchMail(args),
      'get_mail_message' => _getMailMessage(args),
      'find_mail_deadlines' => _findMailDeadlines(args),
      _ => 'Tool is not available: $toolName',
    };
  }

  Future<String> _listMailboxes() async {
    final mailboxes = await repository.listMailboxes(profile);
    return jsonEncode(mailboxes.map((mailbox) => mailbox.toJson()).toList());
  }

  Future<String> _getRecentMail(Map<String, Object?> args) async {
    final inbox = await repository.fetchMailboxSummary(
      profile,
      mailbox: _stringArg(args, 'mailbox', fallback: 'INBOX'),
      limit: _intArg(args, 'limit', fallback: 5).clamp(1, 10).toInt(),
      unreadOnly: args['unread_only'] == true,
    );
    return jsonEncode(inbox.toJson());
  }

  Future<String> _searchMail(Map<String, Object?> args) async {
    final inbox = await repository.fetchMailboxSummary(
      profile,
      mailbox: _stringArg(args, 'mailbox', fallback: 'INBOX'),
      limit: _intArg(args, 'limit', fallback: 5).clamp(1, 10).toInt(),
      unreadOnly: args['unread_only'] == true,
      query: _stringArg(args, 'query'),
      sender: _stringArg(args, 'sender'),
      since: _stringArg(args, 'since'),
      scanLimit: _intArg(
        args,
        'scan_limit',
        fallback: 100,
      ).clamp(20, 300).toInt(),
    );
    return jsonEncode(inbox.toJson());
  }

  Future<String> _getMailMessage(Map<String, Object?> args) async {
    final uid = _stringArg(args, 'uid');
    if (uid.isEmpty) return 'Mail UID is required.';
    final message = await repository.fetchMessageDetail(
      profile,
      uid: uid,
      mailbox: _stringArg(args, 'mailbox', fallback: 'INBOX'),
    );
    return jsonEncode(message.toJson());
  }

  Future<String> _findMailDeadlines(Map<String, Object?> args) async {
    final inbox = await repository.fetchMailboxSummary(
      profile,
      mailbox: _stringArg(args, 'mailbox', fallback: 'INBOX'),
      limit: _intArg(args, 'limit', fallback: 8).clamp(1, 10).toInt(),
      query: _stringArg(args, 'query'),
      sender: _stringArg(args, 'sender'),
      since: _stringArg(args, 'since'),
      scanLimit: _intArg(
        args,
        'scan_limit',
        fallback: 150,
      ).clamp(20, 300).toInt(),
    );
    final candidates = inbox.messages
        .where(_looksDeadlineRelated)
        .map(_deadlineCandidate)
        .toList();
    return jsonEncode(<String, Object?>{
      'mailbox': inbox.mailbox,
      'heuristic': true,
      'note':
          'Candidate deadline mentions from mail summaries. Read source messages before treating dates as confirmed.',
      'messages': candidates,
    });
  }
}

Map<String, Object?> _decodeArgs(String arguments) {
  if (arguments.trim().isEmpty) return const <String, Object?>{};
  final Object? decoded;
  try {
    decoded = jsonDecode(arguments);
  } on FormatException {
    return const <String, Object?>{};
  }
  if (decoded is! Map) return const <String, Object?>{};
  return Map<String, Object?>.from(decoded);
}

String _stringArg(
  Map<String, Object?> args,
  String name, {
  String fallback = '',
}) {
  final value = args[name]?.toString().trim();
  return value == null || value.isEmpty ? fallback : value;
}

int _intArg(Map<String, Object?> args, String name, {required int fallback}) {
  final value = args[name];
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _looksDeadlineRelated(MailMessageSummary message) {
  final haystack = '${message.subject} ${message.preview ?? ''}'.toLowerCase();
  return <String>[
    'deadline',
    'frist',
    'abgabe',
    'due',
    'submission',
    'prüfung',
    'exam',
    'termin',
  ].any(haystack.contains);
}

Map<String, Object?> _deadlineCandidate(MailMessageSummary message) {
  return <String, Object?>{
    'uid': message.uid,
    'subject': message.subject,
    'from_name': message.fromName,
    'from_address': message.fromAddress,
    'received_at': message.receivedAt,
    'preview': message.preview,
    'date_mentions': _dateMentions('${message.subject} ${message.preview}'),
    'is_approved_broadcast': message.approvalNotice != null,
  };
}

List<String> _dateMentions(String text) {
  return RegExp(
    r'\b(?:\d{1,2}[./-]\d{1,2}(?:[./-]\d{2,4})?|\d{4}-\d{2}-\d{2})\b',
  ).allMatches(text).map((match) => match.group(0)!).toList();
}
