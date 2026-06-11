import 'dart:async';

import 'package:flutter/material.dart';

import 'models.dart';
import 'studyos_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({required this.onLogin, super.key});

  final Future<void> Function(UserSession session, String password) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your university ID and password.');
      return;
    }

    _passwordController.clear();
    unawaited(widget.onLogin(UserSession(username: username), password));
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      title: 'StudyOS Agent',
      subtitle: 'Connect your student workspace',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _InputField(
            controller: _usernameController,
            label: 'University ID or email',
            icon: Icons.account_circle_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          _InputField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            onSubmitted: _submit,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.md),
            Text(_error!, style: const TextStyle(color: StudyOsColors.warning)),
          ],
          const SizedBox(height: StudyOsSpacing.xl),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continue'),
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
  late final TextEditingController _emailController;
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
    _emailController = TextEditingController(
      text: widget.session.displayEmail ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _degreeController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  void _submit() {
    final displayName = _nameController.text.trim();
    final email = _emailController.text.trim();
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
        email: email.contains('@') ? email : null,
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
          _InputField(
            controller: _nameController,
            label: 'Name',
            icon: Icons.badge_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          _InputField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          _InputField(
            controller: _degreeController,
            label: 'Degree program',
            icon: Icons.school_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          _InputField(
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

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label),
    );
  }
}
