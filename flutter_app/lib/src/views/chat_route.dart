import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_shell_scope.dart';
import '../chat_session_mutation.dart';
import '../studyos_theme.dart';
import '../widgets/conversation_list.dart';
import 'chat_view.dart';

class ChatRoute extends StatefulWidget {
  const ChatRoute({
    required this.prompt,
    required this.autosend,
    required this.sessionId,
    super.key,
  });

  final String? prompt;
  final bool autosend;
  final String? sessionId;

  @override
  State<ChatRoute> createState() => _ChatRouteState();
}

class _ChatRouteState extends State<ChatRoute> {
  bool _appliedInitialParams = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedInitialParams) return;
    _appliedInitialParams = true;
    final hasParams =
        widget.prompt?.trim().isNotEmpty == true ||
        widget.autosend ||
        widget.sessionId?.trim().isNotEmpty == true;
    if (!hasParams) return;
    final controller = AppShellScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        controller
            .applyChatRoute(
              prompt: widget.prompt,
              autosend: widget.autosend,
              sessionId: widget.sessionId,
            )
            .then((_) {
              if (mounted) context.replace('/chat');
            }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppShellScope.of(context),
      builder: (context, _) {
        final controller = AppShellScope.of(context);
        return Scaffold(
          endDrawer: Drawer(
            backgroundColor: StudyOsColors.background,
            child: ConversationList(
              sessions: controller.sessions,
              activeSessionId: controller.activeSessionId,
              onSelectSession: controller.selectSession,
              onCreateSession: controller.createSession,
              onDeleteSession: controller.deleteSession,
            ),
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
                      _ChatHeader(onCreateSession: controller.createSession),
                      Expanded(
                        child: ChatView(
                          messages: activeSessionFrom(
                            controller.sessions,
                            controller.activeSessionId,
                          ).messages,
                          inputController: controller.inputController,
                          messageScrollController:
                              controller.messageScrollController,
                          isSending: controller.isSending,
                          compactMessages: controller.compactMessages,
                          onSuggestionSelected: controller.useSuggestion,
                          onSend: controller.sendMessage,
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
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.onCreateSession});

  final VoidCallback onCreateSession;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, StudyOsSpacing.lg, 0, 10),
      child: Row(
        children: <Widget>[
          _HeaderIconButton(
            tooltip: 'Back',
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          const SizedBox(width: StudyOsSpacing.md),
          Expanded(
            child: Text(
              'StudyOS Agent',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Builder(
            builder: (context) => _HeaderIconButton(
              tooltip: 'Chat history',
              icon: Icons.history_rounded,
              onPressed: Scaffold.of(context).openEndDrawer,
            ),
          ),
          const SizedBox(width: StudyOsSpacing.sm),
          _HeaderIconButton(
            tooltip: 'New chat',
            icon: Icons.add_comment_outlined,
            onPressed: onCreateSession,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: IconButton(
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: StudyOsColors.surface,
          foregroundColor: StudyOsColors.text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
            side: const BorderSide(color: StudyOsColors.border),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
