import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'src/app_router.dart';
import 'src/app_shell_controller.dart';
import 'src/models.dart';
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
  late final AuthRouterState _authState;
  late final GoRouter _router;

  UserSession? _session;
  OnboardingProfile? _profile;
  bool _isLoadingProfile = true;
  AppShellController? _shellController;

  @override
  void initState() {
    super.initState();
    _authState = AuthRouterState(
      initialSession: _session,
      initialProfile: _profile,
      initialLoading: _isLoadingProfile,
    );
    _router = buildAppRouter(
      authState: _authState,
      shellController: () => _shellController,
      onLogin: _handleLogin,
      onOnboardingComplete: _handleOnboardingComplete,
    );
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    final profile = await _profileStore.loadProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _isLoadingProfile = false;
    });
    _syncShellController();
    _syncAuthState();
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
    _syncAuthState();
  }

  Future<void> _handleOnboardingComplete(OnboardingProfile profile) async {
    await _saveProfile(profile);
  }

  Future<void> _saveProfile(OnboardingProfile profile) async {
    await _profileStore.saveProfile(profile);
    if (!mounted) return;
    setState(() => _profile = profile);
    _syncAuthState();
    _syncShellController();
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
    _syncAuthState();
    _disposeShellController();
  }

  void _syncAuthState() {
    _authState.update(
      session: _session,
      profile: _profile,
      isLoading: _isLoadingProfile,
    );
  }

  void _syncShellController() {
    final profile = _profile;
    if (profile == null) {
      _disposeShellController();
      return;
    }
    final existing = _shellController;
    if (existing != null) {
      existing.updateProfile(
        profile: profile,
        onLogout: _handleLogout,
        onSaveProfile: _saveProfile,
      );
      return;
    }
    final controller = AppShellController(
      initialProfile: profile,
      initialOnLogout: _handleLogout,
      initialOnSaveProfile: _saveProfile,
    );
    controller.onOpenChatRequest = (request) {
      _router.go(request.toUri().toString());
    };
    _shellController = controller;
    unawaited(controller.initialize());
  }

  void _disposeShellController() {
    _shellController?.dispose();
    _shellController = null;
  }

  @override
  void dispose() {
    _disposeShellController();
    _router.dispose();
    _authState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'StudyOS',
      theme: buildStudyOsTheme(),
      routerConfig: _router,
    );
  }
}
