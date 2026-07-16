import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/studyos_theme.dart';
import 'package:studyos_agent/src/widgets/schedule_components.dart';

void main() {
  testWidgets('day strip keeps the selected date visible', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    final days = List<DateTime>.generate(
      20,
      (index) => DateTime(2026, 7, index + 1),
    );
    var selectedDay = days[7];
    late StateSetter updateHost;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 382,
              child: StatefulBuilder(
                builder: (context, setState) {
                  updateHost = setState;
                  return ScheduleDayStrip(
                    days: days,
                    selectedDay: selectedDay,
                    countFor: (_) => 1,
                    onSelected: (day) => setState(() => selectedDay = day),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    _expectSelectedDayVisible(tester, selectedDay);

    updateHost(() => selectedDay = days[17]);
    await tester.pumpAndSettle();

    _expectSelectedDayVisible(tester, selectedDay);
    semantics.dispose();
  });

  testWidgets('day strip adapts to accessibility text sizes', (tester) async {
    final day = DateTime(2026, 7, 16);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudyOsTheme(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ScheduleDayStrip(
              days: <DateTime>[day],
              selectedDay: day,
              countFor: (_) => 5,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(ListView)).height, 88);
    expect(tester.takeException(), isNull);
  });
}

void _expectSelectedDayVisible(WidgetTester tester, DateTime day) {
  final selected = find.bySemanticsLabel(
    '${scheduleWeekday(day)}, ${day.day} ${scheduleMonth(day)}, 1 item',
  );
  expect(selected, findsOneWidget);
  final semantics = tester.getSemantics(selected);
  expect(semantics.flagsCollection.isButton, isTrue);
  expect(semantics.flagsCollection.isSelected, ui.Tristate.isTrue);

  final viewport = tester.getRect(find.byType(ListView));
  final selectedBounds = tester.getRect(selected);
  expect(selectedBounds.left, greaterThanOrEqualTo(viewport.left));
  expect(selectedBounds.right, lessThanOrEqualTo(viewport.right));
}
