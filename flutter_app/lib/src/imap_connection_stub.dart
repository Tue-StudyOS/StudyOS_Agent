import 'mail_models.dart';

class ImapConnection {
  static Future<ImapConnection> connect({
    required String host,
    required int port,
    required Duration timeout,
  }) async {
    throw const MailException(
      'University mail is not available on this platform.',
    );
  }

  Future<ImapResponse> command(String command) async {
    throw const MailException(
      'University mail is not available on this platform.',
    );
  }

  void close() {}
}

class ImapResponse {
  ImapResponse(this.text);

  final String text;
  List<String> get lines => const <String>[];
  List<int>? get firstLiteral => null;
  bool isOk(String tag) => false;
  String statusLine(String tag) => '';
}
