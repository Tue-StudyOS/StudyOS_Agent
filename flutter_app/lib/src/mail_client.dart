import 'dart:async';

import 'imap_connection.dart';
import 'mail_models.dart';
import 'mail_parsing.dart';

class MailClient {
  MailClient({
    this.host = 'mailserv.uni-tuebingen.de',
    this.port = 993,
    this.timeout = const Duration(seconds: 20),
  });

  final String host;
  final int port;
  final Duration timeout;
  ImapConnection? _connection;
  String? _account;

  Future<void> login(String username, String password) async {
    final connection = await ImapConnection.connect(
      host: host,
      port: port,
      timeout: timeout,
    );
    try {
      await connection.command('LOGIN ${_quote(username)} ${_quote(password)}');
    } on Object {
      connection.close();
      throw MailException(
        'Mail login failed. Uni Tuebingen mail usually expects the ZDV-ID.',
      );
    }
    _connection = connection;
    _account = username;
  }

  Future<List<MailboxSummary>> listMailboxes() async {
    final response = await _requireConnection().command('LIST "" "*"');
    final mailboxes = <MailboxSummary>[];
    for (final line in response.lines) {
      final parsed = _parseMailboxLine(line);
      if (parsed == null) continue;
      final counts = await _mailboxCounts(parsed.name);
      mailboxes.add(
        MailboxSummary(
          name: parsed.name,
          label: _mailboxLabel(parsed.name),
          specialUse: parsed.name.toUpperCase() == 'INBOX' ? 'inbox' : null,
          messageCount: counts.$1,
          unreadCount: counts.$2,
        ),
      );
    }
    mailboxes.sort((left, right) {
      final leftRank = left.specialUse == 'inbox' ? 0 : 1;
      final rightRank = right.specialUse == 'inbox' ? 0 : 1;
      if (leftRank != rightRank) return leftRank.compareTo(rightRank);
      return left.label.toLowerCase().compareTo(right.label.toLowerCase());
    });
    return mailboxes;
  }

  Future<MailInboxSummary> fetchMailboxSummary({
    String mailbox = 'INBOX',
    int limit = 12,
    bool unreadOnly = false,
    String query = '',
    String sender = '',
    String since = '',
    int scanLimit = 200,
  }) async {
    final connection = _requireConnection();
    await connection.command('EXAMINE ${_quote(mailbox)}');
    final unreadIds = (await _searchUids('UNSEEN')).toSet();
    final sinceCriterion = _sinceCriterion(since);
    final allIds = await _searchUids(sinceCriterion ?? 'ALL');
    final boundedLimit = limit.clamp(1, 50).toInt();
    final trimmedQuery = query.trim();
    final trimmedSender = sender.trim();

    final messages = <MailMessageSummary>[];
    if (trimmedQuery.isEmpty && trimmedSender.isEmpty && !unreadOnly) {
      final recent = allIds.reversed.take(boundedLimit);
      for (final uid in recent) {
        messages.add(
          await _fetchSummary(uid, mailbox, unreadIds.contains(uid)),
        );
      }
    } else {
      final source = allIds.where(
        (uid) => !unreadOnly || unreadIds.contains(uid),
      );
      for (final uid in source.toList().reversed.take(scanLimit)) {
        final summary = await _fetchSummary(
          uid,
          mailbox,
          unreadIds.contains(uid),
        );
        if (!_matches(summary, query: trimmedQuery, sender: trimmedSender)) {
          continue;
        }
        messages.add(summary);
        if (messages.length >= boundedLimit) break;
      }
    }

    return MailInboxSummary(
      account: _account ?? '',
      mailbox: mailbox,
      unreadCount: unreadIds.length,
      messages: messages,
    );
  }

  Future<MailMessageDetail> fetchMessageDetail(
    String uid, {
    String mailbox = 'INBOX',
  }) async {
    if (!RegExp(r'^\d+$').hasMatch(uid)) {
      throw const MailException('Mail UID is invalid.');
    }
    await _requireConnection().command('EXAMINE ${_quote(mailbox)}');
    final unreadIds = (await _searchUids('UNSEEN')).toSet();
    final raw = await _fetchRawMessage(uid);
    return parseMailDetail(
      raw,
      uid: uid,
      mailbox: mailbox,
      isUnread: unreadIds.contains(uid),
    );
  }

