import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/alma_login_form.dart';
import 'package:studyos_agent/src/tuebingen_profile_client.dart';

void main() {
  test('prefers ALMA form that carries credential fields and ajax token', () {
    final form = extractAlmaLoginForm(
      html: '''
        <form id="mobileLoginForm" action="https://alma.example/alma/rds">
          <input type="hidden" name="userInfo" value="">
          <input type="hidden" name="ajax-token" value="token-123">
          <input name="asdf" value="">
          <input name="fdsa" value="" type="password">
        </form>
        <form id="loginForm" action="https://alma.example/alma/rds"></form>
      ''',
      pageUrl: Uri.parse('https://alma.example/alma/start.faces'),
      exception: TuebingenProfileException.new,
    );

    expect(form.action.toString(), 'https://alma.example/alma/rds');
    expect(form.payload['ajax-token'], 'token-123');
    expect(form.payload, containsPair('asdf', ''));
    expect(form.payload, containsPair('fdsa', ''));
  });
}
