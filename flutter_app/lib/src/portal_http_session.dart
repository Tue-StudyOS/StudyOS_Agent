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

  Future<PortalResponse> _send(
    String method,
    Uri url, {
    Map<String, String>? form,
    String? jsonBody,
    Uri? referer,
  }) async {
    var nextMethod = method;
    var nextUrl = url;
    var nextForm = form;
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
        nextJson = null;
      }
    }
    throw const PortalException('Portal redirected too many times.');
  }

  void close() {
    _cookiesByHost.clear();
    if (_ownsClient) _client.close();
  }

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
  for (var step = 0; step < 6; step += 1) {
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
    if (current.url.host == 'idp.uni-tuebingen.de' &&
        current.body.contains('_eventId_proceed')) {
      current = await session.postForm(
        portalForm(
          current.body,
          current.url,
          requiredFields: const <String>{'_eventId_proceed'},
        ),
      );
      continue;
    }
    break;
  }
  final stage = current.url.host == 'idp.uni-tuebingen.de'
      ? 'The university identity provider requires an unsupported interactive step, such as MFA or consent.'
      : 'The university portal did not confirm the SAML login at ${current.url.host}${current.url.path}.';
  throw PortalAuthenticationException(stage);
}

bool _isRedirect(int status) =>
    status == 301 ||
    status == 302 ||
    status == 303 ||
    status == 307 ||
    status == 308;
