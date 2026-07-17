import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_shell_controller.dart';
import 'app_shell_scope.dart';
import 'models.dart';
import 'onboarding_flow.dart';
import 'studyos_theme.dart';
import 'views/chat_route.dart';
import 'views/home_view.dart';
import 'views/maps_view.dart';
import 'views/memories_view.dart';
import 'views/official_documents_view.dart';
import 'views/profile_edit_view.dart';
import 'views/schedule_view.dart';
import 'views/settings_view.dart';
import 'views/shell_scaffold.dart';
import 'views/talks_view.dart';
import 'views/voice_assist_view.dart';

class AuthRouterState extends ChangeNotifier {
  AuthRouterState({
    required UserSession? initialSession,
    required OnboardingProfile? initialProfile,
    required bool initialLoading,
  }) : _session = initialSession,
       _profile = initialProfile,
       _isLoading = initialLoading;

  UserSession? _session;
  OnboardingProfile? _profile;
  bool _isLoading;

  UserSession? get session => _session;
  OnboardingProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get hasProfile => _profile != null;

  void update({
    required UserSession? session,
    required OnboardingProfile? profile,
    required bool isLoading,
  }) {
    _session = session;
    _profile = profile;
    _isLoading = isLoading;
    notifyListeners();
  }
}

GoRouter buildAppRouter({
  required AuthRouterState authState,
  required AppShellController? Function() shellController,
  required Future<void> Function(UserSession session, String password) onLogin,
  required Future<void> Function(OnboardingProfile profile)
  onOnboardingComplete,
}) {
  String? redirect(BuildContext context, GoRouterState state) {
    if (authState.isLoading) return null;
    final location = state.uri.path;
    final inLogin = location == '/login';
    final inOnboarding = location == '/onboarding';
    if (authState.profile != null) {
      return inLogin || inOnboarding || location == '/' ? '/home' : null;
    }
    if (authState.session == null) return inLogin ? null : '/login';
    return inOnboarding ? null : '/onboarding';
  }

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authState,
    redirect: redirect,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(onLogin: onLogin),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) {
          final session = authState.session;
          if (session == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return OnboardingPage(
            session: session,
            onComplete: onOnboardingComplete,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _ScopedAppRoute(
          controller: shellController(),
          child: ShellScaffold(navigationShell: navigationShell),
        ),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                builder: (context, state) =>
                    _HomeRoute(controller: shellController()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/plan',
                builder: (context, state) =>
                    _ScheduleRoute(controller: shellController()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => _ScopedAppRoute(
          controller: shellController(),
          child: ChatRoute(
            prompt: state.uri.queryParameters['prompt'],
            autosend: state.uri.queryParameters['autosend'] == 'true',
            sessionId: state.uri.queryParameters['sessionId'],
          ),
        ),
      ),
      GoRoute(
        path: '/maps',
        builder: (context, state) => _ScopedAppRoute(
          controller: shellController(),
          child: _MapsRoute(controller: shellController()),
        ),
      ),
      GoRoute(
        path: '/memories',
        builder: (context, state) => _ScopedAppRoute(
          controller: shellController(),
          child: _MemoriesRoute(controller: shellController()),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => _ScopedAppRoute(
          controller: shellController(),
          child: _SettingsRoute(controller: shellController()),
        ),
      ),
      GoRoute(
        path: '/settings/profile',
        builder: (context, state) => _ScopedAppRoute(
          controller: shellController(),
          child: _ProfileEditRoute(controller: shellController()),
        ),
      ),
      GoRoute(
        path: '/documents',
        builder: (context, state) => _ScopedAppRoute(
          controller: shellController(),
          child: _DocumentsRoute(controller: shellController()),
        ),
      ),
      GoRoute(
        path: '/talks',
        builder: (context, state) => _ScopedAppRoute(
          controller: shellController(),
          child: _TalksRoute(controller: shellController()),
        ),
      ),
      GoRoute(
        path: '/voice',
        builder: (context, state) => _ScopedAppRoute(
          controller: shellController(),
          child: const VoiceAssistView(),
        ),
      ),
    ],
  );
}

class _ScopedAppRoute extends StatelessWidget {
  const _ScopedAppRoute({required this.controller, required this.child});

  final AppShellController? controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return AppShellScope(controller: controller, child: child);
  }
}

class _HomeRoute extends StatelessWidget {
  const _HomeRoute({required this.controller});

  final AppShellController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? AppShellScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => HomeView(
        profile: controller.profile,
        config: controller.agentConfig,
        snapshot: controller.homeFeedSnapshot,
        memoryText: controller.memoryText,
        timetable: controller.timetable,
        onOpenProfile: () => context.push('/settings/profile'),
        onOpenAssistant: () => context.push('/settings'),
        onOpenNotes: () => context.push('/memories'),
        onOpenTalks: () => context.push('/talks'),
        onOpenMail: () =>
            context.push('/chat?prompt=Show%20my%20university%20mail'),
        onOpenMaps: () => context.push('/maps'),
        onOpenCampus: () => context.push(
          '/chat?prompt=What%20is%20good%20at%20the%20Mensa%20today%3F',
        ),
        onOpenSchedule: () => context.go('/plan'),
        onAskAssistant: (prompt) => context.push(
          Uri(path: '/chat', queryParameters: <String, String>{
            'prompt': prompt,
          }).toString(),
        ),
        onRefresh: controller.refreshHomeFeed,
      ),
    );
  }
}

