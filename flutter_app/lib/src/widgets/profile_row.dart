import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

class ProfileRow extends StatelessWidget {
  const ProfileRow({required this.profile, this.onEdit, super.key});

  final OnboardingProfile? profile;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: StudyOsColors.accent.withValues(alpha: 0.14),
        child: const Icon(Icons.person_outline_rounded),
      ),
      title: Text(profile?.displayName ?? 'Profile not connected'),
      subtitle: Text(
        profile == null
            ? 'Sign in to personalize StudyOS.'
            : _profileSubtitle(profile),
      ),
      trailing: profile == null
          ? null
          : IconButton(
              tooltip: 'Edit profile',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
      onTap: profile == null ? null : onEdit,
    );
  }

  String _profileSubtitle(OnboardingProfile profile) {
    final semester = profile.semester;
    final parts = <String>[
      if (profile.email != null && profile.email!.isNotEmpty) profile.email!,
      profile.username,
      profile.degreeProgram,
      if (semester != null) 'Semester $semester',
      if (profile.livesInTuebingen) 'Tübingen',
    ];
    return parts.join(' · ');
  }
}
