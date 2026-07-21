import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/alma_academic_client.dart';

const _courseHtml = '''
<form id="studentOverviewForm">
  <select name="studentOverviewForm:enrollmentsDiv:termSelector:termPeriodDropDownList_input">
    <option value="229" selected="selected">Sommersemester 2026</option>
  </select>
  <h2>Veranstaltung: Vorlesung/Übung GTCNEURO Neural Data Science</h2>
  <table>
    <tr>
      <td>
        <div>1. Parallelgruppe Neural Data Science</div>
        <div>jeden Mittwoch (15.04.26 bis 22.07.26) von 10:15 bis 11:45 wöchentlich</div>
        <div>Status Aktionen Details anzeigen Informationen zu Belegzeiträumen</div>
        <a href="/alma/pages/cm/exa/searchRoomDetail.xhtml?roomId=471">Raumdetails für Hörsaal A2 anzeigen</a>
      </td>
      <td>
        <div>Status</div>
        <div>Ihr aktueller Status: storniert</div>
        <div>Semester der Leistung: SoSe 2026</div>
      </td>
      <td>
        <a href="/alma/pages/startFlow.xhtml?_flowId=detailView-flow&amp;unitId=42&amp;periodId=229">Details anzeigen</a>
      </td>
    </tr>
  </table>
</form>
''';

const _examHtml = '''
<form id="studentOverviewForm">
  <select name="studentOverviewForm:enrollmentsDiv:termSelector:termPeriodDropDownList_input">
    <option value="229" selected="selected">Sommersemester 2026</option>
  </select>
  <h2>Prüfung: INFO-THEO-1-9CP THEO</h2>
  <table>
    <tr>
      <td>Termine und Räume Status Aktionen</td>
      <td>1. Parallelgruppe Probabilistic Machine Learning Donnerstag 23.07.26 Keine Uhrzeit festgelegt Prüfungsform: Schriftlich oder mündlich Prüfer/-in: Prof. Dr. Macke</td>
      <td>Ihr aktueller Status: zugelassen Semester der Leistung: SoSe 2026 Versuch (gilt nur für Prüfungen): 1</td>
      <td><a href="/alma/pages/startFlow.xhtml?_flowId=detailView-flow&amp;unitId=63233">Details anzeigen</a></td>
    </tr>
  </table>
</form>
''';

void main() {
  test('parseAcademicStatus extracts term-aware course enrollment', () {
    final snapshot = parseAcademicStatus(
      _courseHtml,
      now: DateTime(2026, 7, 10),
    );

    expect(snapshot.term, 'Sommersemester 2026');
    expect(snapshot.availableTerms, contains('Sommersemester 2026'));

    final entry = snapshot.entries.single;
    expect(entry.category, 'Veranstaltung');
    expect(entry.eventType, 'Vorlesung/Übung');
    expect(entry.number, 'GTCNEURO');
    expect(entry.title, 'Neural Data Science');
    expect(entry.status, 'storniert');
    expect(entry.semester, 'SoSe 2026');
    expect(entry.scheduleText, contains('jeden Mittwoch'));
    expect(entry.scheduleText, isNot(contains('Details anzeigen')));
    expect(
      entry.scheduleText,
      isNot(contains('Informationen zu Belegzeiträumen')),
    );
    expect(entry.detailUrl, endsWith('unitId=42&periodId=229'));
  });

  test('parseAcademicStatus distinguishes exam registrations', () {
    final snapshot = parseAcademicStatus(_examHtml, now: DateTime(2026, 7, 10));

    final entry = snapshot.entries.single;
    expect(entry.category, 'Prüfung');
    expect(entry.eventType, 'Prüfung');
    expect(entry.number, 'INFO-THEO-1-9CP');
    expect(entry.title, 'Probabilistic Machine Learning');
    expect(entry.status, 'zugelassen');
    expect(entry.semester, 'SoSe 2026');
    expect(entry.attempt, '1');
    expect(entry.scheduleText, contains('Donnerstag 23.07.26'));
    expect(
      entry.scheduleText,
      contains('Prüfungsform: Schriftlich oder mündlich'),
    );
  });

  test('parseAcademicStatus preserves the original status without inference', () {
    final snapshot = parseAcademicStatus(
      _courseHtml,
      now: DateTime(2026, 7, 10),
    );

    // "storniert" must survive verbatim; we never normalize to passed/cancelled.
    expect(snapshot.entries.single.status, 'storniert');
    expect(snapshot.notice, isNull);
  });
}