class _ScheduleRoute extends StatelessWidget {
  const _ScheduleRoute({required this.controller});

  final AppShellController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? AppShellScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ScheduleView(
        snapshot: controller.timetable,
        error: controller.timetableError,
        isRefreshing: controller.isRefreshingTimetable,
        onRefresh: controller.refreshTimetable,
        calendarSyncMessage: controller.calendarSyncMessage,
        calendarSyncError: controller.calendarSyncError,
        isSyncingCalendar: controller.isSyncingCalendar,
        onSyncCalendar: controller.syncTimetableToCalendar,
        calendarOverviewSource: controller.calendarOverviewSource,
        academicStatus: controller.academicStatus,
        academicStatusError: controller.academicStatusError,
        isRefreshingAcademicStatus: controller.isRefreshingAcademicStatus,
        onRefreshAcademicStatus: controller.refreshAcademicStatus,
        academicReportError: controller.academicReportError,
        isOpeningAcademicReport: controller.isOpeningAcademicReport,
        onOpenAcademicReport: controller.openAcademicReport,
      ),
    );
  }
}

class _TalksRoute extends StatelessWidget {
  const _TalksRoute({required this.controller});

  final AppShellController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? AppShellScope.of(context);
    return TalksView(repository: controller.talksRepository);
  }
}

class _MapsRoute extends StatelessWidget {
  const _MapsRoute({required this.controller});

  final AppShellController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? AppShellScope.of(context);
    return _RouteScaffold(
      title: 'Map',
      child: MapsView(onAskAssistant: controller.prefillChatPrompt),
    );
  }
}

class _MemoriesRoute extends StatelessWidget {
  const _MemoriesRoute({required this.controller});

  final AppShellController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? AppShellScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _RouteScaffold(
        title: 'Notes',
        showTitle: false,
        child: MemoriesView(
          worldState: controller.worldState,
          memoryText: controller.memoryText,
          onSaveMemory: controller.saveMemory,
        ),
      ),
    );
  }
}

class _SettingsRoute extends StatelessWidget {
  const _SettingsRoute({required this.controller});

  final AppShellController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? AppShellScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _RouteScaffold(
        title: 'Settings',
        showTitle: false,
        child: SettingsView(
          config: controller.agentConfig,
          profile: controller.profile,
          status: controller.status,
          compactMessages: controller.compactMessages,
          onLogout: controller.onLogout,
          onSaveProfile: controller.saveProfile,
          onSaveAgentConfig: controller.saveAgentConfig,
          onCompactMessagesChanged: controller.setCompactMessages,
          nativeBridge: controller.bridge,
        ),
      ),
    );
  }
}

class _ProfileEditRoute extends StatelessWidget {
  const _ProfileEditRoute({required this.controller});

  final AppShellController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? AppShellScope.of(context);
    final profile = controller.profile;
    if (profile == null) {
      return const _RouteScaffold(
        title: 'Edit profile',
        child: Center(child: Text('No profile loaded.')),
      );
    }
    return ProfileEditView(
      profile: profile,
      onOpenDocuments: () => context.push('/documents'),
      onSaved: (updated) async {
        await controller.saveProfile(updated);
        if (context.mounted) context.pop();
      },
    );
  }
}

class _DocumentsRoute extends StatelessWidget {
  const _DocumentsRoute({required this.controller});

  final AppShellController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? AppShellScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.officialDocuments.isEmpty &&
            controller.officialDocumentsError == null &&
            !controller.isLoadingOfficialDocuments) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.loadOfficialDocuments();
          });
        }
        return OfficialDocumentsView(
          documents: controller.officialDocuments,
          error: controller.officialDocumentsError,
          isLoading: controller.isLoadingOfficialDocuments,
          openingDocumentId: controller.openingOfficialDocumentId,
          onRefresh: controller.loadOfficialDocuments,
          onOpen: controller.openOfficialDocument,
        );
      },
    );
  }
}

class _RouteScaffold extends StatelessWidget {
  const _RouteScaffold({
    required this.title,
    required this.child,
    this.showTitle = true,
  });

  final String title;
  final Widget child;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/home');
                            }
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: StudyOsColors.surface,
                            foregroundColor: StudyOsColors.text,
                          ),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                        if (showTitle) ...<Widget>[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
