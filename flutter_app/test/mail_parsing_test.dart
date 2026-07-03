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

  test(
    'summary preview parses headers without requiring full message body',
    () {
      final summary = parseMailSummaryPreview(
        rawHeaders: utf8.encode('''
From: Prof X <prof@example.edu>
Subject: Office hour
Date: Tue, 16 Jun 2026 10:00:00 +0200
Content-Type: text/plain; charset=utf-8
'''),
        rawPreview: utf8.encode('Please bring your draft.'),
        uid: '9',
        isUnread: false,
      );

      expect(summary.subject, 'Office hour');
      expect(summary.fromAddress, 'prof@example.edu');
      expect(summary.preview, 'Please bring your draft.');
      expect(summary.isUnread, isFalse);
    },
  );

  group('parseBodyStructure', () {
    test('returns no section for a single-part message', () {
      final structure = parseBodyStructure(
        '* 5 FETCH (BODYSTRUCTURE '
        '("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "7BIT" 2279 48 NIL NIL NIL NIL))',
      );

      expect(structure, isNotNull);
      expect(structure!.isMultipart, isFalse);
      expect(structure.textSection, isNull);
      expect(structure.attachmentNames, isEmpty);
    });

    test('prefers the text/plain part of a multipart/alternative', () {
      final structure = parseBodyStructure(
        '* 5 FETCH (BODYSTRUCTURE '
        '(("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 12 3 NIL NIL NIL NIL)'
        '("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 40 5 NIL NIL NIL NIL)'
        ' "ALTERNATIVE" ("BOUNDARY" "abc") NIL NIL NIL))',
      );

      expect(structure, isNotNull);
      expect(structure!.isMultipart, isTrue);
      expect(structure.textSection?.section, '1');
      expect(structure.textSection?.mimeType, 'text/plain');
      expect(structure.textSection?.encoding, 'quoted-printable');
      expect(structure.attachmentNames, isEmpty);
    });

    test('selects the text part and lists attachments in multipart/mixed', () {
      final structure = parseBodyStructure(
        '* 5 FETCH (BODYSTRUCTURE '
        '(("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "7BIT" 100 4 NIL NIL NIL NIL)'
        '("APPLICATION" "PDF" ("NAME" "slides.pdf") NIL NIL "BASE64" 90000 NIL '
        '("ATTACHMENT" ("FILENAME" "slides.pdf")) NIL)'
        ' "MIXED" ("BOUNDARY" "xyz") NIL NIL NIL))',
      );

      expect(structure!.textSection?.section, '1');
      expect(structure.textSection?.mimeType, 'text/plain');
      expect(structure.attachmentNames, <String>['slides.pdf']);
    });

    test('assigns dotted section numbers for nested multiparts', () {
      final structure = parseBodyStructure(
        '* 5 FETCH (BODYSTRUCTURE '
        '((("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "7BIT" 100 4 NIL NIL NIL NIL)'
        '("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "7BIT" 200 6 NIL NIL NIL NIL)'
        ' "ALTERNATIVE" ("BOUNDARY" "inner") NIL NIL NIL)'
        '("APPLICATION" "PDF" ("NAME" "doc.pdf") NIL NIL "BASE64" 90000 NIL '
        '("ATTACHMENT" ("FILENAME" "doc.pdf")) NIL)'
        ' "MIXED" ("BOUNDARY" "outer") NIL NIL NIL))',
      );

      expect(structure!.textSection?.section, '1.1');
      expect(structure.attachmentNames, <String>['doc.pdf']);
    });

    test('returns null when no structure is present', () {
      expect(parseBodyStructure('* 5 FETCH (UID 5 FLAGS (\\Seen))'), isNull);
    });
  });

  test(
    'buildTextPartMessage decodes a fetched text part with its encoding',
    () {
      final section = MailTextSection(
        section: '1',
        mimeType: 'text/plain',
        charset: 'utf-8',
        encoding: 'quoted-printable',
      );
      final message = buildTextPartMessage(
        rawHeaders: latin1.encode(
          'From: Info <info@example.edu>\r\n'
          'Subject: Update\r\n'
          'Content-Type: multipart/alternative; boundary="abc"\r\n',
        ),
        rawPartBody: latin1.encode('Bitte pr=C3=BCfen Sie das Dokument.'),
        section: section,
      );

      final summary = parseMailSummary(message, uid: '3', isUnread: false);
      expect(summary.subject, 'Update');
      expect(summary.fromAddress, 'info@example.edu');
      expect(summary.preview, 'Bitte prüfen Sie das Dokument.');
    },
  );
}
