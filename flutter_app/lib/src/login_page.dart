import 'dart:async';

import 'package:flutter/material.dart';

import 'models.dart';
import 'onboarding_scaffold.dart';
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
    return OnboardingScaffold(
      title: 'StudyOS',
      subtitle: 'Connect your student workspace',
      backgroundImageAsset: 'assets/images/tuebingen_login_background.jpg',
      backgroundBlurSigma: 4,
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
