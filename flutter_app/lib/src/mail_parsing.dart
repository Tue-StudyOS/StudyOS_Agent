import 'dart:convert';

import 'mail_models.dart';

const approvedBroadcastNotice = MailApprovalNotice(
  title: 'Approved university broadcast',
  message: 'Die Hochschulleitung hat dem Versand dieser Rundmail zugestimmt.',
);

final _approvalPattern = RegExp(
  r'Die Hochschulleitung hat (?:dem|den) Versand dieser (?:Rundmail|Runde) zugestimmt\.?',
  caseSensitive: false,
);
final _responsibilityPattern = RegExp(
  r'\*{8,}\s*\*\s*\*\s*\*\s*Die inhaltliche Verantwortung liegt bei der Absenderin/dem Absender\s*\*\s*\*{8,}',
  caseSensitive: false,
);

MailMessageSummary parseMailSummary(
  List<int> rawMessage, {
  required String uid,
  required bool isUnread,
}) {
  final parsed = ParsedMail.fromBytes(rawMessage);
  final body = parsed.bodyText;
  final cleanedBody = stripBroadcastBoilerplate(body);
  final sender = _parseAddress(parsed.header('from'));
  return MailMessageSummary(
    uid: uid,
    subject: decodeMimeHeader(parsed.header('subject')) ?? '(No subject)',
    fromName: sender.name,
    fromAddress: sender.address,
    receivedAt: parsed.header('date'),
    preview: previewFromText(cleanedBody),
    isUnread: isUnread,
    approvalNotice: hasBroadcastApproval(body) ? approvedBroadcastNotice : null,
  );
}

MailMessageDetail parseMailDetail(
  List<int> rawMessage, {
  required String uid,
  required String mailbox,
  required bool isUnread,
}) {
  final parsed = ParsedMail.fromBytes(rawMessage);
  final body = parsed.bodyText;
  final cleanedBody = stripBroadcastBoilerplate(body);
  final sender = _parseAddress(parsed.header('from'));
  return MailMessageDetail(
    uid: uid,
    mailbox: mailbox,
    subject: decodeMimeHeader(parsed.header('subject')) ?? '(No subject)',
    fromName: sender.name,
    fromAddress: sender.address,
    toRecipients: parseAddressList(parsed.header('to')),
    ccRecipients: parseAddressList(parsed.header('cc')),
    receivedAt: parsed.header('date'),
    preview: previewFromText(cleanedBody),
    bodyText: cleanedBody,
    attachmentNames: parsed.attachmentNames,
    isUnread: isUnread,
    approvalNotice: hasBroadcastApproval(body) ? approvedBroadcastNotice : null,
  );
}

bool hasBroadcastApproval(String? value) {
  return value != null && _approvalPattern.hasMatch(value);
}

String? stripBroadcastBoilerplate(String? value) {
  if (value == null || value.trim().isEmpty) return value;
  final cleaned = value
      .replaceAll(_approvalPattern, '')
      .replaceAll(_responsibilityPattern, '')
      .trim();
  return cleaned.isEmpty ? null : cleaned;
}

String? previewFromText(String? value, {int limit = 160}) {
  if (value == null) return null;
  final collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) return null;
  return collapsed.length <= limit ? collapsed : collapsed.substring(0, limit);
}

String? decodeMimeHeader(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value.replaceAllMapped(RegExp(r'=\?([^?]+)\?([bqBQ])\?([^?]*)\?='), (
    match,
  ) {
    final charset = match.group(1)?.toLowerCase() ?? 'utf-8';
    final encoding = match.group(2)?.toLowerCase();
    final payload = match.group(3) ?? '';
    List<int> bytes;
    if (encoding == 'b') {
      bytes = base64.decode(payload);
    } else {
      bytes = quotedPrintableBytes(payload.replaceAll('_', ' '));
    }
    return _decodeBytes(bytes, charset);
  }).trim();
}

List<int> quotedPrintableBytes(String value) {
  final bytes = <int>[];
  for (var index = 0; index < value.length; index++) {
    final char = value[index];
    if (char == '=' && index + 2 < value.length) {
      final hex = value.substring(index + 1, index + 3);
      final decoded = int.tryParse(hex, radix: 16);
      if (decoded != null) {
        bytes.add(decoded);
        index += 2;
        continue;
      }
    }
    bytes.addAll(utf8.encode(char));
  }
  return bytes;
}

_MailAddress _parseAddress(String? value) {
  final decoded = decodeMimeHeader(value) ?? '';
  final match = RegExp(r'^\s*"?([^"<]*)"?\s*<([^>]+)>').firstMatch(decoded);
  if (match != null) {
    final name = match.group(1)?.trim();
    return _MailAddress(
      name: name == null || name.isEmpty ? null : name,
      address: match.group(2)?.trim(),
    );
  }
  final trimmed = decoded.trim();
  if (trimmed.contains('@')) return _MailAddress(name: null, address: trimmed);
  return _MailAddress(name: trimmed.isEmpty ? null : trimmed, address: null);
}

