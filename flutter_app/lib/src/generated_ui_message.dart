import 'dart:convert';

/// Fenced-block marker the model uses to attach a generative-UI component to a
/// reply that did not run a tool. The reply ends with:
///
/// ```ui
/// {"type": "quick_reply", "title": "...", "body": "...", "arguments": {...}}
/// ```
///
/// Kept as a `ui`-tagged code fence so a malformed or partially streamed block
/// degrades to (at worst) a hidden code block rather than raw JSON, and so the
/// opener is cheap to detect while the reply is still streaming in.
final RegExp _uiFence = RegExp(r'```[ \t]*ui[ \t]*\r?\n([\s\S]*?)```');

/// Just the fence opener, used to hide everything from the block onward while
/// the reply streams (before the closing fence has arrived).
final RegExp _uiFenceOpener = RegExp(r'```[ \t]*ui\b');

/// A committed assistant reply split into its visible [text] and an optional
/// generative-UI [component] payload the model emitted in a trailing `ui`
/// fence. [component] is left unvalidated — the render layer
/// ([GenerativeUiRegistry]) validates and silently drops anything invalid, so a
/// junk payload just yields no card.
class AssistantMessageParts {
  const AssistantMessageParts({required this.text, this.component});

  final String text;
  final Map<String, Object?>? component;
}

/// Splits a raw assistant reply into visible prose and an optional model-emitted
/// component payload. The `ui` fence is always removed from [text] whether or
/// not its contents parse, so raw JSON is never shown to the user; the payload
/// is attached only when the fence holds a JSON object.
AssistantMessageParts splitAssistantComponent(String raw) {
  final match = _uiFence.firstMatch(raw);
  if (match == null) {
    return AssistantMessageParts(text: raw);
  }

  final text = raw.replaceRange(match.start, match.end, '').trim();
  final component = _decodeComponent(match.group(1) ?? '');
  return AssistantMessageParts(text: text, component: component);
}

/// The portion of a still-streaming reply that is safe to show: everything
/// before the `ui` fence opener, so the JSON block never flashes on screen as it
/// arrives token by token. Returns [raw] unchanged when no opener is present.
String streamingVisibleText(String raw) {
  final match = _uiFenceOpener.firstMatch(raw);
  if (match == null) return raw;
  return raw.substring(0, match.start).trimRight();
}

/// Wire type of a model-emitted reference that asks the app to display a tool's
/// result as its existing card, rather than restating the tool's data inline.
const String toolCardReferenceType = 'tool_card';

/// Resolves the payload extracted from a `ui` block into the component to attach
/// to the assistant message.
///
/// Tool cards are decoupled from tool execution: running `get_study_planner`
/// does NOT surface a planner card on its own. The model must opt a tool result
/// in by ending its reply with a `{"type":"tool_card","tool":"<name>"}`
/// reference, which resolves here to that tool's captured payload from
/// [capturedToolComponents] (keyed by tool name). If the model didn't reference
/// a tool — because it called the tool but pivoted away — nothing shows.
///
/// - A `tool_card` reference → the captured payload for its `tool`, or null when
///   the tool wasn't called this turn or produced no card.
/// - Any other payload (a model-composed A/B component such as `quick_reply` or
///   `custom_view`) → returned unchanged.
/// - null → null.
Map<String, Object?>? resolveComponentPayload(
  Map<String, Object?>? emitted,
  Map<String, Map<String, Object?>> capturedToolComponents,
) {
  if (emitted == null) return null;
  if (emitted['type'] != toolCardReferenceType) return emitted;
  final tool = emitted['tool']?.toString();
  if (tool == null || tool.isEmpty) return null;
  return capturedToolComponents[tool];
}

/// Upper bounds on what still counts as a presentational lead-in (see
/// [isPresentationalLeadIn]).
const int _leadInMaxLines = 2;
const int _leadInMaxChars = 140;
const int _leadInMaxSentences = 1;

final RegExp _sentenceEnd = RegExp(r'[.!?]+(\s|$)');

/// Whether [replyText] reads as a short lead-in that introduces a result (e.g.
/// "Here are your recent emails:") rather than a full answer that has pivoted to
/// another topic. Used to decide whether to surface a tool's captured card when
/// the model didn't emit an explicit reference — small models write the lead-in
/// naturally but forget the machine-readable block.
///
/// A lead-in is short on all three axes: at most [_leadInMaxLines] lines,
/// [_leadInMaxChars] characters, and [_leadInMaxSentences] sentence. The
/// sentence count catches a multi-sentence answer that still fits the character
/// budget; the character cap catches a single run-on pivot sentence.
bool isPresentationalLeadIn(String replyText) {
  final trimmed = replyText.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.length > _leadInMaxChars) return false;
  final lineCount = trimmed
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .length;
  if (lineCount > _leadInMaxLines) return false;
  return _sentenceEnd.allMatches(trimmed).length <= _leadInMaxSentences;
}

/// Decides the component to attach to an assistant message.
///
/// Tool cards are shown when the reply is *about* a fetched result, detected two
/// ways: an explicit `tool_card` reference the model emitted (precise, picks the
/// exact tool), or — since a small model often omits that block — a short
/// presentational lead-in ([isPresentationalLeadIn]) paired with a tool that
/// produced a card this turn, in which case the most recently captured card is
/// used. A long answer with no reference (the model called a tool but pivoted
/// away) yields no card, keeping the full prose. Composed A/B components
/// ([resolveComponentPayload] passthrough) always win when present.
///
/// [capturedToolComponents] is insertion-ordered; its last value is the most
/// recent tool card of the turn.
Map<String, Object?>? resolveMessageComponent({
  required Map<String, Object?>? emitted,
  required Map<String, Map<String, Object?>> capturedToolComponents,
  required String replyText,
}) {
  final direct = resolveComponentPayload(emitted, capturedToolComponents);
  if (direct != null) return direct;
  if (capturedToolComponents.isEmpty) return null;
  if (!isPresentationalLeadIn(replyText)) return null;
  return capturedToolComponents.values.last;
}

Map<String, Object?>? _decodeComponent(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    return null;
  }
  return decoded is Map ? Map<String, Object?>.from(decoded) : null;
}
