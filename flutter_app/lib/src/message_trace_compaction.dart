import 'models.dart';

List<ChatMessage> compactTraceMessages(List<ChatMessage> messages) {
  final visible = <ChatMessage>[];
  for (final message in messages) {
    if (_isHiddenTrace(message)) continue;
    if (visible.isNotEmpty && _sameTraceUpdate(visible.last, message)) {
      visible[visible.length - 1] = message;
      continue;
    }
    visible.add(message);
  }
  return visible;
}

bool _isHiddenTrace(ChatMessage message) {
  final trace = message.trace;
  return trace != null && trace.toolName.startsWith('model:');
}

bool _sameTraceUpdate(ChatMessage previous, ChatMessage next) {
  if (!previous.isTrace || !next.isTrace) return false;
  final previousTrace = previous.trace!;
  final nextTrace = next.trace!;
  if (previousTrace.toolName == nextTrace.toolName) return true;
  final previousCallId = previousTrace.callId;
  final nextCallId = nextTrace.callId;
  if (previousCallId != null || nextCallId != null) {
    return previousCallId == nextCallId;
  }
  return previousTrace.toolName == nextTrace.toolName;
}
