import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_shell_controller.dart';
import 'app_shell_scope.dart';
import 'models.dart';
import 'onboarding_flow.dart';
import 'views/campus_view.dart';
import 'views/chat_route.dart';
import 'views/home_view.dart';
import 'views/mail_view.dart';
import 'views/maps_view.dart';
import 'views/memories_view.dart';
import 'views/profile_edit_view.dart';
import 'views/schedule_view.dart';
import 'views/settings_view.dart';
import 'views/shell_scaffold.dart';

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
    initialLocation: '/home',
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
                path: '/schedule',
                builder: (context, state) =>
                    _ScheduleRoute(controller: shellController()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/mail',
                builder: (context, state) =>
                    _MailRoute(controller: shellController()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/campus',
                builder: (context, state) =>
                    _CampusRoute(controller: shellController()),
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
        path: '/voice',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Voice assist coming soon')),
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
        memoryText: controller.memoryText,
        timetable: controller.timetable,
        onOpenMail: () => context.go('/mail'),
        onOpenMaps: () => context.push('/maps'),
        onOpenCampus: () => context.go('/campus'),
        onOpenSchedule: () => context.go('/schedule'),
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
        profile: controller.profile,
        snapshot: controller.timetable,
        error: controller.timetableError,
        isRefreshing: controller.isRefreshingTimetable,
        onRefresh: controller.refreshTimetable,
      ),
    );
  }
}

class _MailRoute extends StatelessWidget {
  const _MailRoute({required this.controller});

  final AppShellController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? AppShellScope.of(context);
    return MailView(profile: controller.profile);
  }
}

class _CampusRoute extends StatelessWidget {
  const _CampusRoute({required this.controller});

  final AppShellController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? AppShellScope.of(context);
    return CampusView(profile: controller.profile);
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
      onSaved: (updated) async {
        await controller.saveProfile(updated);
        if (context.mounted) context.pop();
      },
    );
  }
}

class _RouteScaffold extends StatelessWidget {
  const _RouteScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

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
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
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
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
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
