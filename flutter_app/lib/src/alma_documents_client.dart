import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'alma_web_session.dart';
import 'official_document_models.dart';

class AlmaDocumentsClient {
  AlmaDocumentsClient({http.Client? httpClient})
    : _session = AlmaWebSession(httpClient: httpClient);

  static const _enrollmentPath =
      '/alma/pages/cm/exa/enrollment/info/start.xhtml'
      '?_flowId=searchOwnEnrollmentInfo-flow'
      '&navigationPosition=hisinoneMeinStudium%2ChisinoneOwnEnrollmentList'
      '&recordRequest=true';
  static const _examPath =
      '/alma/pages/sul/examAssessment/personExamsReadonly.xhtml'
      '?_flowId=examsOverviewForPerson-flow'
      '&navigationPosition=hisinoneMeinStudium%2CexamAssessmentForStudent'
      '&recordRequest=true';
  static const _studyServicePath =
      '/alma/pages/cm/exa/enrollment/info/start.xhtml'
      '?_flowId=studyservice-flow'
      '&navigationPosition=hisinoneMeinStudium%2ChisinoneStudyservice'
      '&recordRequest=true';

  final AlmaWebSession _session;

  Future<List<OfficialDocument>> list({
    required String username,
    required String password,
  }) async {
    await _session.login(username: username, password: password);
    final enrollment = await _contract(_enrollmentPath, 'studentOverviewForm');
    final exams = await _contract(_examPath, 'examsReadonly');
    final certificates = await _certificateContract();
    return <OfficialDocument>[
      ..._documents(
        enrollment.form,
        OfficialDocumentKind.enrollment,
        (name) =>
            name.contains('enrollStudentListJobConfigurationButtons') &&
            name.endsWith(':job2'),
      ),
      ..._documents(
        exams.form,
        OfficialDocumentKind.transcript,
        (name) => name.contains('printReport'),
      ),
      ..._documents(
        certificates.form,
        OfficialDocumentKind.certificate,
        (name) => name.endsWith(':job2'),
      ),
    ];
  }

  Future<Uint8List> download({
    required String username,
    required String password,
    required OfficialDocument document,
  }) async {
    await _session.login(username: username, password: password);
    return switch (document.kind) {
      OfficialDocumentKind.enrollment => _downloadEnrollment(document),
      OfficialDocumentKind.transcript => _downloadTranscript(document),
      OfficialDocumentKind.certificate => _downloadCertificate(document),
    };
  }

  void close() => _session.close();

  Future<Uint8List> _downloadEnrollment(OfficialDocument document) async {
    final contract = await _contract(_enrollmentPath, 'studentOverviewForm');
    return _downloadDirect(contract, document.trigger);
  }

  Future<Uint8List> _downloadTranscript(OfficialDocument document) async {
    final contract = await _contract(_examPath, 'examsReadonly');
    final payload = Map<String, String>.from(contract.payload)
      ..['activePageElementId'] = document.trigger
      ..['refreshButtonClickedId'] = ''
      ..['examsReadonly:_idcl'] = document.trigger;
    final response = await _session.post(contract.action, payload);
    return _requirePdf(response, 'transcript');
  }

  Future<Uint8List> _downloadCertificate(OfficialDocument document) async {
    var contract = await _certificateContract();
    var response = await _session.post(
      contract.action,
      _actionPayload(contract.payload, document.trigger),
    );
    for (var attempt = 0; attempt < 6; attempt++) {
      final pdf = await _session.pdfFromResponse(response);
      if (pdf != null) return pdf;
      contract = _contractFromResponse(response, 'studyserviceForm');
      final trigger = _jobTrigger(contract.form);
      if (trigger == null) break;
      response = await _session.post(
        contract.action,
        _actionPayload(contract.payload, trigger),
      );
    }
    throw const AlmaDocumentsException(
      'ALMA did not finish generating this certificate. Please try again.',
    );
  }

  Future<Uint8List> _downloadDirect(
    _AlmaFormContract contract,
    String trigger,
  ) async {
    final response = await _session.post(
      contract.action,
      _actionPayload(contract.payload, trigger),
    );
    return _requirePdf(response, 'document');
  }

