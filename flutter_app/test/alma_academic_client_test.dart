import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/alma_academic_client.dart';

void main() {
  test('parses ALMA registration report rows', () {
    final snapshot = parseAcademicReport('''
Sommersemester 2026
Nr. Titel der Veranstaltung/Prüfung Gruppe Status Bemerkung
INFO-INFO-6-3CP AI for Scientific Discovery 27. PG zugelassen
INFO-FOKUS-4-6CPNatural Language Processing 41. PG zugelassen
ZDV-IVS alma-Einführung für neue Studierende 3. PG zugelassen
''', now: DateTime(2026, 7, 10));

    expect(snapshot.term, 'Sommersemester 2026');
    expect(snapshot.entries, hasLength(3));
    expect(snapshot.entries[0].title, 'AI for Scientific Discovery');
    expect(snapshot.entries[0].status, 'zugelassen');
    expect(snapshot.entries[1].title, 'Natural Language Processing');
    expect(snapshot.entries[1].detail, 'INFO-FOKUS-4-6CP · 41. PG');
  });
}
