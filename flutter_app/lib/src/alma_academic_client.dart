import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'academic_models.dart';
import 'alma_web_session.dart';

typedef PdfTextExtractor = Future<String> Function(Uint8List document);

class AlmaAcademicClient {
  AlmaAcademicClient({http.Client? httpClient, this.pdfTextExtractor})
    : _session = AlmaWebSession(httpClient: httpClient);

  static const _enrollmentPath =
      '/alma/pages/cm/exa/enrollment/info/start.xhtml'
      '?_flowId=searchOwnEnrollmentInfo-flow'
      '&navigationPosition=hisinoneMeinStudium%2ChisinoneOwnEnrollmentList'
      '&recordRequest=true';

  final AlmaWebSession _session;
  final PdfTextExtractor? pdfTextExtractor;

  Future<AcademicStatusSnapshot> fetch({
    required String username,
    required String password,
  }) async {
    final overview = await _loadOverview(
      username: username,
      password: password,
    );
    final extractor = pdfTextExtractor;
    if (extractor == null) {
      return parseAcademicStatus(overview.body, now: DateTime.now());
    }
    final report = await _downloadRegistrationReport(overview);
    return parseAcademicReport(await extractor(report), now: DateTime.now());
  }

  Future<Uint8List> downloadRegistrationReport({
    required String username,
    required String password,
  }) async => _downloadRegistrationReport(
    await _loadOverview(username: username, password: password),
  );

  void close() => _session.close();

  Future<http.Response> _loadOverview({
    required String username,
    required String password,
  }) async {
    await _session.login(username: username, password: password);
    final overview = await _session.getPath(_enrollmentPath);
    if (_session.looksLoggedOut(overview.body)) {
      throw const AlmaAcademicException(
        'ALMA session expired before academic status loaded.',
      );
    }
    return overview;
  }

  Future<Uint8List> _downloadRegistrationReport(http.Response overview) async {
    final form = html_parser
        .parse(overview.body)
        .getElementById('studentOverviewForm');
    if (form == null) {
      throw const AlmaAcademicException(
        'ALMA did not expose the registration report form.',
      );
    }
    final trigger = _reportTrigger(form);
    final action = form.attributes['action'];
    if (trigger == null || action == null || action.isEmpty) {
      throw const AlmaAcademicException(
        'ALMA did not expose the registration report action.',
      );
    }
    final payload = _session.formPayload(form)
      ..['activePageElementId'] = trigger
      ..['refreshButtonClickedId'] = ''
      ..putIfAbsent(trigger, () => '');
    final pageUrl = overview.request?.url ?? Uri.parse(AlmaWebSession.baseUrl);
    final response = await _session.post(pageUrl.resolve(action), payload);
    final pdf = await _session.pdfFromResponse(response);
    if (pdf == null) {
      throw const AlmaAcademicException(
        'ALMA did not return the registration report PDF. Please try again.',
      );
    }
    return pdf;
  }

  String? _reportTrigger(Element form) {
    final candidates = form.querySelectorAll(
      '[name*="enrollStudentListJobConfigurationButtons"]',
    );
    for (final candidate in candidates) {
      final name = candidate.attributes['name'];
      final label = _clean(candidate.text);
      if (name != null &&
          name.endsWith(':job2') &&
          label.contains('Belegungen und Prüfungsanmeldungen')) {
        return name;
      }
    }
    for (final candidate in candidates) {
      final name = candidate.attributes['name'];
      if (name != null && name.endsWith(':job2')) return name;
    }
    return null;
  }
}

AcademicStatusSnapshot parseAcademicStatus(
  String html, {
  required DateTime now,
}) {
  final document = html_parser.parse(html);
  final term = document
      .querySelector('select[name*="termPeriodDropDownList"] option[selected]')
      ?.text
      .trim();
  final entries = <AcademicEntry>[];
  for (final heading in document.querySelectorAll('h2')) {
    final text = _clean(heading.text);
    final match = RegExp(r'^(Veranstaltung|Prüfung):\s*(.+)$').firstMatch(text);
    if (match == null) continue;
    final tableText = _clean(
      heading.parent?.querySelector('table')?.text ?? '',
    );
    entries.add(
      AcademicEntry(
        category: match.group(1)!,
        title: match.group(2)!,
        status: _afterLabel(tableText, 'Ihr aktueller Status'),
        detail: _afterLabel(tableText, 'Semester der Leistung'),
      ),
    );
  }
  return AcademicStatusSnapshot(
    term: term,
    entries: entries,
    refreshedAt: now,
    notice: entries.isEmpty
        ? 'ALMA did not expose registrations in the overview.'
        : null,
  );
}

AcademicStatusSnapshot parseAcademicReport(
  String text, {
  required DateTime now,
}) {
  final term = RegExp(
    r'\b(?:Wintersemester|Sommersemester)\s+\d{4}(?:/\d{2})?',
  ).firstMatch(text)?.group(0);
  final entries = <AcademicEntry>[];
  final seen = <String>{};
  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final line = _clean(rawLine);
    final match = RegExp(
      r'^([A-ZÄÖÜ]+(?:-[A-ZÄÖÜ]+)*(?:-\d+(?:CP)?)*)(.*?)(?:\s+(\d+\.\s*PG))?\s+(zugelassen|angemeldet|abgemeldet)\b',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) continue;
    final number = match.group(1)!;
    final title = _clean(match.group(2) ?? '');
    if (title.isEmpty || !seen.add('$number:$title')) continue;
    final group = match.group(3);
    entries.add(
      AcademicEntry(
        category: 'Registration',
        title: title,
        status: match.group(4),
        detail: group == null ? number : '$number · $group',
      ),
    );
  }
  return AcademicStatusSnapshot(
    term: term,
    entries: entries,
    refreshedAt: now,
    notice: entries.isEmpty
        ? 'The official ALMA registration report contains no current registrations.'
        : null,
  );
}

String _clean(String value) => value.split(RegExp(r'\s+')).join(' ').trim();

String? _afterLabel(String text, String label) {
  final match = RegExp(
    '${RegExp.escape(label)}:${r'\s*([^:]+?)(?=\s+[A-ZÄÖÜ][^:]+:|$)'}',
  ).firstMatch(text);
  final value = _clean(match?.group(1) ?? '');
  return value.isEmpty ? null : value;
}

class AlmaAcademicException extends AlmaWebException {
  const AlmaAcademicException(super.message);
}
