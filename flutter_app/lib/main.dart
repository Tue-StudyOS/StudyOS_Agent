import 'dart:async';

import 'package:flutter/material.dart';

import 'src/agent_home_page.dart';
import 'src/models.dart';
import 'src/onboarding_flow.dart';
import 'src/profile_store.dart';
import 'src/studyos_theme.dart';
import 'src/tuebingen_profile_client.dart';

void main() {
  runApp(const StudyOsAgentApp());
}

class StudyOsAgentApp extends StatefulWidget {
  const StudyOsAgentApp({super.key});

  @override
  State<StudyOsAgentApp> createState() => _StudyOsAgentAppState();
}

class _StudyOsAgentAppState extends State<StudyOsAgentApp> {
  final ProfileStore _profileStore = ProfileStore();

  UserSession? _session;
  OnboardingProfile? _profile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    final profile = await _profileStore.loadProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _isLoadingProfile = false;
    });
  }

  Future<void> _handleLogin(UserSession session, String password) async {
    final profileClient = TuebingenProfileClient();
    final prefill = await profileClient
        .fetch(username: session.username, password: password)
        .whenComplete(profileClient.close);
    final enrichedSession = UserSession(
      username: session.username,
      displayName: prefill.displayName,
      email: prefill.email,
      degreeProgram: prefill.degreeProgram,
      profileWarning: prefill.warning,
    );
    await _profileStore.saveLogin(session: enrichedSession, password: password);
    if (!mounted) return;
    setState(() => _session = enrichedSession);
  }

  Future<void> _handleOnboardingComplete(OnboardingProfile profile) async {
    await _saveProfile(profile);
  }

  Future<void> _saveProfile(OnboardingProfile profile) async {
    await _profileStore.saveProfile(profile);
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  void _handleLogout() {
    unawaited(_clearProfile());
  }

  Future<void> _clearProfile() async {
    await _profileStore.clear();
    if (!mounted) return;
    setState(() {
      _session = null;
      _profile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StudyOS',
      theme: buildStudyOsTheme(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_isLoadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session;
    final profile = _profile;
    if (profile != null) {
      return AgentHomePage(
        profile: profile,
        onLogout: _handleLogout,
        onSaveProfile: _saveProfile,
      );
    }
    if (session == null) {
      return LoginPage(onLogin: _handleLogin);
    }
    return OnboardingPage(
      session: session,
      onComplete: _handleOnboardingComplete,
    );
  }
}
