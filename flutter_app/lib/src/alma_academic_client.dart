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

final _headingPattern = RegExp(r'^(Veranstaltung|Prüfung):\s*(.+)$');
final _codePattern = RegExp(
  r'^([A-ZÄÖÜ]+[A-ZÄÖÜ0-9-]*\d+[A-Z]*|GTCNEURO)\s+(.+)$',
);
final _embeddedCodePattern = RegExp(
  r'([A-ZÄÖÜ]+[A-ZÄÖÜ0-9-]*\d+[A-Z]*|GTCNEURO)\s+(.+)$',
);
final _scheduleNoisePattern = RegExp(
  r'\b(?:Status|Aktionen|Details anzeigen|Informationen zu Belegzeiträumen|'
  r'Ab-/Ummelden|Raumdetails für .+? anzeigen)\b',
);

AcademicStatusSnapshot parseAcademicStatus(
  String html, {
  required DateTime now,
}) {
  final document = html_parser.parse(html);
  final scope =
      document.getElementById('studentOverviewForm') ??
      document.documentElement;

  final availableTerms = <String>[];
  String? selectedTerm;
  final select = scope?.querySelector('select[name*="termPeriodDropDownList"]');
  if (select != null) {
    for (final option in select.querySelectorAll('option')) {
      final label = _clean(option.text);
      final value = (option.attributes['value'] ?? '').trim();
      if (label.isEmpty || value.isEmpty) continue;
      availableTerms.add(label);
      if (option.attributes.containsKey('selected')) selectedTerm = label;
    }
  }

  final preorder = <Element>[];
  void collect(Element element) {
    preorder.add(element);
    for (final child in element.children) {
      collect(child);
    }
  }

  if (scope != null) collect(scope);

  final entries = <AcademicEntry>[];
  for (var index = 0; index < preorder.length; index++) {
    final element = preorder[index];
    if (element.localName != 'h2') continue;
    final match = _headingPattern.firstMatch(_clean(element.text));
    if (match == null) continue;
    final category = match.group(1)!;
    final table = _followingTable(preorder, index);
    if (table == null) continue;
    final scheduleText = _scheduleText(table);
    final (eventType, number, title) = _entryIdentity(
      category,
      match.group(2)!,
      scheduleText,
    );
    final statusText = _statusText(table);
    final semester = _afterLabel(statusText, 'Semester der Leistung');
    entries.add(
      AcademicEntry(
        category: category,
        title: title,
        eventType: eventType,
        number: number,
        status: _afterLabel(statusText, 'Ihr aktueller Status'),
        semester: semester,
        detail: semester,
        scheduleText: scheduleText,
        detailUrl: _detailUrl(table),
        attempt: _afterLabel(statusText, 'Versuch (gilt nur für Prüfungen)'),
      ),
    );
  }

  return AcademicStatusSnapshot(
    term: selectedTerm,
    availableTerms: availableTerms,
    entries: entries,
    refreshedAt: now,
    notice: entries.isEmpty
        ? 'ALMA did not expose registrations in the overview.'
        : null,
  );
}

Element? _followingTable(List<Element> preorder, int fromIndex) {
  for (var index = fromIndex + 1; index < preorder.length; index++) {
    if (preorder[index].localName == 'table') return preorder[index];
  }
  return null;
}

(String?, String?, String) _entryIdentity(
  String category,
  String headingTitle,
  String? scheduleText,
) {
  if (category == 'Prüfung') {
    final (number, fallbackTitle) = _splitCode(headingTitle);
    return (category, number, _examTitle(scheduleText) ?? fallbackTitle);
  }
  final cleaned = _clean(headingTitle);
  final embedded = _embeddedCodePattern.firstMatch(cleaned);
  if (embedded == null) {
    final (number, title) = _splitCode(headingTitle);
    return (category, number, title);
  }
  final eventType = _clean(cleaned.substring(0, embedded.start));
  return (
    eventType.isEmpty ? category : eventType,
    embedded.group(1),
    embedded.group(2)!,
  );
}

(String?, String) _splitCode(String value) {
  final cleaned = _clean(value);
  final match = _codePattern.firstMatch(cleaned);
  if (match == null) return (null, cleaned);
  return (match.group(1), match.group(2)!);
}

String? _examTitle(String? scheduleText) {
  if (scheduleText == null || scheduleText.isEmpty) return null;
  var value = scheduleText.replaceFirst(
    RegExp(r'^\d+\.\s*Parallelgruppe\s+'),
    '',
  );
  value = value
      .split(
        RegExp(
          r'\s+(?:Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag)'
          r'\s+\d{2}\.\d{2}\.\d{2}\b',
        ),
      )
      .first;
  value = value
      .split(
        RegExp(r'\s+(?:Keine Uhrzeit festgelegt|Prüfungsform:|Prüfer/-in:)'),
      )
      .first;
  final cleaned = _clean(value);
  return cleaned.isEmpty ? null : cleaned;
}

String? _scheduleText(Element table) {
  final candidates = table
      .querySelectorAll('td')
      .map((cell) => _clean(cell.text))
      .toList();
  if (candidates.isEmpty) return null;
  final datePattern = RegExp(r'\b\d{2}\.\d{2}\.\d{2}\b');
  final value = candidates.firstWhere(
    (candidate) =>
        !candidate.contains('Ihr aktueller Status:') &&
        (candidate.contains('Parallelgruppe') ||
            candidate.contains('Prüfungsform:') ||
            datePattern.hasMatch(candidate)),
    orElse: () => candidates.first,
  );
  final cleaned = _clean(value.replaceAll(_scheduleNoisePattern, ' '));
  return cleaned.isEmpty ? null : cleaned;
}

String _statusText(Element table) {
  for (final cell in table.querySelectorAll('td')) {
    final value = _clean(cell.text);
    if (value.contains('Ihr aktueller Status:')) return value;
  }
  return _clean(table.text);
}

String? _detailUrl(Element table) {
  for (final anchor in table.querySelectorAll('a')) {
    final href = anchor.attributes['href'];
    if (href != null && href.contains('_flowId=detailView-flow')) {
      return Uri.parse('${AlmaWebSession.baseUrl}/').resolve(href).toString();
    }
  }
  return null;
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
