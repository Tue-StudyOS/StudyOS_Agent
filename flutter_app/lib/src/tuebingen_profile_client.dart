import 'dart:async';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class StudentProfilePrefill {
  const StudentProfilePrefill({
    this.displayName,
    this.email,
    this.degreeProgram,
    this.warning,
  });

  final String? displayName;
  final String? email;
  final String? degreeProgram;
  final String? warning;
}

class TuebingenProfileClient {
  TuebingenProfileClient({
    http.Client? httpClient,
    this.baseUrl = 'https://alma.uni-tuebingen.de',
    this.timeout = const Duration(seconds: 18),
    this.optionalTimeout = const Duration(seconds: 10),
  }) : _http = _CookieClient(httpClient ?? http.Client());

  final _CookieClient _http;
  final String baseUrl;
  final Duration timeout;
  final Duration optionalTimeout;

  static const String _startPath =
      '/alma/pages/cs/sys/portal/hisinoneStartPage.faces';
  static const String _studyServicePath =
      '/alma/pages/cm/exa/enrollment/info/start.xhtml'
      '?_flowId=studyservice-flow'
      '&navigationPosition=hisinoneMeinStudium%2ChisinoneStudyservice'
      '&recordRequest=true';
  static const String _studyPlannerUrl =
      'https://alma.uni-tuebingen.de/alma/pages/startFlow.xhtml'
      '?_flowId=studyPlanner-flow'
      '&navigationPosition=hisinoneMeinStudium,hisinoneStudyPlanner'
      '&recordRequest=true';

  Future<StudentProfilePrefill> fetch({
    required String username,
    required String password,
  }) async {
    await _login(username: username, password: password);

    String? displayName;
    String? degreeProgram;
    final warnings = <String>[];

    try {
      final response = await _http
          .get(_resolve(_studyServicePath))
          .timeout(optionalTimeout);
      _ensureOk(response);
      displayName = _parseStudyServiceName(response.body);
    } on Object catch (error) {
      warnings.add('Could not load account name from ALMA: ${_message(error)}');
    }

    try {
      final response = await _http
          .get(Uri.parse(_studyPlannerUrl))
          .timeout(optionalTimeout);
      _ensureOk(response);
      degreeProgram = _degreeFromPlannerTitle(response.body);
    } on Object catch (error) {
      warnings.add(
        'Could not load degree program from ALMA: ${_message(error)}',
      );
    }

    return StudentProfilePrefill(
      displayName: displayName,
      degreeProgram: degreeProgram,
      warning: warnings.isEmpty ? null : warnings.join(' '),
    );
  }

  Future<void> close() => _http.close();

  Future<void> _login({
    required String username,
    required String password,
  }) async {
    final start = await _http.get(_resolve(_startPath)).timeout(timeout);
    _ensureOk(start);
    final form = _extractLoginForm(
      start.body,
      start.request?.url ?? _resolve(_startPath),
    );
    final payload = Map<String, String>.from(form.payload)
      ..['asdf'] = username
      ..['fdsa'] = password
      ..putIfAbsent('submit', () => '');

    final login = await _http.post(form.action, body: payload).timeout(timeout);
    _ensureOk(login);
    if (_looksLoggedOut(login.body)) {
      throw const TuebingenProfileException(
        'ALMA login failed. Check your university ID and password.',
      );
    }
  }

  Uri _resolve(String path) => Uri.parse(baseUrl).resolve(path);

  void _ensureOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw TuebingenProfileException(
        'ALMA returned HTTP ${response.statusCode}.',
      );
    }
  }
}

class TuebingenProfileException implements Exception {
  const TuebingenProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _LoginForm {
  const _LoginForm({required this.action, required this.payload});

  final Uri action;
  final Map<String, String> payload;
}

class _CookieClient {
  _CookieClient(this._inner);

  final http.Client _inner;
  final Map<String, String> _cookies = <String, String>{};

  Future<http.Response> get(Uri url) => _send('GET', url);

  Future<http.Response> post(
    Uri url, {
    required Map<String, String> body,
  }) async {
    return _send('POST', url, body: body);
  }

  Future<void> close() async => _inner.close();

