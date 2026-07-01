import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_shell_scope.dart';
import '../studyos_theme.dart';
import '../widgets/secondary_destinations_drawer.dart';
import '../widgets/shell_app_bar.dart';
import '../widgets/study_bottom_bar.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = navigationShell.currentIndex;
    return ListenableBuilder(
      listenable: AppShellScope.of(context),
      builder: (context, _) {
        return Scaffold(
          drawer: const SecondaryDestinationsDrawer(),
          floatingActionButton: AskFab(
            onPressed: () => context.push('/chat'),
            onLongPress: () {
              // TODO(voice): route to /voice when push-to-talk is implemented.
            },
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: StudyBottomBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
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
                      ShellAppBar(title: _titleForIndex(selectedIndex)),
                      Expanded(child: navigationShell),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _titleForIndex(int index) {
    return switch (index) {
      1 => 'Schedule',
      2 => 'Mail',
      3 => 'Campus',
      _ => 'Home',
    };
  }
}
