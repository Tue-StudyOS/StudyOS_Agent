import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// LaTeX math support for the assistant's Markdown replies. Inline math is
/// written `$…$` and display math `$$…$$`; both are parsed into a `math` element
/// and rendered with `flutter_math_fork`. GitHub-flavored features (tables,
/// etc.) are preserved because the extension set extends `gitHubFlavored` rather
/// than replacing it.
///
/// Invalid TeX never breaks a reply: `Math.tex`'s error fallback renders the raw
/// `$…$` source as plain text instead.

/// Parses `$…$` / `$$…$$` into a `math` element carrying a `mode` attribute.
class _MathSyntax extends md.InlineSyntax {
  _MathSyntax(super.pattern, this.mode);

  final String mode;

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = (match[1] ?? '').trim();
    if (content.isEmpty) return false;
    final element = md.Element.text('math', content);
    element.attributes['mode'] = mode;
    parser.addNode(element);
    return true;
  }
}

/// GitHub-flavored Markdown plus the two math syntaxes. Display (`$$…$$`) is
/// registered before inline (`$…$`) so it wins. The inline pattern forbids a
/// space just inside the delimiters, which keeps stray currency like "$5 and
/// $10" from being read as math.
md.ExtensionSet mathMarkdownExtensionSet() {
  final gfm = md.ExtensionSet.gitHubFlavored;
  return md.ExtensionSet(
    List<md.BlockSyntax>.of(gfm.blockSyntaxes),
    <md.InlineSyntax>[
      _MathSyntax(r'\$\$(.+?)\$\$', 'display'),
      _MathSyntax(r'\$(?! )((?:[^\$\n])+?)(?<! )\$', 'inline'),
      ...gfm.inlineSyntaxes,
    ],
  );
}

/// Renders a `math` element with `flutter_math_fork`, falling back to the raw
/// source on a TeX parse error.
class MathElementBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final tex = element.textContent;
    final isDisplay = element.attributes['mode'] == 'display';
    return Math.tex(
      tex,
      textStyle: preferredStyle,
      mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
      onErrorFallback: (_) => Text('\$$tex\$', style: preferredStyle),
    );
  }
}

/// Builder map to pass to `MarkdownBody(builders: ...)`.
Map<String, MarkdownElementBuilder> mathMarkdownBuilders() =>
    <String, MarkdownElementBuilder>{'math': MathElementBuilder()};