  Future<http.Response> _send(
    String method,
    Uri url, {
    Map<String, String>? body,
  }) async {
    var nextMethod = method;
    var nextUrl = url;
    var nextBody = body;

    for (var redirects = 0; redirects < 8; redirects += 1) {
      final request = http.Request(nextMethod, nextUrl)
        ..followRedirects = false
        ..headers.addAll(_headers());
      if (nextBody != null) request.bodyFields = nextBody;

      final streamed = await _inner.send(request);
      final response = await http.Response.fromStream(streamed);
      _captureCookies(response);

      final location = response.headers['location'];
      if (!_isRedirect(response.statusCode) || location == null) {
        return response;
      }

      nextUrl = nextUrl.resolve(location);
      if (_redirectsToGet(response.statusCode, nextMethod)) {
        nextMethod = 'GET';
        nextBody = null;
      }
    }

    throw const TuebingenProfileException('ALMA redirected too many times.');
  }

  Map<String, String> _headers() {
    return <String, String>{
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'de-DE,de;q=0.9,en;q=0.8',
      'User-Agent': 'tue-api-wrapper/0.1 (+https://alma.uni-tuebingen.de/)',
      if (_cookies.isNotEmpty)
        'Cookie': _cookies.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join('; '),
    };
  }

  void _captureCookies(http.Response response) {
    final header = response.headers['set-cookie'];
    if (header == null || header.isEmpty) return;
    for (final rawCookie in header.split(RegExp(r',(?=\s*[^;,]+=)'))) {
      final pair = rawCookie.split(';').first.trim();
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      _cookies[pair.substring(0, index)] = pair.substring(index + 1);
    }
  }
}

bool _isRedirect(int statusCode) {
  return statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;
}

bool _redirectsToGet(int statusCode, String method) {
  return statusCode == 303 ||
      (method == 'POST' && (statusCode == 301 || statusCode == 302));
}

_LoginForm _extractLoginForm(String html, Uri pageUrl) {
  final document = html_parser.parse(html);
  final form =
      document.getElementById('loginForm') ??
      document.getElementById('mobileLoginForm');
  if (form == null) {
    throw const TuebingenProfileException('Could not find ALMA login form.');
  }

  final action = form.attributes['action'];
  if (action == null || action.isEmpty) {
    throw const TuebingenProfileException('ALMA login form has no action.');
  }

  final payload = <String, String>{};
  for (final input in form.getElementsByTagName('input')) {
    final name = input.attributes['name'];
    final type = input.attributes['type'] ?? '';
    if (name == null ||
        name.isEmpty ||
        type == 'checkbox' ||
        type == 'button') {
      continue;
    }
    payload[name] = input.attributes['value'] ?? '';
  }

  payload.putIfAbsent('submit', () => '');
  return _LoginForm(action: pageUrl.resolve(action), payload: payload);
}

bool _looksLoggedOut(String html) {
  final document = html_parser.parse(html);
  return document.getElementById('loginForm') != null ||
      document.getElementById('mobileLoginForm') != null;
}

String? _parseStudyServiceName(String html) {
  final document = html_parser.parse(html);
  final form = document.getElementById('studyserviceForm');
  if (form == null) return null;
  for (final heading in form.getElementsByTagName('h2')) {
    final text = _clean(heading.text);
    final match = RegExp(r'Personendaten:\s*(.+)$').firstMatch(text);
    if (match != null) return _emptyToNull(match.group(1));
  }
  return null;
}

String? _degreeFromPlannerTitle(String html) {
  final document = html_parser.parse(html);
  final title = _emptyToNull(
    _clean(document.querySelector('title')?.text ?? ''),
  );
  if (title == null) return null;
  final match = RegExp(
    r'^Studienplaner mit Modulplan\s+(.+?)(?:\s+\([^)]+\))?$',
  ).firstMatch(title);
  return _emptyToNull(match?.group(1) ?? title);
}

String _clean(String value) => value.split(RegExp(r'\s+')).join(' ').trim();

String? _emptyToNull(String? value) {
  final cleaned = _clean(value ?? '');
  return cleaned.isEmpty ? null : cleaned;
}

String _message(Object error) {
  if (error is TimeoutException) return 'request timed out';
  if (error is TuebingenProfileException) return error.message;
  if (error is http.ClientException) return error.message;
  return 'request failed';
}
