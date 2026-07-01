import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';
import '../widgets/profile_form.dart';

class ProfileEditView extends StatelessWidget {
  const ProfileEditView({required this.profile, this.onSaved, super.key});

  final OnboardingProfile profile;
  final Future<void> Function(OnboardingProfile profile)? onSaved;

  @override
  Widget build(BuildContext context) {
    final session = UserSession(
      username: profile.username,
      displayName: profile.displayName,
      email: profile.email,
      degreeProgram: profile.degreeProgram,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(StudyOsSpacing.lg),
              children: <Widget>[
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: StudyOsSpacing.xs),
                Text(
                  'Update your study preferences and personalization.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: StudyOsSpacing.lg),
                ProfileForm(
                  session: session,
                  initialProfile: profile,
                  submitLabel: 'Save profile',
                  onSubmit: (updated) {
                    final onSaved = this.onSaved;
                    if (onSaved == null) {
                      Navigator.of(context).pop(updated);
                      return;
                    }
                    unawaited(onSaved(updated));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
