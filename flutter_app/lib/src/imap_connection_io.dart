import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'mail_models.dart';

class ImapConnection {
  ImapConnection._(this._socket, this.timeout) {
    _subscription = _socket.listen(_buffer.addAll);
  }

  final SecureSocket _socket;
  final Duration timeout;
  final List<int> _buffer = <int>[];
  late final StreamSubscription<List<int>> _subscription;
  var _tagCounter = 0;

  static Future<ImapConnection> connect({
    required String host,
    required int port,
    required Duration timeout,
  }) async {
    final socket = await SecureSocket.connect(host, port, timeout: timeout);
    final connection = ImapConnection._(socket, timeout);
    await connection._waitForGreeting();
    return connection;
  }

  Future<ImapResponse> command(String command) async {
    final tag = 'A${(++_tagCounter).toString().padLeft(4, '0')}';
    _socket.write('$tag $command\r\n');
    await _socket.flush();
    final bytes = await _readUntilTagged(tag);
    final response = ImapResponse.fromBytes(bytes);
    if (!response.isOk(tag)) {
      throw MailException('IMAP command failed: ${response.statusLine(tag)}');
    }
    return response;
  }

  void close() {
    unawaited(_subscription.cancel());
    _socket.destroy();
  }

  Future<void> _waitForGreeting() async {
    await _readUntil((text) => text.contains('\r\n'));
  }

  Future<List<int>> _readUntilTagged(String tag) {
    return _readUntil(
      (text) => RegExp(
        r'(^|\r\n)'
        '$tag'
        r'\s+(OK|NO|BAD)\b',
        caseSensitive: false,
      ).hasMatch(text),
    );
  }

  Future<List<int>> _readUntil(bool Function(String text) done) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final text = latin1.decode(_buffer, allowInvalid: true);
      if (done(text)) {
        final bytes = List<int>.from(_buffer);
        _buffer.clear();
        return bytes;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw const MailException('Timed out while waiting for the IMAP server.');
  }
}

class ImapResponse {
  ImapResponse(this.text);

  factory ImapResponse.fromBytes(List<int> bytes) {
    return ImapResponse(latin1.decode(bytes, allowInvalid: true));
  }

  final String text;

  List<String> get lines {
    return text
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  List<int>? get firstLiteral {
    final marker = RegExp(r'\{(\d+)\}\r\n').firstMatch(text);
    if (marker == null) return null;
    final length = int.tryParse(marker.group(1) ?? '');
    if (length == null) return null;
    final start = marker.end;
    final bytes = latin1.encode(text);
    if (start + length > bytes.length) return null;
    return bytes.sublist(start, start + length);
  }

  bool isOk(String tag) {
    return statusLine(tag).toUpperCase().startsWith('$tag OK');
  }

  String statusLine(String tag) {
    return lines.lastWhere(
      (line) => line.toUpperCase().startsWith(tag.toUpperCase()),
      orElse: () => '',
    );
  }
}
