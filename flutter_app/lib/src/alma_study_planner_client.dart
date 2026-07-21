import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'alma_study_planner_models.dart';
import 'alma_web_session.dart';

const studyPlannerPath =
    '/alma/pages/startFlow.xhtml'
    '?_flowId=studyPlanner-flow'
    '&navigationPosition=hisinoneMeinStudium,hisinoneStudyPlanner'
    '&recordRequest=true';

class AlmaStudyPlannerClient {
  AlmaStudyPlannerClient({http.Client? httpClient})
    : _session = AlmaWebSession(httpClient: httpClient);

  final AlmaWebSession _session;

  Future<AlmaStudyPlannerPage> fetch({
    required String username,
    required String password,
  }) async {
    await _session.login(username: username, password: password);
    var response = await _session.getPath(studyPlannerPath);
    if (_session.looksLoggedOut(response.body)) {
      throw const AlmaStudyPlannerException(
        'ALMA session expired before the study planner loaded.',
      );
    }
    // The planner is a stateful JSF flow: the first GET can land on a
    // course-of-study selection page, then on the examination-structure tree
    // view. The credit/semester grid the parser reads only renders in the
    // "Modulplan" view, so advance through both steps before parsing.
    response = await _selectCourseIfNeeded(response);
    response = await _switchToModulplanIfNeeded(response);

    final pageUrl =
        response.request?.url.toString() ??
        '${AlmaWebSession.baseUrl}$studyPlannerPath';
    return parseStudyPlannerPage(response.body, pageUrl);
  }

  Future<http.Response> _selectCourseIfNeeded(http.Response response) async {
    final document = html_parser.parse(response.body);
    final trigger = _triggerIdEndingWith(
      document,
      ':doChangeDepp',
      containing: 'studentCourseOfStudySelection',
    );
    final form = document.getElementById('studyPlanner');
    if (trigger == null || form == null) return response;
    final action = form.attributes['action'];
    if (action == null || action.isEmpty) return response;
    final formId = form.id.isEmpty ? 'studyPlanner' : form.id;
    final target = _pageUrl(response).resolve(action);
    // `doChangeDepp` is a JSF AJAX action, and Spring Web Flow only advances the
    // flow on a partial/ajax request, answering with a <redirect> to the next
    // view-state (the URL the browser navigates to). Replay that request, then
    // follow the redirect to load the selected planner.
    final payload = _session.formPayload(form)
      ..[formId] = formId
      ..[trigger] = trigger
      ..['javax.faces.partial.ajax'] = 'true'
      ..['javax.faces.source'] = trigger
      ..['javax.faces.partial.execute'] = '@all'
      ..['javax.faces.partial.render'] =
          '$formId contentFrame $formId:messages-infobox'
      ..['javax.faces.behavior.event'] = 'action';
    final ajax = await _session.post(
      target,
      payload,
      extraHeaders: const <String, String>{
        'Faces-Request': 'partial/ajax',
        'X-Requested-With': 'XMLHttpRequest',
      },
    );
    final redirect = _partialResponseRedirect(ajax.body);
    if (redirect != null) return _session.get(target.resolve(redirect));
    return ajax;
  }

  Future<http.Response> _switchToModulplanIfNeeded(
    http.Response response,
  ) async {
    final document = html_parser.parse(response.body);
    if (_hasModulplanTable(document)) return response;
    final trigger = _triggerIdEndingWith(document, ':switchView');
    final form = document.getElementById('enrollTree');
    if (trigger == null || form == null) return response;
    final action = form.attributes['action'];
    if (action == null || action.isEmpty) return response;
    // The "Modulplan anzeigen" button is a plain (non-AJAX) form submit via
    // `myfaces.oam.submitForm`, which sets a hidden field named after the
    // button and the `activeView=mplan` parameter, then submits the form.
    final payload = _session.formPayload(form)
      ..['activePageElementId'] = trigger
      ..['refreshButtonClickedId'] = ''
      ..[trigger] = trigger
      ..['activeView'] = 'mplan';
    return _session.post(_pageUrl(response).resolve(action), payload);
  }

