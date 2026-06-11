import 'dart:async';

import 'package:flutter/material.dart';

import 'models.dart';
import 'studyos_theme.dart';
import 'widgets/study_input_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({required this.onLogin, super.key});

  final Future<void> Function(UserSession session, String password) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your university ID and password.');
      return;
    }

    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    try {
      await widget.onLogin(UserSession(username: username), password);
      _passwordController.clear();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      title: 'StudyOS Agent',
      subtitle: 'Connect your student workspace',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudyInputField(
            controller: _usernameController,
            label: 'University ID or email',
            icon: Icons.account_circle_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          StudyInputField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            onSubmitted: () => unawaited(_submit()),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.md),
            Text(_error!, style: const TextStyle(color: StudyOsColors.warning)),
          ],
          const SizedBox(height: StudyOsSpacing.xl),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : () => unawaited(_submit()),
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(_isSubmitting ? 'Connecting' : 'Continue'),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    required this.session,
    required this.onComplete,
    super.key,
  });

  final UserSession session;
  final ValueChanged<OnboardingProfile> onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final TextEditingController _nameController;
  final TextEditingController _degreeController = TextEditingController();
  final TextEditingController _semesterController = TextEditingController();
  bool _livesInTuebingen = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.session.suggestedDisplayName,
    );
    _degreeController.text = widget.session.degreeProgram ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _degreeController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  void _submit() {
    final displayName = _nameController.text.trim();
    final degreeProgram = _degreeController.text.trim();
    final semesterText = _semesterController.text.trim();
    final semester = semesterText.isEmpty ? null : int.tryParse(semesterText);

    if (displayName.isEmpty || degreeProgram.isEmpty) {
      setState(() => _error = 'Enter your name and degree program.');
      return;
    }
    if (semesterText.isNotEmpty && semester == null) {
      setState(() => _error = 'Semester must be a number.');
      return;
    }

    widget.onComplete(
      OnboardingProfile(
        displayName: displayName,
        username: widget.session.username,
        email: widget.session.displayEmail,
        degreeProgram: degreeProgram,
        semester: semester,
        livesInTuebingen: _livesInTuebingen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      title: 'Set up profile',
      subtitle: widget.session.username,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudyInputField(
            controller: _nameController,
            label: 'Name',
            icon: Icons.badge_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          StudyInputField(
            controller: _degreeController,
            label: 'Degree program',
            icon: Icons.school_outlined,
            textInputAction: TextInputAction.next,
          ),
          if (widget.session.profileWarning != null) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.sm),
            Text(
              widget.session.profileWarning!,
              style: const TextStyle(color: StudyOsColors.warning),
            ),
          ],
          const SizedBox(height: StudyOsSpacing.md),
          StudyInputField(
            controller: _semesterController,
            label: 'Semester',
            icon: Icons.format_list_numbered_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lives in Tübingen'),
            value: _livesInTuebingen,
            onChanged: (value) => setState(() => _livesInTuebingen = value),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.md),
            Text(_error!, style: const TextStyle(color: StudyOsColors.warning)),
          ],
          const SizedBox(height: StudyOsSpacing.xl),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Start StudyOS'),
          ),
        ],
      ),
    );
  }
}

class _OnboardingScaffold extends StatelessWidget {
  const _OnboardingScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(StudyOsSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Material(
                color: StudyOsColors.surface,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: StudyOsColors.border),
                  borderRadius: BorderRadius.circular(StudyOsRadii.lg),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(StudyOsSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: StudyOsSpacing.xs),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: StudyOsSpacing.xl),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
