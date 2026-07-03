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

MailMessageSummary parseMailSummaryPreview({
  required List<int> rawHeaders,
  required List<int> rawPreview,
  required String uid,
  required bool isUnread,
}) {
  final parsed = ParsedMail.fromBytes(_messageBytes(rawHeaders, rawPreview));
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
  List<String>? attachmentNames,
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
    attachmentNames: attachmentNames ?? parsed.attachmentNames,
    isUnread: isUnread,
    approvalNotice: hasBroadcastApproval(body) ? approvedBroadcastNotice : null,
  );
}

List<int> combineMailHeaderAndBodyPreview(
  List<int> rawHeaders,
  List<int> rawBody,
) {
  return _messageBytes(rawHeaders, rawBody);
}

/// A single MIME leaf selected from an IMAP BODYSTRUCTURE, describing how to
/// fetch and decode just that part.
class MailTextSection {
  const MailTextSection({
    required this.section,
    required this.mimeType,
    required this.charset,
    required this.encoding,
  });

  /// IMAP section spec used in `BODY[<section>]`, e.g. `1` or `1.2`.
  final String section;

  /// e.g. `text/plain` or `text/html`.
  final String mimeType;

  /// e.g. `utf-8`.
  final String charset;

  /// Content transfer encoding, e.g. `base64`, `quoted-printable`, `7bit`.
  final String encoding;
}

/// Parsed view of an IMAP BODYSTRUCTURE response: which body part carries the
/// readable text and which parts are attachments. Used to fetch only the text
/// part instead of downloading full messages (attachments included).
class MailBodyStructure {
  const MailBodyStructure({
    required this.isMultipart,
    required this.textSection,
    required this.attachmentNames,
  });

  final bool isMultipart;

  /// The best text part to fetch, or null when the message is a single part
  /// (fetch `BODY[TEXT]` instead) or no text part exists.
  final MailTextSection? textSection;

  final List<String> attachmentNames;
}

/// Parses a raw IMAP FETCH response containing a BODYSTRUCTURE. Returns null if
/// no structure can be recovered, so callers can fall back to a bounded
/// `BODY[TEXT]` fetch.
MailBodyStructure? parseBodyStructure(String rawResponse) {
  final group = _extractStructureGroup(rawResponse);
  if (group == null) return null;
  try {
    final cursor = _StructCursor(group, 0);
    final root = _readStructToken(group, cursor);
    if (root is! List) return null;
    final leaves = <_StructLeaf>[];
    _collectLeaves(root, '', leaves);
    final isMultipart = _isMultipartNode(root);
    final textLeaves = leaves
        .where((leaf) => !leaf.isAttachment && leaf.type == 'TEXT')
        .toList();
    _StructLeaf? chosen;
    for (final leaf in textLeaves) {
      if (leaf.subtype == 'PLAIN') {
        chosen = leaf;
        break;
      }
    }
    chosen ??= textLeaves.isNotEmpty ? textLeaves.first : null;
    final attachments = leaves
        .where((leaf) => leaf.isAttachment)
        .map((leaf) => leaf.filename)
        .whereType<String>()
        .toList();
    final textSection = (chosen == null || !isMultipart)
        ? null
        : MailTextSection(
            section: chosen.section,
            mimeType:
                '${chosen.type.toLowerCase()}/${chosen.subtype.toLowerCase()}',
            charset: chosen.charset,
            encoding: chosen.encoding,
          );
    return MailBodyStructure(
      isMultipart: isMultipart,
      textSection: textSection,
      attachmentNames: attachments,
    );
  } on Object {
    return null;
  }
}

/// Builds a synthetic single-part message (top-level headers + the selected
/// part's content headers + its still-encoded body) so [parseMailSummary] and
/// [parseMailDetail] can decode a single fetched text part with the existing
/// pipeline. The injected content headers are appended last so they win over
/// any multipart Content-Type carried in [rawHeaders].
List<int> buildTextPartMessage({
  required List<int> rawHeaders,
  required List<int> rawPartBody,
  required MailTextSection section,
}) {
  final headers = latin1.decode(rawHeaders, allowInvalid: true).trim();
  final injected =
      '$headers\r\n'
      'Content-Type: ${section.mimeType}; charset=${section.charset}\r\n'
      'Content-Transfer-Encoding: ${section.encoding}';
  final body = latin1.decode(rawPartBody, allowInvalid: true);
  return latin1.encode('$injected\r\n\r\n$body');
}

class _StructLeaf {
  const _StructLeaf({
    required this.section,
    required this.type,
    required this.subtype,
    required this.charset,
    required this.encoding,
    required this.isAttachment,
    required this.filename,
  });

  final String section;
  final String type;
  final String subtype;
  final String charset;
  final String encoding;
  final bool isAttachment;
  final String? filename;
}

String? _extractStructureGroup(String raw) {
  final marker = RegExp('BODYSTRUCTURE', caseSensitive: false).firstMatch(raw);
  if (marker == null) return null;
  final start = raw.indexOf('(', marker.end);
  if (start < 0) return null;
  var depth = 0;
  var inQuote = false;
  for (var i = start; i < raw.length; i++) {
    final ch = raw[i];
    if (inQuote) {
      if (ch == r'\') {
        i++;
        continue;
      }
      if (ch == '"') inQuote = false;
      continue;
    }
    if (ch == '"') {
      inQuote = true;
    } else if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
      if (depth == 0) return raw.substring(start, i + 1);
    }
  }
  return null;
}