  Uri _pageUrl(http.Response response) =>
      response.request?.url ??
      Uri.parse('${AlmaWebSession.baseUrl}$studyPlannerPath');

  void close() => _session.close();
}

String? _partialResponseRedirect(String body) {
  final match = RegExp(r'<redirect\s+url="([^"]+)"').firstMatch(body);
  if (match == null) return null;
  return match.group(1)!.replaceAll('&amp;', '&');
}

bool _hasModulplanTable(Document document) => document
    .querySelectorAll('table')
    .any((element) => element.id.endsWith('modulAnchorsTable'));

String? _triggerIdEndingWith(
  Document document,
  String suffix, {
  String? containing,
}) {
  for (final element in document.querySelectorAll('a, button')) {
    final id = element.id;
    if (id.isEmpty || !id.endsWith(suffix)) continue;
    if (containing != null && !id.contains(containing)) continue;
    return id;
  }
  return null;
}

AlmaStudyPlannerPage parseStudyPlannerPage(String html, String pageUrl) {
  final document = html_parser.parse(html);
  final titleNode = document.querySelector('title');
  final title = titleNode != null ? _clean(titleNode.text) : 'Study planner';

  final table = _firstOrNull(
    document
        .querySelectorAll('table')
        .where((element) => element.id.endsWith('modulAnchorsTable')),
  );
  if (table == null) {
    final tableIds = document
        .querySelectorAll('table')
        .map((element) => element.id)
        .where((id) => id.isNotEmpty)
        .take(12)
        .toList();
    throw AlmaStudyPlannerException(
      'Could not find the Alma study planner table. '
      'title="$title"; '
      'bytes=${html.length}; '
      'looksLoggedOut=${html.contains('loginForm')}; '
      'stage=${_plannerStage(html)}; '
      'tableIds=${tableIds.isEmpty ? 'none' : tableIds.join('|')}',
    );
  }

  final semesters = <AlmaStudyPlannerSemester>[];
  final headers = table
      .querySelectorAll('thead th div')
      .where((div) => div.attributes['title'] == 'Studiensemester')
      .toList();
  var headerIndex = 0;
  for (final header in headers) {
    headerIndex++;
    final parts = _strippedStrings(header);
    if (parts.isEmpty) continue;
    semesters.add(
      AlmaStudyPlannerSemester(
        index: headerIndex,
        label: parts[0],
        termLabel: parts.length > 1 ? parts[1] : null,
      ),
    );
  }

  final modules = <AlmaStudyPlannerModule>[];
  var bodyRows = table.querySelectorAll('tbody tr');
  if (bodyRows.isEmpty) {
    final allRows = table.querySelectorAll('tr');
    bodyRows = allRows.length > 1 ? allRows.sublist(1) : const <Element>[];
  }
  var rowIndex = 0;
  for (final row in bodyRows) {
    rowIndex++;
    var columnStart = 1;
    for (final cell in row.children.where((e) => e.localName == 'td')) {
      final span = int.tryParse(cell.attributes['colspan'] ?? '1') ?? 1;
      final popup = cell.querySelector('.mouseMoveTitle .mouseMove');
      final summary = cell.querySelector(
        '.headerModulePlan .popupDismissable [title]',
      );
      final heading = _clean(
        popup != null
            ? popup.text
            : (summary != null ? (summary.attributes['title'] ?? '') : ''),
      );
      if (heading.isEmpty) {
        columnStart += span;
        continue;
      }
      final (number, moduleTitle) = _splitModuleHeading(heading);
      final detailLink = _firstOrNull(
        cell
            .querySelectorAll('a')
            .where(
              (a) => (a.attributes['href'] ?? '').contains(
                '_flowId=detailView-flow',
              ),
            ),
      );
      final creditsElement = _firstOrNull(
        cell
            .querySelectorAll('span')
            .where((span) => span.attributes['title'] == 'CP erworben/soll'),
      );
      final creditsSummary = creditsElement != null
          ? _clean(creditsElement.text)
          : null;
      final (earned, required) = _parseCreditProgress(creditsSummary);
      final detailHref = detailLink?.attributes['href'];
      modules.add(
        AlmaStudyPlannerModule(
          rowIndex: rowIndex,
          columnStart: columnStart,
          columnSpan: span,
          title: moduleTitle,
          number: number,
          creditsSummary: creditsSummary,
          creditsEarned: earned,
          creditsRequired: required,
          progressPercent: _progressPercent(earned, required),
          detailUrl: detailHref != null ? _resolve(pageUrl, detailHref) : null,
          isExpandable: cell
              .querySelectorAll('button')
              .any(
                (b) => (b.attributes['name'] ?? '').endsWith(':explodeModule'),
              ),
        ),
      );
      columnStart += span;
    }
  }

  bool buttonEnabled(String suffix) {
    final button = _firstOrNull(
      document
          .querySelectorAll('button')
          .where((b) => (b.attributes['name'] ?? '').endsWith(suffix)),
    );
    if (button == null) return false;
    return (button.attributes['class'] ?? '')
        .split(RegExp(r'\s+'))
        .contains('submit_checkbox_tick');
  }

  if (semesters.isEmpty && !html.contains('Studienplaner')) {
    throw const AlmaStudyPlannerException(
      'The response did not look like an Alma study planner page.',
    );
  }

  return AlmaStudyPlannerPage(
    title: title,
    pageUrl: pageUrl,
    semesters: semesters,
    modules: modules,
    viewState: AlmaStudyPlannerViewState(
      showRecommendedPlan: buttonEnabled(':switchMusterplan'),
      showMyModules: buttonEnabled(':switchMeineModule'),
      showAlternativeSemesters: buttonEnabled(':switchAlternativeFachsemester'),
    ),
  );
}

