import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/mail_parsing.dart';

void main() {
  test('approved broadcast banner is stripped and exposed as notice', () {
    final detail = parseMailDetail(
      utf8.encode('''
From: Info <info@example.edu>
To: Ada <ada@example.edu>
Subject: Sprachcafes
Date: Tue, 16 Jun 2026 10:00:00 +0200
Content-Type: text/plain; charset=utf-8

***********************************************************************
* Die Hochschulleitung hat dem Versand dieser Rundmail zugestimmt.    *
* Die inhaltliche Verantwortung liegt bei der Absenderin/dem Absender *
***********************************************************************
Liebe Studierende,

das Fremdsprachenzentrum Tuebingen laedt Sie herzlich ein.
'''),
      uid: '12',
      mailbox: 'INBOX',
      isUnread: false,
    );

    expect(detail.approvalNotice?.title, 'Approved university broadcast');
    expect(detail.bodyText, isNot(contains('Hochschulleitung')));
    expect(detail.bodyText, contains('Liebe Studierende'));
    expect(detail.preview, startsWith('Liebe Studierende'));
  });

  test('multipart html fallback produces readable preview', () {
    final summary = parseMailSummary(
      utf8.encode('''
From: Prof X <prof@example.edu>
Subject: =?utf-8?Q?Exam_deadline?=
Content-Type: multipart/alternative; boundary="abc"

--abc
Content-Type: text/html; charset=utf-8

<p>The <strong>deadline</strong> is 2026-06-20.</p>
--abc--
'''),
      uid: '7',
      isUnread: true,
    );

    expect(summary.subject, 'Exam deadline');
    expect(summary.fromName, 'Prof X');
    expect(summary.preview, 'The deadline is 2026-06-20.');
    expect(summary.isUnread, isTrue);
  });
}