  void close() {
    final connection = _connection;
    _connection = null;
    if (connection == null) return;
    unawaited(connection.command('LOGOUT').catchError((_) => ImapResponse('')));
    connection.close();
  }

  ImapConnection _requireConnection() {
    final connection = _connection;
    if (connection == null) throw const MailException('Mail is not connected.');
    return connection;
  }

  Future<List<String>> _searchUids(String criterion) async {
    final response = await _requireConnection().command(
      'UID SEARCH $criterion',
    );
    final line = response.lines.firstWhere(
      (item) => item.toUpperCase().startsWith('* SEARCH'),
      orElse: () => '',
    );
    return line
        .replaceFirst(RegExp(r'^\* SEARCH\s*', caseSensitive: false), '')
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList();
  }

  Future<MailMessageSummary> _fetchSummary(
    String uid,
    String mailbox,
    bool isUnread,
  ) async {
    final raw = await _fetchRawMessage(uid);
    return parseMailSummary(raw, uid: uid, isUnread: isUnread);
  }

  Future<List<int>> _fetchRawMessage(String uid) async {
    final response = await _requireConnection().command(
      'UID FETCH $uid (BODY.PEEK[])',
    );
    final literal = response.firstLiteral;
    if (literal == null) {
      throw MailException('IMAP fetch returned no message body for UID $uid.');
    }
    return literal;
  }

  Future<(int?, int?)> _mailboxCounts(String mailbox) async {
    try {
      final response = await _requireConnection().command(
        'STATUS ${_quote(mailbox)} (MESSAGES UNSEEN)',
      );
      final payload = response.text;
      return (
        _extractStatusValue(payload, 'MESSAGES'),
        _extractStatusValue(payload, 'UNSEEN'),
      );
    } on Object {
      return (null, null);
    }
  }
}

String? _sinceCriterion(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return 'SINCE $trimmed';
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return 'SINCE ${parsed.day}-${months[parsed.month - 1]}-${parsed.year}';
}

_ParsedMailbox? _parseMailboxLine(String line) {
  if (!line.toUpperCase().startsWith('* LIST')) return null;
  final quoted = RegExp(r'"([^"]+)"\s*$').firstMatch(line);
  if (quoted != null) return _ParsedMailbox(quoted.group(1)!);
  final parts = line.split(RegExp(r'\s+'));
  if (parts.length < 4) return null;
  return _ParsedMailbox(parts.last);
}

class _ParsedMailbox {
  const _ParsedMailbox(this.name);

  final String name;
}

bool _matches(
  MailMessageSummary message, {
  required String query,
  required String sender,
}) {
  final senderNeedle = sender.toLowerCase();
  if (senderNeedle.isNotEmpty) {
    final senderText = '${message.fromName ?? ''} ${message.fromAddress ?? ''}'
        .toLowerCase();
    if (!senderText.contains(senderNeedle)) return false;
  }

  final queryNeedle = query.toLowerCase();
  if (queryNeedle.isEmpty) return true;
  return <String>[
    message.subject,
    message.preview ?? '',
    message.fromName ?? '',
    message.fromAddress ?? '',
  ].any((value) => value.toLowerCase().contains(queryNeedle));
}

int? _extractStatusValue(String payload, String key) {
  final match = RegExp(
    '$key\\s+(\\d+)',
    caseSensitive: false,
  ).firstMatch(payload);
  return int.tryParse(match?.group(1) ?? '');
}

String _mailboxLabel(String name) {
  if (name.toUpperCase() == 'INBOX') return 'Inbox';
  return name.split('/').last.replaceAll(RegExp(r'[_-]+'), ' ');
}

String _quote(String value) {
  return '"${value.replaceAll('\\', '\\\\').replaceAll('"', r'\"')}"';
}
