import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'alma_login_form.dart';
import 'ics_parser.dart';
import 'timetable_models.dart';

class AlmaTimetableClient {
  AlmaTimetableClient({http.Client? httpClient, IcsParser? icsParser})
    : _httpClient = httpClient ?? http.Client(),
      _icsParser = icsParser ?? const IcsParser();

  static const _baseUrl = 'https://alma.uni-tuebingen.de';
  static const _startPath = '/alma/pages/cs/sys/portal/hisinoneStartPage.faces';
  static const _timetablePath =
      '/alma/pages/plan/individualTimetable.xhtml'
      '?_flowId=individualTimetableSchedule-flow'
      '&navigationPosition=hisinoneMeinStudium%2CindividualTimetableSchedule'
      '&recordRequest=true';

  final http.Client _httpClient;
  final IcsParser _icsParser;
  final Map<String, String> _cookies = <String, String>{};

  Future<TimetableSnapshot> fetch({
    required String username,
    required String password,
  }) async {
    await _login(username: username, password: password);
    final timetable = await _get(Uri.parse('$_baseUrl$_timetablePath'));
    if (_looksLoggedOut(timetable.body)) {
      throw const AlmaTimetableException(
        'ALMA session expired before timetable loaded.',
      );
    }
    final contract = _TimetableContract.fromHtml(
      timetable.body,
      timetable.request?.url.toString() ?? '$_baseUrl$_timetablePath',
    );
    final exportUrl = contract.exportUrl;
    if (exportUrl == null || exportUrl.isEmpty) {
      throw const AlmaTimetableException(
        'ALMA did not expose a timetable export URL.',
      );
    }
    final resolvedExportUrl = _withSelectedTerm(
      exportUrl,
      contract.selectedTermValue,
    );
    final calendar = await _get(Uri.parse(resolvedExportUrl));
    final rawIcs = calendar.body;
    if (!rawIcs.contains('BEGIN:VCALENDAR')) {
      throw const AlmaTimetableException(
        'ALMA returned an unexpected timetable export.',
      );
    }
    return TimetableSnapshot(
      refreshedAt: DateTime.now(),
      sourceTerm: contract.selectedTermLabel ?? 'Current term',
      events: _icsParser.parseUpcoming(rawIcs),
    );
  }

  void close() => _httpClient.close();

  Future<void> _login({
    required String username,
    required String password,
  }) async {
    final start = await _get(Uri.parse('$_baseUrl$_startPath'));
    final form = extractAlmaLoginForm(
      html: start.body,
      pageUrl: start.request?.url ?? Uri.parse('$_baseUrl$_startPath'),
      exception: AlmaTimetableException.new,
    );
    final payload = <String, String>{
      ...form.payload,
      'asdf': username,
      'fdsa': password,
    };
    payload.putIfAbsent('submit', () => '');
    final response = await _post(form.action, payload);
    if (_looksLoggedOut(response.body)) {
      throw const AlmaTimetableException('ALMA login failed.');
    }
  }

  Future<http.Response> _get(Uri uri) async {
    final response = await _httpClient.get(uri, headers: _headers());
    _captureCookies(response);
    return response;
  }

  Future<http.Response> _post(Uri uri, Map<String, String> body) async {
    final response = await _httpClient.post(
      uri,
      headers: <String, String>{
        ..._headers(),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );
    _captureCookies(response);
    return response;
  }

  Map<String, String> _headers() {
    return <String, String>{
      'User-Agent':
          'StudyOS/1.0 (+https://github.com/Tue-StudyOS/StudyOS_Agent)',
      if (_cookies.isNotEmpty)
        'Cookie': _cookies.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join('; '),
    };
  }

  void _captureCookies(http.Response response) {
    final header = response.headers['set-cookie'];
    if (header == null || header.isEmpty) return;
    for (final cookie in header.split(',')) {
      final first = cookie.split(';').first;
      final separator = first.indexOf('=');
      if (separator > 0) {
        _cookies[first.substring(0, separator).trim()] = first
            .substring(separator + 1)
            .trim();
      }
    }
  }
}

class _TimetableContract {
  const _TimetableContract({
    required this.exportUrl,
    required this.selectedTermValue,
    required this.selectedTermLabel,
  });

  final String? exportUrl;
  final String? selectedTermValue;
  final String? selectedTermLabel;

  static _TimetableContract fromHtml(String html, String pageUrl) {
    final document = html_parser.parse(html);
    final textarea = document.querySelector(
      'textarea[name="plan:scheduleConfiguration:anzeigeoptionen:ical:cal_add"]',
    );
    final select = document.querySelector(
      'select[name="plan:scheduleConfiguration:anzeigeoptionen:changeTerm_input"]',
    );
    String? selectedValue;
    String? selectedLabel;
    if (select != null) {
      final selected =
          select.querySelector('option[selected]') ??
          select.querySelector('option');
      selectedValue = selected?.attributes['value']?.trim();
      selectedLabel = selected?.text.trim();
    }
    final rawExportUrl = textarea?.text.trim();
    final exportUrl = rawExportUrl == null || rawExportUrl.isEmpty
        ? null
        : Uri.parse(pageUrl).resolve(rawExportUrl).toString();
    return _TimetableContract(
      exportUrl: exportUrl,
      selectedTermValue: selectedValue,
      selectedTermLabel: selectedLabel,
    );
  }
}

String _withSelectedTerm(String exportUrl, String? termValue) {
  if (termValue == null || termValue.isEmpty) return exportUrl;
  final uri = Uri.parse(exportUrl);
  return uri
      .replace(
        queryParameters: <String, String>{
          ...uri.queryParameters,
          'termgroup': termValue,
        },
      )
      .toString();
}

bool _looksLoggedOut(String html) {
  return RegExp(
        r'''<body[^>]*class=["'][^"']*notloggedin''',
        caseSensitive: false,
      ).hasMatch(html) ||
      RegExp(
        r'''<form[^>]*id=["']loginForm["']''',
        caseSensitive: false,
      ).hasMatch(html);
}

class AlmaTimetableException implements Exception {
  const AlmaTimetableException(this.message);

  final String message;

  @override
  String toString() => message;
}
