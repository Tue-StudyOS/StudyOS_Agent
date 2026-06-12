import 'package:flutter/material.dart';

import '../assistant_copy.dart';
import '../models.dart';
import '../studyos_theme.dart';

class HomeView extends StatelessWidget {
  const HomeView({
    required this.profile,
    required this.config,
    required this.memoryText,
    required this.timetable,
    required this.onOpenCampus,
    required this.onOpenSchedule,
    super.key,
  });

  final OnboardingProfile? profile;
  final AgentConfig config;
  final String memoryText;
  final TimetableSnapshot? timetable;
  final VoidCallback onOpenCampus;
  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    return ListView(
      padding: const EdgeInsets.only(top: StudyOsSpacing.sm),
      children: <Widget>[
        Text(
          profile == null ? 'Home' : 'Hi ${profile.displayName}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: StudyOsSpacing.xs),
        Text(
          profile == null
              ? 'Connect your student profile to personalize StudyOS.'
              : _profileLine(profile),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        _StatusGrid(
          items: <_HomeStatusItem>[
            _HomeStatusItem(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              value: profile == null ? 'Not connected' : 'Connected',
            ),
            _HomeStatusItem(
              icon: Icons.auto_awesome_outlined,
              label: 'Assistant',
              value: assistantSetupLabel(config),
            ),
            _HomeStatusItem(
              icon: Icons.psychology_alt_outlined,
              label: 'Notes',
              value: memoryText.trim().isEmpty ? 'Not yet' : 'Saved',
            ),
            _HomeStatusItem(
              icon: Icons.calendar_month_outlined,
              label: 'Timetable',
              value: _timetableStatus,
            ),
          ],
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        _HomeCard(
          icon: Icons.event_available_outlined,
          title: 'Next lecture',
          body: _nextLectureLine(),
          onTap: onOpenSchedule,
        ),
        const SizedBox(height: StudyOsSpacing.md),
        _HomeCard(
          icon: Icons.restaurant_outlined,
          title: 'Campus',
          body: _campusLine(profile),
          onTap: onOpenCampus,
        ),
      ],
    );
  }

  String get _timetableStatus {
    final snapshot = timetable;
    if (snapshot == null) return 'Not synced yet';
    return snapshot.isStale ? 'Refresh due' : 'Synced';
  }

  String _nextLectureLine() {
    final next = timetable?.nextLecture;
    if (next == null) return 'Refresh your timetable to see upcoming lectures.';
    final location = next.location == null ? '' : ' · ${next.location}';
    return '${next.dayLabel} · ${next.timeRangeText}$location';
  }

  String _profileLine(OnboardingProfile profile) {
    final semester = profile.semester;
    final parts = <String>[
      profile.degreeProgram,
      if (semester != null) 'Semester $semester',
      if (profile.livesInTuebingen) 'Tübingen',
    ];
    return parts.join(' · ');
  }

  String _campusLine(OnboardingProfile? profile) {
    if (profile?.interests.contains(StudyInterest.mensa) == true) {
      final preference = profile!.foodPreference;
      if (preference == FoodPreference.noPreference) {
        return 'Mensa meals will appear here when campus data is connected.';
      }
      return '${preference.label} Mensa options will appear here.';
    }
    return 'Mensa, rooms, and campus shortcuts will appear here.';
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.items});

  final List<_HomeStatusItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width < 520 ? 2 : 4,
      childAspectRatio: 1.25,
      mainAxisSpacing: StudyOsSpacing.md,
      crossAxisSpacing: StudyOsSpacing.md,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        for (final item in items)
          _HomeCard(icon: item.icon, title: item.label, body: item.value),
      ],
    );
  }
}

class _HomeStatusItem {
  const _HomeStatusItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudyOsColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: StudyOsColors.border),
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(StudyOsSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Icon(icon, color: StudyOsColors.accent),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: StudyOsSpacing.xs),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
