import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';
import '../views/agent_selected_view.dart';
import 'app_drawer.dart';
import 'study_header.dart';

class AgentHomeScaffold extends StatelessWidget {
  const AgentHomeScaffold({
    required this.selectedView,
    required this.sessions,
    required this.activeSessionId,
    required this.inputController,
    required this.isSending,
    required this.compactMessages,
    required this.status,
    required this.worldState,
    required this.memoryText,
    required this.agentConfig,
    required this.profile,
    required this.onSelectView,
    required this.onSelectSession,
    required this.onCreateSession,
    required this.onSuggestionSelected,
    required this.onSend,
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
  final String status;
  final Map<String, Object?> worldState;
  final String memoryText;
  final AgentConfig agentConfig;
  final OnboardingProfile? profile;
  final ValueChanged<AppView> onSelectView;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onCreateSession;
  final ValueChanged<String> onSuggestionSelected;
  final VoidCallback onSend;
  final VoidCallback? onLogout;
  final Future<void> Function(AgentConfig config, String? apiKey)
  onSaveAgentConfig;
  final ValueChanged<bool> onCompactMessagesChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        selectedView: selectedView,
        sessions: sessions,
        activeSessionId: activeSessionId,
        onSelectView: onSelectView,
        onSelectSession: onSelectSession,
        onCreateSession: onCreateSession,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StudyOsSpacing.lg,
              ),
              child: Column(
                children: <Widget>[
                  StudyHeader(status: status),
                  Expanded(
                    child: AgentSelectedView(
                      selectedView: selectedView,
                      sessions: sessions,
                      activeSessionId: activeSessionId,
                      inputController: inputController,
                      isSending: isSending,
                      compactMessages: compactMessages,
                      onSuggestionSelected: onSuggestionSelected,
                      onSend: onSend,
                      worldState: worldState,
                      memoryText: memoryText,
                      agentConfig: agentConfig,
                      profile: profile,
                      status: status,
                      onLogout: onLogout,
                      onSaveAgentConfig: onSaveAgentConfig,
                      onCompactMessagesChanged: onCompactMessagesChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
