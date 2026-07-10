import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_shell_scope.dart';
import '../studyos_theme.dart';
import '../widgets/shell_app_bar.dart';
import '../widgets/study_bottom_bar.dart';

class ShellScaffold extends StatefulWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  Offset _contentOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final selectedIndex = navigationShell.currentIndex;
    return ListenableBuilder(
      listenable: AppShellScope.of(context),
      builder: (context, _) {
        return Scaffold(
          bottomNavigationBar: StudyBottomBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: _goBranch,
            onAssistantPressed: () => context.push('/chat'),
            onAssistantLongPress: () => context.go('/voice'),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StudyOsSpacing.xl,
                  ),
                  child: Column(
                    children: <Widget>[
                      const ShellAppBar(),
                      Expanded(
                        child: GestureDetector(
                          key: const ValueKey<String>('shell-swipe-area'),
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragEnd: (details) {
                            final velocity =
                                details.primaryVelocity?.round() ?? 0;
                            if (velocity.abs() < 250) return;
                            final direction = velocity < 0 ? 1 : -1;
                            final nextIndex = selectedIndex + direction;
                            if (nextIndex < 0 || nextIndex > 1) return;
                            _goBranch(nextIndex);
                          },
                          child: ClipRect(
                            child: AnimatedSlide(
                              offset: _contentOffset,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              child: navigationShell,
                            ),
                          ),
                        ),
                      ),
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

  void _goBranch(int index) {
    final currentIndex = widget.navigationShell.currentIndex;
    if (index != currentIndex) {
      setState(() {
        _contentOffset = Offset(index > currentIndex ? 1 : -1, 0);
      });
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == currentIndex,
    );
    if (index == currentIndex) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _contentOffset = Offset.zero);
    });
  }
}
