import 'package:flutter/material.dart';

import '../feedback_client.dart';
import '../studyos_theme.dart';

class FeedbackSettingsCard extends StatefulWidget {
  const FeedbackSettingsCard({required this.status, this.client, super.key});

  final String status;
  final FeedbackClient? client;

  @override
  State<FeedbackSettingsCard> createState() => _FeedbackSettingsCardState();
}

class _FeedbackSettingsCardState extends State<FeedbackSettingsCard> {
  late final TextEditingController _controller;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _isSending = true);
    try {
      await (widget.client ?? FeedbackClient()).submit(
        token: studyOsFeedbackToken,
        message: _controller.text,
        status: widget.status,
      );
      _controller.clear();
      _showMessage('Feedback sent.');
    } on FeedbackException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudyOsColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: StudyOsColors.border),
        borderRadius: BorderRadius.circular(StudyOsRadii.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Feedback', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: StudyOsSpacing.sm),
            Text(
              'Send feedback to the StudyOS team.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: StudyOsSpacing.md),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Feedback',
                hintText: 'What should we improve?',
              ),
            ),
            const SizedBox(height: StudyOsSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSending ? null : _send,
                icon: _isSending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.feedback_outlined),
                label: const Text('Send feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
