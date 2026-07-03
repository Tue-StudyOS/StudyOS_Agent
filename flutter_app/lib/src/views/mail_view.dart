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
  late Future<MailMailboxSnapshot> _state;
  MailMessageDetail? _selectedMessage;
  String? _openingMessageUid;
  String? _messageError;
  String _mailbox = 'INBOX';
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _state = _load();
  }

  void _refresh() {
    setState(() {
      _selectedMessage = null;
      _openingMessageUid = null;
      _messageError = null;
      _state = _load();
    });
  }

  Future<MailMailboxSnapshot> _load() {
    return _repository.fetchMailboxSnapshot(
      widget.profile,
      mailbox: _mailbox,
      limit: 20,
      unreadOnly: _unreadOnly,
    );
  }

  Future<void> _openMessage(MailMessageSummary message) async {
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
    return ListView(
      padding: const EdgeInsets.only(top: StudyOsSpacing.sm),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Mail',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: StudyOsSpacing.xs),
                  Text(
                    'University mailbox, folders, and read-only message access.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh mail',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        FutureBuilder<MailMailboxSnapshot>(
          future: _state,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
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
                _MailControls(
                  mailboxes: state.mailboxes,
                  mailbox: _mailbox,
                  unreadOnly: _unreadOnly,
                  onMailboxChanged: (value) {
                    setState(() => _mailbox = value);
                    _refresh();
                  },
                  onUnreadOnlyChanged: (value) {
                    setState(() => _unreadOnly = value);
                    _refresh();
                  },
                ),
                const SizedBox(height: StudyOsSpacing.md),
                if (_selectedMessage != null) ...<Widget>[
                  _MailDetailCard(message: _selectedMessage!),
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
                  const _MailMessageCard(
                    icon: Icons.inbox_outlined,
                    title: 'No messages found',
                    body: 'Try another folder or turn off the unread filter.',
                  )
                else
                  for (final message in state.inbox.messages)
                    _MailSummaryCard(
                      message: message,
                      selected:
                          _selectedMessage?.uid == message.uid ||
                          _openingMessageUid == message.uid,
                      onTap: () => _openMessage(message),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}
