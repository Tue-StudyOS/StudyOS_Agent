import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';
import '../widgets/profile_form.dart';

class ProfileEditView extends StatelessWidget {
  const ProfileEditView({
    required this.profile,
    this.onSaved,
    this.onOpenDocuments,
    super.key,
  });

  final OnboardingProfile profile;
  final Future<void> Function(OnboardingProfile profile)? onSaved;
  final VoidCallback? onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    final session = UserSession(
      username: profile.username,
      displayName: profile.displayName,
      email: profile.email,
      degreeProgram: profile.degreeProgram,
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                StudyOsSpacing.xl,
                StudyOsSpacing.md,
                StudyOsSpacing.xl,
                StudyOsSpacing.xxl,
              ),
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: Navigator.of(context).pop,
                    style: IconButton.styleFrom(
                      backgroundColor: StudyOsColors.surface,
                      foregroundColor: StudyOsColors.text,
                    ),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                ),
                const SizedBox(height: StudyOsSpacing.xl),
                Text(
                  'Your profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: StudyOsSpacing.xs),
                Text(
                  'Keep your study details and preferences up to date.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: StudyOsSpacing.xxl),
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
                if (onOpenDocuments != null) ...<Widget>[
                  const SizedBox(height: StudyOsSpacing.xxl),
                  Text(
                    'Official documents',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: StudyOsSpacing.sm),
                  Material(
                    color: StudyOsColors.surface,
                    borderRadius: BorderRadius.circular(StudyOsRadii.md),
                    child: ListTile(
                      onTap: onOpenDocuments,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: StudyOsSpacing.lg,
                        vertical: StudyOsSpacing.xs,
                      ),
                      leading: const Icon(
                        Icons.folder_copy_outlined,
                        color: StudyOsColors.accent,
                      ),
                      title: const Text('ALMA documents'),
                      subtitle: const Text(
                        'Transcript, registrations, and certificates',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