List<String> parseAddressList(String? value) {
  final decoded = decodeMimeHeader(value) ?? '';
  if (decoded.trim().isEmpty) return const <String>[];
  return decoded
      .split(RegExp(r',\s*(?=[^>]*(?:<|$))'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

class ParsedMail {
  ParsedMail._(this.headers, this.parts);

  final Map<String, String> headers;
  final List<MailPart> parts;

  static ParsedMail fromBytes(List<int> bytes) {
    final text = latin1.decode(bytes, allowInvalid: true);
    return _parseMessage(text);
  }

  String? header(String name) => headers[name.toLowerCase()];

  String? get bodyText {
    final plain = parts
        .where((part) => part.contentType.startsWith('text/plain'))
        .where((part) => !part.isAttachment)
        .map((part) => part.decodedText)
        .where((text) => text.trim().isNotEmpty)
        .join('\n\n');
    if (plain.trim().isNotEmpty) return normalizeBodyText(plain);

    final html = parts
        .where((part) => part.contentType.startsWith('text/html'))
        .where((part) => !part.isAttachment)
        .map((part) => htmlToText(part.decodedText))
        .where((text) => text.trim().isNotEmpty)
        .join('\n\n');
    return normalizeBodyText(html);
  }

  List<String> get attachmentNames {
    return parts
        .where((part) => part.isAttachment)
        .map((part) => part.filename)
        .whereType<String>()
        .toList();
  }
}

class MailPart {
  const MailPart({required this.headers, required this.body});

  final Map<String, String> headers;
  final String body;

  String get contentType =>
      (headers['content-type'] ?? 'text/plain').toLowerCase();
  String get transferEncoding =>
      (headers['content-transfer-encoding'] ?? '').toLowerCase();
  bool get isAttachment => (headers['content-disposition'] ?? '')
      .toLowerCase()
      .contains('attachment');
  String? get filename {
    final disposition = headers['content-disposition'] ?? '';
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    return decodeMimeHeader(match?.group(1));
  }

  String get decodedText {
    final charset =
        RegExp(r'charset="?([^";]+)"?').firstMatch(contentType)?.group(1) ??
        'utf-8';
    final bytes = transferEncoding == 'base64'
        ? base64.decode(body.replaceAll(RegExp(r'\s+'), ''))
        : transferEncoding == 'quoted-printable'
        ? quotedPrintableBytes(body.replaceAll(RegExp(r'=\r?\n'), ''))
        : latin1.encode(body);
    return _decodeBytes(bytes, charset);
  }
}

ParsedMail _parseMessage(String text) {
  final split = _splitHeaderBody(text);
  final headers = _parseHeaders(split.$1);
  final contentType = headers['content-type']?.toLowerCase() ?? '';
  final boundary = RegExp(
    r'boundary="?([^";]+)"?',
  ).firstMatch(contentType)?.group(1);
  if (boundary == null || boundary.isEmpty) {
    return ParsedMail._(headers, <MailPart>[
      MailPart(headers: headers, body: split.$2),
    ]);
  }
  return ParsedMail._(headers, _parseParts(split.$2, boundary));
}

List<MailPart> _parseParts(String body, String boundary) {
  return body
      .split('--$boundary')
      .where((part) => part.trim().isNotEmpty && !part.trim().startsWith('--'))
      .map((part) {
        final split = _splitHeaderBody(part);
        return MailPart(headers: _parseHeaders(split.$1), body: split.$2);
      })
      .toList();
}

(String, String) _splitHeaderBody(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final separator = normalized.indexOf('\n\n');
  if (separator < 0) return ('', normalized);
  return (
    normalized.substring(0, separator),
    normalized.substring(separator + 2),
  );
}

Map<String, String> _parseHeaders(String value) {
  final headers = <String, String>{};
  String? currentName;
  final currentValue = StringBuffer();
  for (final line in value.split('\n')) {
    if (line.startsWith(' ') || line.startsWith('\t')) {
      currentValue.write(' ${line.trim()}');
      continue;
    }
    if (currentName != null) {
      headers[currentName] = currentValue.toString().trim();
    }
    final separator = line.indexOf(':');
    if (separator < 0) {
      currentName = null;
      currentValue.clear();
      continue;
    }
    currentName = line.substring(0, separator).toLowerCase();
    currentValue
      ..clear()
      ..write(line.substring(separator + 1).trim());
  }
  if (currentName != null) headers[currentName] = currentValue.toString();
  return headers;
}

String? normalizeBodyText(String value) {
  final lines = value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.trimRight())
      .toList();
  final cleaned = <String>[];
  var blankStreak = 0;
  for (final line in lines) {
    final collapsed = line.trim();
    if (collapsed.isEmpty) {
      blankStreak += 1;
      if (blankStreak <= 1) cleaned.add('');
      continue;
    }
    blankStreak = 0;
    cleaned.add(collapsed);
  }
  final result = cleaned.join('\n').trim();
  return result.isEmpty ? null : result;
}

String htmlToText(String value) {
  return value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</(p|div|li|tr|h[1-6]|blockquote)>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '- ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

String _decodeBytes(List<int> bytes, String charset) {
  if (charset.toLowerCase().contains('utf')) {
    return utf8.decode(bytes, allowMalformed: true).trim();
  }
  return latin1.decode(bytes, allowInvalid: true).trim();
}

class _MailAddress {
  const _MailAddress({required this.name, required this.address});

  final String? name;
  final String? address;
}
