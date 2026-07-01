import 'package:flutter/widgets.dart';

import 'app_shell_controller.dart';

class AppShellScope extends InheritedNotifier<AppShellController> {
  const AppShellScope({
    required AppShellController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppShellController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppShellScope>();
    assert(scope != null, 'No AppShellScope found in context.');
    return scope!.notifier!;
  }
}
