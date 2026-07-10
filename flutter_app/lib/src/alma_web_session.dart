import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:http/http.dart' as http;

import 'alma_login_form.dart';

class AlmaWebSession {
  AlmaWebSession({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  static const baseUrl = 'https://alma.uni-tuebingen.de';
  static const _startPath = '/alma/pages/cs/sys/portal/hisinoneStartPage.faces';

  final http.Client _http;
  final Map<String, String> _cookies = <String, String>{};

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final start = await getPath(_startPath);
    if (!looksLoggedOut(start.body)) return;
    final form = extractAlmaLoginForm(
      html: start.body,
      pageUrl: start.request?.url ?? Uri.parse('$baseUrl$_startPath'),
      exception: AlmaWebException.new,
    );
    final response = await post(
      form.action,
      Map<String, String>.from(form.payload)
        ..['asdf'] = username
        ..['fdsa'] = password
        ..putIfAbsent('submit', () => ''),
    );
    if (looksLoggedOut(response.body)) {
      throw const AlmaWebException('ALMA login failed.');
    }
  }

  Future<http.Response> getPath(String path) => get(Uri.parse('$baseUrl$path'));

  Future<http.Response> get(Uri url) async {
    final response = await _http.get(url, headers: _headers());
    _captureCookies(response);
    return response;
  }

  Future<http.Response> post(Uri url, Map<String, String> body) async {
    final response = await _http.post(
      url,
      headers: <String, String>{
        ..._headers(),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );
    _captureCookies(response);
    final location = response.headers['location'];
    if (_isPostRedirect(response.statusCode) && location != null) {
      final destination = url.resolve(location);
      if (destination.host != Uri.parse(baseUrl).host) {
        throw const AlmaWebException(
          'ALMA redirected the request to an unexpected host.',
        );
      }
      return get(destination);
    }
    return response;
  }

  Future<Uint8List?> pdfFromResponse(http.Response response) async {
    if (isPdf(response)) return response.bodyBytes;
    final href = RegExp(
      r'''href=["']([^"']*state=docdownload[^"']*)["']''',
      caseSensitive: false,
    ).firstMatch(response.body)?.group(1)?.replaceAll('&amp;', '&');
    if (href == null || href.isEmpty) return null;
    final pageUrl = response.request?.url ?? Uri.parse(baseUrl);
    final download = await get(pageUrl.resolve(href));
    return isPdf(download) ? download.bodyBytes : null;
  }

  Map<String, String> formPayload(Element form) {
    final payload = <String, String>{};
    for (final field in form.querySelectorAll('input, select, textarea')) {
      final name = field.attributes['name'];
      if (name == null || name.isEmpty) continue;
      if (field.localName == 'select') {
        payload[name] =
            field.querySelector('option[selected]')?.attributes['value'] ?? '';
        continue;
      }
      if (field.localName == 'textarea') {
        payload[name] = field.text;
        continue;
      }
      final type = field.attributes['type']?.toLowerCase() ?? '';
      if (const <String>{
        'button',
        'file',
        'image',
        'password',
        'reset',
        'submit',
      }.contains(type)) {
        continue;
      }
      payload[name] = field.attributes['value'] ?? '';
    }
    return payload;
  }

  bool looksLoggedOut(String html) =>
      html.contains('id="loginForm"') || html.contains("id='loginForm'");

  bool isPdf(http.Response response) =>
      _startsWithPdf(response.bodyBytes) ||
      (response.headers['content-type']?.toLowerCase().contains('pdf') ??
          false);

  void close() => _http.close();

  Map<String, String> _headers() => <String, String>{
    'User-Agent': 'StudyOS/1.0 (+https://github.com/Tue-StudyOS/StudyOS_Agent)',
    if (_cookies.isNotEmpty)
      'Cookie': _cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; '),
  };

  void _captureCookies(http.Response response) {
    final header = response.headers['set-cookie'];
    if (header == null || header.isEmpty) return;
    for (final cookie in header.split(',')) {
      final pair = cookie.split(';').first;
      final separator = pair.indexOf('=');
      if (separator > 0) {
        _cookies[pair.substring(0, separator).trim()] = pair
            .substring(separator + 1)
            .trim();
      }
    }
  }
}

class AlmaWebException implements Exception {
  const AlmaWebException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool _isPostRedirect(int statusCode) =>
    statusCode == 301 || statusCode == 302 || statusCode == 303;

bool _startsWithPdf(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x25 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x44 &&
    bytes[3] == 0x46;
