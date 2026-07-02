import 'package:flutter/material.dart';

void scrollChatToBottom(ScrollController controller) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!controller.hasClients) return;
    controller.animateTo(
      controller.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  });
}

/// During streaming, jump (no animation) to the bottom only when the user is
/// already near it, so frequent token updates don't fight a manual scroll-up.
void maybeStickChatToBottom(
  ScrollController controller, {
  double threshold = 80,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (position.maxScrollExtent - position.pixels <= threshold) {
      controller.jumpTo(position.maxScrollExtent);
    }
  });
}
