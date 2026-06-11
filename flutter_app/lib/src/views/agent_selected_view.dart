import 'package:flutter/material.dart';

import '../chat_session_mutation.dart';
import '../models.dart';
import 'chat_view.dart';
import 'memories_view.dart';
import 'settings_view.dart';

class AgentSelectedView extends StatelessWidget {
  const AgentSelectedView({
    required this.selectedView,
    required this.sessions,
    required this.activeSessionId,
    required this.inputController,
    required this.isSending,
    required this.compactMessages,
    required this.onSuggestionSelected,
    required this.onSend,
    required this.worldState,
    required this.memoryText,
    required this.agentConfig,
    required this.profile,
    required this.status,
    required this.onLogout,
    required this.onSaveAgentConfig,
    required this.onCompactMessagesChanged,
    super.key,
  });

  final AppView selectedView;
  final List<ChatSession> sessions;
  final String? activeSessionId;
  final TextEditingController inputController;
  final bool isSending;
  final bool compactMessages;
  final ValueChanged<String> onSuggestionSelected;
  final VoidCallback onSend;
  final Map<String, Object?> worldState;
  final String memoryText;
  final AgentConfig agentConfig;
  final OnboardingProfile? profile;
  final String status;
  final VoidCallback? onLogout;
  final Future<void> Function(AgentConfig config, String? apiKey)
  onSaveAgentConfig;
  final ValueChanged<bool> onCompactMessagesChanged;

  @override
  Widget build(BuildContext context) {
    return switch (selectedView) {
      AppView.chat => ChatView(
        messages: activeSessionFrom(sessions, activeSessionId).messages,
        inputController: inputController,
        isSending: isSending,
        compactMessages: compactMessages,
        onSuggestionSelected: onSuggestionSelected,
        onSend: onSend,
      ),
      AppView.memories => MemoriesView(
        worldState: worldState,
        memoryText: memoryText,
      ),
      AppView.settings => SettingsView(
        config: agentConfig,
        profile: profile,
        status: status,
        compactMessages: compactMessages,
        onLogout: onLogout,
        onSaveAgentConfig: onSaveAgentConfig,
        onCompactMessagesChanged: onCompactMessagesChanged,
      ),
    };
  }
}
