import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:studyos_agent/src/widgets/markdown_math.dart';

void main() {
  Widget host(String data) {
    return MaterialApp(
      home: Scaffold(
        body: MarkdownBody(
          data: data,
          selectable: true,
          extensionSet: mathMarkdownExtensionSet(),
          builders: mathMarkdownBuilders(),
        ),
      ),
    );
  }

  testWidgets('renders inline math as a Math widget', (tester) async {
    await tester.pumpWidget(host(r'The formula is $x^2 + y^2$ here.'));
    expect(find.byType(Math), findsOneWidget);
  });

  testWidgets('renders display math as a Math widget', (tester) async {
    await tester.pumpWidget(host(r'$$\frac{a}{b}$$'));
    expect(find.byType(Math), findsOneWidget);
  });

  testWidgets('plain text without math renders no Math widget', (tester) async {
    await tester.pumpWidget(host('Just a normal sentence with no math.'));
    expect(find.byType(Math), findsNothing);
  });

  testWidgets('stray currency is not treated as math', (tester) async {
    await tester.pumpWidget(host(r'It costs $5 and $10 total.'));
    expect(find.byType(Math), findsNothing);
  });

  testWidgets('GFM tables still render alongside math support', (tester) async {
    await tester.pumpWidget(
      host('| A | B |\n| - | - |\n| 1 | 2 |'),
    );
    expect(find.byType(Table), findsOneWidget);
  });

  test(r'the math syntax parses $ and $$ into math elements', () {
    final document = md.Document(
      extensionSet: mathMarkdownExtensionSet(),
      inlineSyntaxes: const <md.InlineSyntax>[],
    );
    final nodes = document.parseInline(r'inline $a+b$ and $$c^2$$ end');
    final maths = <md.Element>[];
    void collect(List<md.Node> list) {
      for (final node in list) {
        if (node is md.Element) {
          if (node.tag == 'math') maths.add(node);
          final children = node.children;
          if (children != null) collect(children);
        }
      }
    }

    collect(nodes);
    expect(maths, hasLength(2));
    expect(maths.first.attributes['mode'], 'inline');
    expect(maths.last.attributes['mode'], 'display');
  });
}