void _collectLeaves(List node, String prefix, List<_StructLeaf> out) {
  if (_isMultipartNode(node)) {
    var index = 0;
    for (final child in node) {
      if (child is! List) break;
      index += 1;
      final section = prefix.isEmpty ? '$index' : '$prefix.$index';
      _collectLeaves(child, section, out);
    }
    return;
  }
  out.add(_leafFromNode(node, prefix.isEmpty ? '1' : prefix));
}

bool _isMultipartNode(List node) => node.isNotEmpty && node.first is List;

_StructLeaf _leafFromNode(List node, String section) {
  final type = _asString(node.isNotEmpty ? node[0] : '').toUpperCase();
  final subtype = _asString(node.length > 1 ? node[1] : '').toUpperCase();
  final params = node.length > 2 && node[2] is List
      ? node[2] as List
      : const <Object>[];
  final charset = (_paramValue(params, 'CHARSET') ?? 'utf-8').toLowerCase();
  final encoding = (node.length > 5 ? _asString(node[5]) : '7bit')
      .toLowerCase();
  final disposition = _dispositionOf(node);
  final filename = _filenameOf(node);
  final isAttachment =
      disposition == 'ATTACHMENT' || (type != 'TEXT' && filename != null);
  return _StructLeaf(
    section: section,
    type: type,
    subtype: subtype,
    charset: charset,
    encoding: encoding.isEmpty ? '7bit' : encoding,
    isAttachment: isAttachment,
    filename: filename,
  );
}

String? _dispositionOf(List node) {
  for (final element in node) {
    if (element is List && element.isNotEmpty && element.first is String) {
      final value = (element.first as String).toUpperCase();
      if (value == 'ATTACHMENT' || value == 'INLINE') return value;
    }
  }
  return null;
}

String? _filenameOf(List node) {
  for (final element in node) {
    if (element is List && element.isNotEmpty && element.first is String) {
      final value = (element.first as String).toUpperCase();
      if ((value == 'ATTACHMENT' || value == 'INLINE') &&
          element.length > 1 &&
          element[1] is List) {
        final name = _paramValue(element[1] as List, 'FILENAME');
        if (name != null && name.isNotEmpty) {
          return decodeMimeHeader(name) ?? name;
        }
      }
    }
  }
  final params = node.length > 2 && node[2] is List
      ? node[2] as List
      : const <Object>[];
  final name = _paramValue(params, 'NAME');
  if (name != null && name.isNotEmpty) return decodeMimeHeader(name) ?? name;
  return null;
}

String? _paramValue(List params, String key) {
  for (var i = 0; i + 1 < params.length; i += 2) {
    if (_asString(params[i]).toUpperCase() == key.toUpperCase()) {
      final value = params[i + 1];
      if (value is String && value.toUpperCase() != 'NIL') return value;
    }
  }
  return null;
}

String _asString(Object? value) => value is String ? value : '';

class _StructCursor {
  _StructCursor(this.text, this.index);

  final String text;
  int index;
}

Object? _readStructToken(String source, _StructCursor cursor) {
  _skipStructSpaces(source, cursor);
  if (cursor.index >= source.length) return null;
  final ch = source[cursor.index];
  if (ch == '(') return _readStructList(source, cursor);
  if (ch == '"') return _readStructQuoted(source, cursor);
  return _readStructAtom(source, cursor);
}

List<Object> _readStructList(String source, _StructCursor cursor) {
  cursor.index += 1; // consume '('
  final items = <Object>[];
  while (cursor.index < source.length) {
    _skipStructSpaces(source, cursor);
    if (cursor.index >= source.length) break;
    if (source[cursor.index] == ')') {
      cursor.index += 1;
      break;
    }
    final token = _readStructToken(source, cursor);
    if (token == null) break;
    items.add(token);
  }
  return items;
}

String _readStructQuoted(String source, _StructCursor cursor) {
  cursor.index += 1; // consume opening quote
  final buffer = StringBuffer();
  while (cursor.index < source.length) {
    final ch = source[cursor.index];
    if (ch == r'\' && cursor.index + 1 < source.length) {
      buffer.write(source[cursor.index + 1]);
      cursor.index += 2;
      continue;
    }
    if (ch == '"') {
      cursor.index += 1;
      break;
    }
    buffer.write(ch);
    cursor.index += 1;
  }
  return buffer.toString();
}

String _readStructAtom(String source, _StructCursor cursor) {
  final buffer = StringBuffer();
  while (cursor.index < source.length) {
    final ch = source[cursor.index];
    if (ch == ' ' ||
        ch == '\r' ||
        ch == '\n' ||
        ch == '(' ||
        ch == ')' ||
        ch == '"') {
      break;
    }
    buffer.write(ch);
    cursor.index += 1;
  }
  return buffer.toString();
}

void _skipStructSpaces(String source, _StructCursor cursor) {
  while (cursor.index < source.length) {
    final ch = source[cursor.index];
    if (ch != ' ' && ch != '\r' && ch != '\n') break;
    cursor.index += 1;
  }
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

List<int> _messageBytes(List<int> rawHeaders, List<int> rawBody) {
  final normalizedHeaders = latin1
      .decode(rawHeaders, allowInvalid: true)
      .trim();
  final normalizedBody = latin1.decode(rawBody, allowInvalid: true);
  return latin1.encode('$normalizedHeaders\r\n\r\n$normalizedBody');
}
