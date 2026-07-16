import 'package:flutter/material.dart';

import '../feedback_client.dart';
import '../feedback_models.dart';
import '../studyos_theme.dart';
import 'feedback_components.dart';

class FeedbackSettingsCard extends StatefulWidget {
  const FeedbackSettingsCard({this.client, super.key});

  final FeedbackClient? client;

  @override
  State<FeedbackSettingsCard> createState() => _FeedbackSettingsCardState();
}

class _FeedbackSettingsCardState extends State<FeedbackSettingsCard> {
  late final TextEditingController _controller;
  late final FeedbackClient _client;
  FeedbackPublicSnapshot? _snapshot;
  FeedbackSubmission? _ownFeedback;
  String? _error;
  String? _reportingId;
  int _rating = 0;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _client = widget.client ?? FeedbackClient();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_client.isConfigured) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final snapshot = await _client.loadPublic();
      final own = await _client.loadOwn();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _ownFeedback = own;
        _rating = own?.rating ?? 0;
        _controller.text = own?.comment ?? '';
        _error = null;
      });
    } on FeedbackException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _send() async {
    if (_rating == 0) {
      _showMessage('Choose a star rating first.');
      return;
    }
    setState(() => _isSending = true);
    try {
      final own = await _client.submit(
        rating: _rating,
        comment: _controller.text,
      );
      final snapshot = await _client.loadPublic();
      if (!mounted) return;
      setState(() {
        _ownFeedback = own;
        _snapshot = snapshot;
        _error = null;
      });
      _showMessage(
        own.commentIsPending
            ? 'Rating saved. Your comment is awaiting review.'
            : 'Rating saved.',
      );
    } on FeedbackException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your feedback?'),
        content: const Text(
          'Your rating and comment will disappear from public results.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);
    try {
      await _client.deleteOwn();
      final snapshot = await _client.loadPublic();
      if (!mounted) return;
      setState(() {
        _ownFeedback = null;
        _snapshot = snapshot;
        _rating = 0;
        _controller.clear();
      });
      _showMessage('Feedback deleted.');
    } on FeedbackException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _report(PublishedFeedbackComment comment) async {
    var reportReason = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report comment'),
        content: TextField(
          maxLength: 500,
          maxLines: 3,
          onChanged: (value) => reportReason = value,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Spam, abuse, personal data…',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reportReason),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _reportingId = comment.id);
    try {
      await _client.report(feedbackId: comment.id, reason: reason);
      _showMessage('Comment reported for review.');
    } on FeedbackException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _reportingId = null);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_client.isConfigured) {
      return const _UnavailableFeedback();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Rate StudyOS', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: StudyOsSpacing.xs),
        Text(
          'Ratings are public. Comments appear after moderation.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: StudyOsSpacing.sm),
        if (_isLoading)
          const LinearProgressIndicator()
        else ...<Widget>[
          FeedbackRatingSummary(snapshot: _snapshot),
          const SizedBox(height: StudyOsSpacing.sm),
          FeedbackStarSelector(
            value: _rating,
            onChanged: (value) => setState(() => _rating = value),
          ),
          const SizedBox(height: StudyOsSpacing.sm),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              hintText: 'What worked, or what should improve?',
            ),
          ),
          if (_error != null) ...<Widget>[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: StudyOsSpacing.sm),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSending || _isDeleting ? null : _send,
                  icon: _isSending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.star_outline_rounded),
                  label: Text(
                    _ownFeedback == null ? 'Send feedback' : 'Update feedback',
                  ),
                ),
              ),
              if (_ownFeedback != null) ...<Widget>[
                const SizedBox(width: StudyOsSpacing.sm),
                IconButton(
                  tooltip: 'Delete my feedback',
                  onPressed: _isSending || _isDeleting ? null : _delete,
                  icon: _isDeleting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
          if (_ownFeedback?.commentStatusMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: StudyOsSpacing.xs),
              child: Text(_ownFeedback!.commentStatusMessage!),
            ),
          if (_snapshot?.comments.isNotEmpty == true) ...<Widget>[
            const Divider(height: StudyOsSpacing.xl),
            PublishedFeedbackComments(
              comments: _snapshot!.comments,
              reportingId: _reportingId,
              onReport: _report,
            ),
          ],
        ],
      ],
    );
  }
}

class _UnavailableFeedback extends StatelessWidget {
  const _UnavailableFeedback();

  @override
  Widget build(BuildContext context) => const ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(Icons.feedback_outlined),
    title: Text('Feedback is unavailable'),
    subtitle: Text('This build is not connected to a feedback service.'),
  );
}
