import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/main.dart';

void main() {
  testWidgets('renders the StudyOS Agent shell', (WidgetTester tester) async {
    await tester.pumpWidget(const StudyOsAgentApp());

    expect(find.text('JARVIS 9'), findsOneWidget);
    expect(
      find.text('Flutter shell with native Android bridge'),
      findsOneWidget,
    );
    expect(find.text('Nachricht an Jarvis...'), findsOneWidget);
  });
}
