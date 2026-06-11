import 'package:flutter/material.dart';

import 'src/agent_home_page.dart';
import 'src/models.dart';
import 'src/onboarding_flow.dart';
import 'src/studyos_theme.dart';

void main() {
  runApp(const StudyOsAgentApp());
}

class StudyOsAgentApp extends StatefulWidget {
  const StudyOsAgentApp({super.key});

  @override
  State<StudyOsAgentApp> createState() => _StudyOsAgentAppState();
}

class _StudyOsAgentAppState extends State<StudyOsAgentApp> {
  UserSession? _session;
  OnboardingProfile? _profile;

  void _handleLogin(UserSession session) {
    setState(() => _session = session);
  }

  void _handleOnboardingComplete(OnboardingProfile profile) {
    setState(() => _profile = profile);
  }

  void _handleLogout() {
    setState(() {
      _session = null;
      _profile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StudyOS Agent',
      theme: buildStudyOsTheme(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    final session = _session;
    final profile = _profile;
    if (session == null) {
      return LoginPage(onLogin: _handleLogin);
    }
    if (profile == null) {
      return OnboardingPage(
        session: session,
        onComplete: _handleOnboardingComplete,
      );
    }
    return AgentHomePage(profile: profile, onLogout: _handleLogout);
  }
}
