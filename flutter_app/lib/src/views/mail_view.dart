import 'dart:async';

import 'package:flutter/material.dart';

import '../mail_parsing.dart';
import '../mail_repository.dart';
import '../models.dart';
import '../studyos_theme.dart';

part 'mail_view_components.dart';

class MailView extends StatefulWidget {
  const MailView({required this.profile, this.repository, super.key});

  final OnboardingProfile? profile;
  final MailRepository? repository;

  @override
  State<MailView> createState() => _MailViewState();
}

class _MailViewState extends State<MailView> {
  late final MailRepository _repository = widget.repository ?? MailRepository();
  final TextEditingController _queryController = TextEditingController();
  Timer? _searchDebounce;
  late Future<MailMailboxSnapshot> _state;
  MailMessageDetail? _selectedMessage;
  String? _openingMessageUid;
  String? _messageError;
  String _mailbox = 'INBOX';
  bool _unreadOnly = false;
  String _query = '';
  List<MailboxSummary> _mailboxes = const <MailboxSummary>[];

  @override
  void initState() {
    super.initState();
    // Reuse the shared repository's cache on entry so revisiting the tab is
    // instant; the refresh button forces a live reload.
    _state = _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  /// Reloads the mailbox listing. [force] bypasses the repository cache, e.g.
  /// when the user taps refresh. Switching mailbox, filter, or search keeps the
  /// cache (each combination is a separate cache key).
  void _reload({bool force = false}) {
    setState(() {
      _selectedMessage = null;
      _openingMessageUid = null;
      _messageError = null;
      _state = _load(force: force);
    });
  }

  /// Pull-to-refresh handler: always forces a live reload and keeps the
  /// spinner up until the fresh snapshot resolves.
  Future<void> _handleRefresh() async {
    final future = _load(force: true);
    setState(() {
      _selectedMessage = null;
      _openingMessageUid = null;
      _messageError = null;
      _state = future;
    });
    try {
      await future;
    } on Object {
      // The FutureBuilder renders the error state; nothing to do here.
    }
  }

  Future<MailMailboxSnapshot> _load({bool force = false}) {
    final future = _repository.fetchMailboxSnapshot(
      widget.profile,
      mailbox: _mailbox,
      limit: 20,
      unreadOnly: _unreadOnly,
      query: _query,
      forceRefresh: force,
    );
    // Keep the folder list around so the controls stay put while a search or
    // filter reload is in flight (the future rebuilds the message list only).
    unawaited(
      future
          .then((snapshot) {
            if (!mounted || _sameMailboxes(snapshot.mailboxes)) return;
            setState(() => _mailboxes = snapshot.mailboxes);
          })
          .catchError((Object _) {}),
    );
    return future;
  }

  bool _sameMailboxes(List<MailboxSummary> next) {
    if (_mailboxes.length != next.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (_mailboxes[i].name != next[i].name ||
          _mailboxes[i].unreadCount != next[i].unreadCount) {
        return false;
      }
    }
    return true;
  }

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _applyQuery(value);
    });
  }

  void _applyQuery(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();
    if (!mounted || trimmed == _query) return;
    setState(() => _query = trimmed);
    _reload();
  }

  void _closeMessage() {
    setState(() {
      _selectedMessage = null;
      _openingMessageUid = null;
      _messageError = null;
    });
  }

  Future<void> _openMessage(MailMessageSummary message) async {
    // Tapping the message that is already open collapses it again.
    if (_selectedMessage?.uid == message.uid ||
        _openingMessageUid == message.uid) {
      _closeMessage();
      return;
    }
    setState(() {
      _selectedMessage = null;
      _openingMessageUid = message.uid;
      _messageError = null;
    });
    try {
      final detail = await _repository.fetchMessageDetail(
        widget.profile,
        uid: message.uid,
        mailbox: _mailbox,
      );
      if (!mounted) return;
      setState(() => _selectedMessage = detail);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _messageError = error.toString());
    } finally {
      if (mounted) setState(() => _openingMessageUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: StudyOsSpacing.xl,
          bottom: StudyOsSpacing.xxl,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Inbox',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: StudyOsSpacing.xs),
                    Text(
                      'Your university mail, in one place.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh mail',
                onPressed: () => _reload(force: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: StudyOsSpacing.lg),
          _MailControls(
            mailboxes: _mailboxes,
            mailbox: _mailbox,
            unreadOnly: _unreadOnly,
            queryController: _queryController,
            onQueryChanged: _onQueryChanged,
            onQuerySubmitted: _applyQuery,
            onClearQuery: () {
              _queryController.clear();
              _applyQuery('');
            },
            onMailboxChanged: (value) {
              setState(() => _mailbox = value);
              _reload();
            },
            onUnreadOnlyChanged: (value) {
              setState(() => _unreadOnly = value);
              _reload();
            },
          ),
          const SizedBox(height: StudyOsSpacing.md),
          FutureBuilder<MailMailboxSnapshot>(
            future: _state,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: StudyOsSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _MailMessageCard(
                  icon: Icons.mark_email_unread_outlined,
                  title: 'Could not load mail',
                  body: snapshot.error.toString(),
                );
              }
              final state = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_selectedMessage != null) ...<Widget>[
                    _MailDetailCard(
                      message: _selectedMessage!,
                      onClose: _closeMessage,
                    ),
                    const SizedBox(height: StudyOsSpacing.md),
                  ],
                  if (_openingMessageUid != null) ...<Widget>[
                    const _MailMessageCard(
                      icon: Icons.hourglass_top_rounded,
                      title: 'Opening message',
                      body: 'Loading the selected message...',
                    ),
                    const SizedBox(height: StudyOsSpacing.md),
                  ],
                  if (_messageError != null) ...<Widget>[
                    _MailMessageCard(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not open message',
                      body: _messageError!,
                    ),
                    const SizedBox(height: StudyOsSpacing.md),
                  ],
                  if (state.inbox.messages.isEmpty)
                    _MailMessageCard(
                      icon: _query.isEmpty
                          ? Icons.inbox_outlined
                          : Icons.search_off_rounded,
                      title: _query.isEmpty
                          ? 'No messages found'
                          : 'No messages match your search',
                      body: _query.isEmpty
                          ? 'Try another folder or turn off the unread filter.'
                          : 'No mail in this folder matches "$_query". '
                                'Try a different term or clear the search.',
                    )
                  else
                    Material(
                      color: StudyOsColors.surface,
                      borderRadius: BorderRadius.circular(StudyOsRadii.md),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(StudyOsRadii.md),
                        child: Column(
                          children: <Widget>[
                            for (
                              var index = 0;
                              index < state.inbox.messages.length;
                              index++
                            ) ...<Widget>[
                              _MailSummaryCard(
                                message: state.inbox.messages[index],
                                selected:
                                    _selectedMessage?.uid ==
                                        state.inbox.messages[index].uid ||
                                    _openingMessageUid ==
                                        state.inbox.messages[index].uid,
                                onTap: () =>
                                    _openMessage(state.inbox.messages[index]),
                              ),
                              if (index < state.inbox.messages.length - 1)
                                const Padding(
                                  padding: EdgeInsets.only(left: 62),
                                  child: Divider(),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
