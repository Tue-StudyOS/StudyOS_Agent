import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'private_study_models.dart';

class PortalResponse {
  const PortalResponse({required this.response, required this.url});

  final http.Response response;
  final Uri url;
  String get body => response.body;
}

class PortalForm {
  const PortalForm({required this.action, required this.payload});

  final Uri action;
  final Map<String, String> payload;
}

class PortalHttpSession {
  PortalHttpSession({
    http.Client? client,
    this.timeout = const Duration(seconds: 18),
    this.allowedHostSuffix = 'uni-tuebingen.de',
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  final String allowedHostSuffix;
  final Map<String, Map<String, String>> _cookiesByHost = {};

  Future<PortalResponse> get(Uri url) => _send('GET', url);

  Future<PortalResponse> postForm(PortalForm form) =>
      _send('POST', form.action, form: form.payload);

  Future<PortalResponse> postJson(Uri url, Object body, {Uri? referer}) =>
      _send('POST', url, jsonBody: jsonEncode(body), referer: referer);

  /// Posts a form that may legitimately repeat a field name (for example the
  /// Shibboleth attribute-release consent page, which renders one
  /// `_shib_idp_consentIds` checkbox per attribute). A [Map] payload cannot
  /// represent repeated keys, so these are encoded as an ordered list.
  Future<PortalResponse> postFormFields(
    Uri action,
    List<MapEntry<String, String>> fields, {
    Uri? referer,
  }) =>
      _send('POST', action, formBody: _encodeFields(fields), referer: referer);

  Future<PortalResponse> _send(
    String method,
    Uri url, {
    Map<String, String>? form,
    String? formBody,
    String? jsonBody,
    Uri? referer,
  }) async {
    var nextMethod = method;
    var nextUrl = url;
    var nextForm = form;
    var nextFormBody = formBody;
    var nextJson = jsonBody;
    for (var redirects = 0; redirects < 10; redirects += 1) {
      _validateUrl(nextUrl);
      final cookies = _cookiesByHost[nextUrl.host];
      final request = http.Request(nextMethod, nextUrl)
        ..followRedirects = false
        ..headers.addAll(<String, String>{
          'Accept': 'text/html,application/json,*/*;q=0.8',
          'User-Agent':
              'StudyOS/1.0 (+https://github.com/Tue-StudyOS/StudyOS_Agent)',
          if (cookies?.isNotEmpty == true)
            'Cookie': cookies!.entries
                .map((entry) => '${entry.key}=${entry.value}')
                .join('; '),
          if (referer != null) 'Referer': referer.toString(),
        });
      if (nextForm != null) request.bodyFields = nextForm;
      if (nextFormBody != null) {
        request.headers['Content-Type'] =
            'application/x-www-form-urlencoded; charset=utf-8';
        request.body = nextFormBody;
      }
      if (nextJson != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = nextJson;
      }
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(timeout);
      _captureCookies(response, nextUrl.host);
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw PortalException('Portal returned HTTP ${response.statusCode}.');
      }
      final location = response.headers['location'];
      if (!_isRedirect(response.statusCode) || location == null) {
        return PortalResponse(response: response, url: nextUrl);
      }
      nextUrl = nextUrl.resolve(location);
      if (response.statusCode == 303 ||
          (nextMethod == 'POST' && response.statusCode < 303)) {
        nextMethod = 'GET';
        nextForm = null;
        nextFormBody = null;
        nextJson = null;
      }
    }
    throw const PortalException('Portal redirected too many times.');
  }

  void close() {
    _cookiesByHost.clear();
    if (_ownsClient) _client.close();
  }

  static String _encodeFields(List<MapEntry<String, String>> fields) => fields
      .map(
        (field) =>
            '${Uri.encodeQueryComponent(field.key)}='
            '${Uri.encodeQueryComponent(field.value)}',
      )
      .join('&');

  void _captureCookies(http.Response response, String host) {
    final header = response.headers['set-cookie'];
    if (header == null) return;
    for (final raw in header.split(RegExp(r',(?=\s*[^;,]+=)'))) {
      final pair = raw.split(';').first.trim();
      final separator = pair.indexOf('=');
      if (separator > 0) {
        (_cookiesByHost[host] ??= <String, String>{})[pair.substring(
          0,
          separator,
        )] = pair.substring(
          separator + 1,
        );
      }
    }
  }

  void _validateUrl(Uri url) {
    final hostAllowed =
        url.host == allowedHostSuffix ||
        url.host.endsWith('.$allowedHostSuffix');
    if (url.scheme != 'https' || !hostAllowed) {
      throw const PortalException(
        'Portal redirected to an untrusted destination.',
      );
    }
  }
}

Uri portalLink(String html, Uri pageUrl, String marker) {
  final document = html_parser.parse(html);
  for (final link in document.querySelectorAll('a[href]')) {
    final href = link.attributes['href'];
    if (href != null && href.contains(marker)) return pageUrl.resolve(href);
  }
  throw const PortalException('Could not find the portal login link.');
}

PortalForm portalForm(
  String html,
  Uri pageUrl, {
  required Set<String> requiredFields,
}) {
  final document = html_parser.parse(html);
  for (final form in document.querySelectorAll('form')) {
    final payload = _formPayload(form, requiredFields);
    if (requiredFields.every(payload.containsKey)) {
      return PortalForm(
        action: pageUrl.resolve(form.attributes['action'] ?? ''),
        payload: payload,
      );
    }
  }
  throw const PortalException('Could not find the expected portal form.');
}

Map<String, String> _formPayload(Element form, Set<String> requiredFields) {
  final result = <String, String>{};
  for (final input in form.querySelectorAll('input[name]')) {
    if (input.attributes['type']?.toLowerCase() == 'checkbox') continue;
    result[input.attributes['name']!] = input.attributes['value'] ?? '';
  }
  for (final button in form.querySelectorAll('button[name]')) {
    final name = button.attributes['name']!;
    final type = button.attributes['type']?.toLowerCase() ?? 'submit';
    if (type == 'submit' && requiredFields.contains(name)) {
      result[name] = button.attributes['value'] ?? '';
    }
  }
  return result;
}

Future<PortalResponse> completeSaml(
  PortalResponse initial,
  PortalHttpSession session, {
  required bool Function(PortalResponse response) isAuthenticated,
}) async {
  var current = initial;
  for (var step = 0; step < 8; step += 1) {
    if (isAuthenticated(current)) return current;
    if (current.body.contains('SAMLResponse') &&
        current.body.contains('RelayState')) {
      current = await session.postForm(
        portalForm(
          current.body,
          current.url,
          requiredFields: const <String>{'SAMLResponse', 'RelayState'},
        ),
      );
      continue;
    }
    if (current.url.host == 'idp.uni-tuebingen.de') {
      // The attribute-release consent page must be handled before the generic
      // proceed step: it also carries `_eventId_proceed`, but proceeding
      // without echoing the requested `_shib_idp_consentIds` attributes just
      // re-serves the same page.
      final consent = portalConsentForm(current.body, current.url);
      if (consent != null) {
        current = await session.postFormFields(
          consent.action,
          consent.fields,
          referer: current.url,
        );
        continue;
      }
      if (current.body.contains('_eventId_proceed')) {
        current = await session.postForm(
          portalForm(
            current.body,
            current.url,
            requiredFields: const <String>{'_eventId_proceed'},
          ),
        );
        continue;
      }
    }
    break;
  }
  final stage = current.url.host == 'idp.uni-tuebingen.de'
      ? 'The university identity provider requires an unsupported interactive '
            'step, such as MFA or consent (${_idpDiagnostics(current.body)}).'
      : 'The university portal did not confirm the SAML login at ${current.url.host}${current.url.path}.';
  throw PortalAuthenticationException(stage);
}

/// Builds the submission for a Shibboleth attribute-release consent page, or
/// returns null when [html] is not such a page. Releases exactly the
/// attributes the service requested and, when offered, remembers the choice
/// for this service so the page is a one-time step rather than a per-login one.
({Uri action, List<MapEntry<String, String>> fields})? portalConsentForm(
  String html,
  Uri pageUrl,
) {
  final document = html_parser.parse(html);
  for (final form in document.querySelectorAll('form')) {
    final consentBoxes = form.querySelectorAll(
      'input[name="_shib_idp_consentIds"]',
    );
    if (consentBoxes.isEmpty) continue;
    final fields = <MapEntry<String, String>>[];
    for (final box in consentBoxes) {
      // Mirror a browser's default "Accept": disabled inputs are never sent,
      // and an unchecked checkbox is omitted. Tübingen renders these as hidden
      // inputs (always submitted); other templates use pre-checked checkboxes.
      if (box.attributes.containsKey('disabled')) continue;
      final type = box.attributes['type']?.toLowerCase();
      if (type == 'checkbox' && !box.attributes.containsKey('checked')) {
        continue;
      }
      final value = box.attributes['value'];
      if (value != null && value.isNotEmpty) {
        fields.add(MapEntry('_shib_idp_consentIds', value));
      }
    }
    // Carry hidden fields (e.g. a CSRF token) but never a form control: this
    // page ships both an Accept and a Reject submit button, and echoing the
    // reject event alongside proceed is what the IdP treats as a denied
    // release. Only the explicit proceed button below is submitted.
    const skipTypes = <String>{
      'checkbox',
      'radio',
      'submit',
      'reset',
      'button',
      'image',
    };
    for (final input in form.querySelectorAll('input[name]')) {
      final name = input.attributes['name']!;
      final type = input.attributes['type']?.toLowerCase();
      if (name == '_shib_idp_consentIds') continue;
      if (skipTypes.contains(type)) continue;
      fields.add(MapEntry(name, input.attributes['value'] ?? ''));
    }
    if (form.querySelector('[name="_shib_idp_consentOptions"]') != null) {
      fields.add(
        const MapEntry('_shib_idp_consentOptions', '_shib_idp_rememberConsent'),
      );
    }
    final proceed =
        form.querySelector('button[name="_eventId_proceed"]') ??
        form.querySelector('input[name="_eventId_proceed"]');
    fields.add(
      MapEntry('_eventId_proceed', proceed?.attributes['value'] ?? ''),
    );
    return (
      action: pageUrl.resolve(form.attributes['action'] ?? ''),
      fields: fields,
    );
  }
  return null;
}

/// Names the blocking IdP page (title and detected field names, never values)
/// so a failed login report can distinguish a consent gate from an MFA gate.
String _idpDiagnostics(String html) {
  final document = html_parser.parse(html);
  final title = document.querySelector('title')?.text.trim();
  final fields = <String>{};
  for (final node in document.querySelectorAll(
    'input[name], select[name], button[name]',
  )) {
    final name = node.attributes['name'];
    if (name != null && name.isNotEmpty) fields.add(name);
  }
  final parts = <String>[
    if (title != null && title.isNotEmpty) 'page "$title"',
    if (fields.isNotEmpty) 'fields: ${fields.take(12).join(', ')}',
  ];
  return parts.isEmpty ? 'no recognizable form' : parts.join('; ');
}

bool _isRedirect(int status) =>
    status == 301 ||
    status == 302 ||
    status == 303 ||
    status == 307 ||
    status == 308;
