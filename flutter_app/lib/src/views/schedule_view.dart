import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

class ScheduleView extends StatelessWidget {
  const ScheduleView({required this.profile, super.key});

  final OnboardingProfile? profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: StudyOsSpacing.sm),
      children: <Widget>[
        Text('Schedule', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: StudyOsSpacing.xs),
        Text(
          profile == null ? 'No student profile connected.' : _profileLine(),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        Container(
          padding: const EdgeInsets.all(StudyOsSpacing.xl),
          decoration: BoxDecoration(
            color: StudyOsColors.surface,
            border: Border.all(color: StudyOsColors.border),
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
          ),
          child: Column(
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                backgroundColor: StudyOsColors.accent.withValues(alpha: 0.14),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: StudyOsColors.accent,
                ),
              ),
              const SizedBox(height: StudyOsSpacing.lg),
              Text(
                'No timetable synced yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: StudyOsSpacing.sm),
              Text(
                'Upcoming lectures and rooms will appear here once a live timetable source is connected.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _profileLine() {
    final profile = this.profile;
    if (profile == null) return '';
    final parts = <String>[
      profile.degreeProgram,
      if (profile.semester != null) 'Semester ${profile.semester}',
      if (profile.livesInTuebingen) 'Tübingen',
    ];
    return parts.join(' · ');
  }
}
