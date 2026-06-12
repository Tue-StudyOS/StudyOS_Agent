import 'package:flutter/material.dart';

import '../feedback_client.dart';
import '../studyos_theme.dart';

class FeedbackSettingsCard extends StatefulWidget {
  const FeedbackSettingsCard({
    required this.status,
    this.client,
    this.credentialStore,
    super.key,
  });

  final String status;
  final FeedbackClient? client;
  final FeedbackCredentialStore? credentialStore;

  @override
  State<FeedbackSettingsCard> createState() => _FeedbackSettingsCardState();
}

class _FeedbackSettingsCardState extends State<FeedbackSettingsCard> {
  late final TextEditingController _controller;
  late final TextEditingController _tokenController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _tokenController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _isSending = true);
    try {
      final store = widget.credentialStore ?? FeedbackCredentialStore();
      final providedToken = _tokenController.text.trim();
      if (providedToken.isNotEmpty) await store.saveToken(providedToken);
      final token = providedToken.isEmpty
          ? (await store.readToken() ?? '')
          : providedToken;
      await (widget.client ?? FeedbackClient()).submit(
        token: token,
        message: _controller.text,
        status: widget.status,
      );
      _controller.clear();
      _tokenController.clear();
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
              'Create a StudyOS GitHub issue directly from this device. The issue token is stored in secure storage.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: StudyOsSpacing.md),
            TextField(
              controller: _tokenController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'GitHub issue token',
                hintText: 'Fine-grained token with Issues write',
                prefixIcon: Icon(Icons.key_rounded),
              ),
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
