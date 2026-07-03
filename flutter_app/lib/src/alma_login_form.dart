import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

class AlmaLoginForm {
  const AlmaLoginForm({required this.action, required this.payload});

  final Uri action;
  final Map<String, String> payload;
}

AlmaLoginForm extractAlmaLoginForm({
  required String html,
  required Uri pageUrl,
  required Object Function(String message) exception,
}) {
  final document = html_parser.parse(html);
  final form = _loginForm(document);
  if (form == null) {
    throw exception('Could not find ALMA login form.');
  }

  final action = form.attributes['action'];
  if (action == null || action.isEmpty) {
    throw exception('ALMA login form has no action.');
  }

  final payload = <String, String>{};
  for (final input in form.getElementsByTagName('input')) {
    final name = input.attributes['name'];
    final type = input.attributes['type']?.toLowerCase() ?? '';
    if (name == null ||
        name.isEmpty ||
        type == 'checkbox' ||
        type == 'button') {
      continue;
    }
    payload[name] = input.attributes['value'] ?? '';
  }

  payload.putIfAbsent('submit', () => '');
  return AlmaLoginForm(action: pageUrl.resolve(action), payload: payload);
}

Element? _loginForm(Document document) {
  final candidates = <Element>[
    ?document.getElementById('mobileLoginForm'),
    ?document.getElementById('loginForm'),
  ];
  for (final form in candidates) {
    if (_hasCredentialFields(form)) return form;
  }
  return candidates.isEmpty ? null : candidates.first;
}

bool _hasCredentialFields(Element form) {
  return form.querySelector('input[name="asdf"]') != null &&
      form.querySelector('input[name="fdsa"]') != null;
}
