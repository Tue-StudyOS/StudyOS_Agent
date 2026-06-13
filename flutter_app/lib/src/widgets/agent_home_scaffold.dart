import 'package:flutter/material.dart';

import '../models.dart';
import '../native_bridge.dart';
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
    required this.messageScrollController,
    required this.isSending,
    required this.compactMessages,
    required this.status,
    required this.worldState,
    required this.memoryText,
    required this.timetable,
    required this.timetableError,
    required this.isRefreshingTimetable,
    required this.agentConfig,
    required this.nativeBridge,
    required this.profile,
    required this.onSelectView,
    required this.onSelectSession,
    required this.onCreateSession,
    required this.onDeleteSession,
    required this.onSuggestionSelected,
    required this.onSend,
    required this.onLogout,
    required this.onSaveProfile,
    required this.onSaveAgentConfig,
    required this.onSaveMemory,
    required this.onRefreshTimetable,
    required this.onCompactMessagesChanged,
    super.key,
  });

  final AppView selectedView;
  final List<ChatSession> sessions;
  final String? activeSessionId;
  final TextEditingController inputController;
  final ScrollController messageScrollController;
  final bool isSending;
  final bool compactMessages;
  final String status;
  final Map<String, Object?> worldState;
  final String memoryText;
  final TimetableSnapshot? timetable;
  final String? timetableError;
  final bool isRefreshingTimetable;
  final AgentConfig agentConfig;
  final NativeBridge nativeBridge;
  final OnboardingProfile? profile;
  final ValueChanged<AppView> onSelectView;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onCreateSession;
  final ValueChanged<String> onDeleteSession;
  final ValueChanged<String> onSuggestionSelected;
  final VoidCallback onSend;
  final VoidCallback? onLogout;
  final Future<void> Function(OnboardingProfile profile)? onSaveProfile;
  final Future<void> Function(AgentConfig config, String? apiKey)
  onSaveAgentConfig;
  final Future<void> Function(String text) onSaveMemory;
  final Future<void> Function() onRefreshTimetable;
  final ValueChanged<bool> onCompactMessagesChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        sessions: sessions.where((session) => session.hasTurns).toList(),
        activeSessionId: activeSessionId,
        onSelectSession: onSelectSession,
        onSelectHome: () => onSelectView(AppView.home),
        onCreateSession: onCreateSession,
        onDeleteSession: onDeleteSession,
      ),
      bottomNavigationBar: selectedView == AppView.chat
          ? null
          : NavigationBar(
              selectedIndex: _navigationViews.indexOf(selectedView),
              onDestinationSelected: (index) =>
                  onSelectView(_navigationViews[index]),
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  selectedIcon: Icon(Icons.home_rounded),
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.chat_bubble_rounded),
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  label: 'Chat',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.calendar_month_rounded),
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Schedule',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.restaurant_rounded),
                  icon: Icon(Icons.restaurant_outlined),
                  label: 'Campus',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.psychology_alt_rounded),
                  icon: Icon(Icons.psychology_alt_outlined),
                  label: 'Notes',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.settings_rounded),
                  icon: Icon(Icons.settings_outlined),
                  label: 'Settings',
                ),
              ],
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
                  StudyHeader(
                    status: status,
                    onCreateSession: selectedView == AppView.chat
                        ? onCreateSession
                        : null,
                  ),
                  Expanded(
                    child: AgentSelectedView(
                      selectedView: selectedView,
                      sessions: sessions,
                      activeSessionId: activeSessionId,
                      inputController: inputController,
                      messageScrollController: messageScrollController,
                      isSending: isSending,
                      compactMessages: compactMessages,
                      onSuggestionSelected: onSuggestionSelected,
                      onSend: onSend,
                      onSelectView: onSelectView,
                      worldState: worldState,
                      memoryText: memoryText,
                      timetable: timetable,
                      timetableError: timetableError,
                      isRefreshingTimetable: isRefreshingTimetable,
                      agentConfig: agentConfig,
                      nativeBridge: nativeBridge,
                      profile: profile,
                      status: status,
                      onLogout: onLogout,
                      onSaveProfile: onSaveProfile,
                      onSaveAgentConfig: onSaveAgentConfig,
                      onSaveMemory: onSaveMemory,
                      onRefreshTimetable: onRefreshTimetable,
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

const List<AppView> _navigationViews = <AppView>[
  AppView.home,
  AppView.chat,
  AppView.schedule,
  AppView.campus,
  AppView.memories,
  AppView.settings,
];