(String?, String) _splitModuleHeading(String value) {
  final heading = _clean(value);
  final separator = heading.indexOf(' - ');
  if (separator < 0) return (null, heading);
  final number = heading.substring(0, separator).trim();
  final title = heading.substring(separator + 3).trim();
  return (number.isEmpty ? null : number, title.isEmpty ? heading : title);
}

(double?, double?) _parseCreditProgress(String? value) {
  if (value == null || !value.contains('/')) return (null, null);
  final separator = value.indexOf('/');
  return (
    _parseCreditValue(value.substring(0, separator)),
    _parseCreditValue(value.substring(separator + 1)),
  );
}

double? _parseCreditValue(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  if (normalized == '-') return 0.0;
  return double.tryParse(normalized);
}

double? _progressPercent(double? earned, double? required) {
  if (earned == null || required == null || required <= 0) return null;
  final raw = (earned / required * 100).clamp(0.0, 100.0);
  return double.parse(raw.toStringAsFixed(1));
}

List<String> _strippedStrings(Element element) {
  final result = <String>[];
  void walk(Node node) {
    for (final child in node.nodes) {
      if (child is Text) {
        final cleaned = _clean(child.text);
        if (cleaned.isNotEmpty) result.add(cleaned);
      } else if (child is Element) {
        walk(child);
      }
    }
  }

  walk(element);
  return result;
}

/// Names which stage of the JSF planner flow a page represents, for
/// on-device diagnostics when the module grid is not found.
String _plannerStage(String html) {
  if (html.contains('studentCourseOfStudySelection')) return 'course_selection';
  if (html.contains('enrollTree:EnrollmentTree') &&
      !html.contains('modulAnchorsTable')) {
    return 'structure_tree';
  }
  if (!html.contains('Studienplaner')) return 'unknown_page';
  return 'planner_no_grid';
}

String _resolve(String base, String href) =>
    Uri.parse(base).resolve(href).toString();

String _clean(String value) =>
    value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).join(' ');

T? _firstOrNull<T>(Iterable<T> items) {
  final iterator = items.iterator;
  return iterator.moveNext() ? iterator.current : null;
}

class AlmaStudyPlannerException extends AlmaWebException {
  const AlmaStudyPlannerException(super.message);
}