  Future<Uint8List> _requirePdf(http.Response response, String label) async {
    final pdf = await _session.pdfFromResponse(response);
    if (pdf == null) {
      throw AlmaDocumentsException('ALMA did not return the $label PDF.');
    }
    return pdf;
  }

  Future<_AlmaFormContract> _contract(String path, String formId) async {
    final response = await _session.getPath(path);
    if (_session.looksLoggedOut(response.body)) {
      throw const AlmaDocumentsException(
        'ALMA session expired while loading documents.',
      );
    }
    return _contractFromResponse(response, formId);
  }

  Future<_AlmaFormContract> _certificateContract() async {
    final initial = await _contract(_studyServicePath, 'studyserviceForm');
    final tab = initial.form
        .querySelectorAll('button[name]')
        .firstWhere(
          (button) => _clean(button.text).contains('Bescheide'),
          orElse: () => throw const AlmaDocumentsException(
            'ALMA did not expose the certificates tab.',
          ),
        );
    final trigger = tab.attributes['name']!;
    final payload = _actionPayload(initial.payload, trigger)
      ..[trigger] = _clean(
        tab.text,
      ).replaceAll('Aktive Registerkarte', '').trim()
      ..['studyserviceForm:_idcl'] = trigger
      ..['DISABLE_VALIDATION'] = 'true'
      ..['DISABLE_AUTOSCROLL'] = 'true';
    final response = await _session.post(initial.action, payload);
    return _contractFromResponse(response, 'studyserviceForm');
  }

  _AlmaFormContract _contractFromResponse(
    http.Response response,
    String formId,
  ) {
    final form = html_parser
        .parse(_partialMarkup(response.body))
        .getElementById(formId);
    if (form == null) {
      throw AlmaDocumentsException(
        'ALMA did not expose the $formId document form.',
      );
    }
    final action = form.attributes['action'];
    final pageUrl = response.request?.url ?? Uri.parse(AlmaWebSession.baseUrl);
    if (action == null || action.isEmpty) {
      throw const AlmaDocumentsException('ALMA document form has no action.');
    }
    return _AlmaFormContract(
      form: form,
      action: pageUrl.resolve(action),
      payload: _session.formPayload(form),
    );
  }
}

class _AlmaFormContract {
  const _AlmaFormContract({
    required this.form,
    required this.action,
    required this.payload,
  });

  final Element form;
  final Uri action;
  final Map<String, String> payload;
}

List<OfficialDocument> _documents(
  Element form,
  OfficialDocumentKind kind,
  bool Function(String name) matches,
) {
  final documents = <OfficialDocument>[];
  final seen = <String>{};
  for (final node in form.querySelectorAll('[name]')) {
    final trigger = node.attributes['name']!;
    if (!matches(trigger) || !seen.add(trigger)) continue;
    final label = _clean(
      node.querySelector('.jobname')?.text ??
          node.attributes['value'] ??
          node.text,
    );
    if (label.isEmpty) continue;
    documents.add(OfficialDocument(kind: kind, label: label, trigger: trigger));
  }
  return documents;
}

Map<String, String> _actionPayload(
  Map<String, String> source,
  String trigger,
) => Map<String, String>.from(source)
  ..['activePageElementId'] = trigger
  ..['refreshButtonClickedId'] = ''
  ..putIfAbsent(trigger, () => '');

String? _jobTrigger(Element form) {
  for (final node in form.querySelectorAll('[name]')) {
    final name = node.attributes['name']!;
    if (name.endsWith(':startJob') || name.endsWith(':jobDownloadPoll:poll')) {
      return name;
    }
  }
  return null;
}

String _partialMarkup(String response) {
  if (!response.contains('<partial-response')) return response;
  return RegExp(
    r'<update[^>]*><!\[CDATA\[(.*?)\]\]></update>',
    dotAll: true,
  ).allMatches(response).map((match) => match.group(1) ?? '').join('\n');
}

String _clean(String value) => value.split(RegExp(r'\s+')).join(' ').trim();

class AlmaDocumentsException implements Exception {
  const AlmaDocumentsException(this.message);

  final String message;

  @override
  String toString() => message;
}
