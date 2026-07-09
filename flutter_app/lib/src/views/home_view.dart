import 'package:flutter/material.dart';

import '../assistant_copy.dart';
import '../models.dart';
import '../studyos_theme.dart';
import '../widgets/proactive_feed_section.dart';

class HomeView extends StatelessWidget {
  const HomeView({
    required this.profile,
    required this.config,
    required this.snapshot,
    required this.memoryText,
    required this.timetable,
    required this.onOpenProfile,
    required this.onOpenAssistant,
    required this.onOpenNotes,
    required this.onOpenMail,
    required this.onOpenMaps,
    required this.onOpenCampus,
    required this.onOpenSchedule,
    required this.onRefresh,
    super.key,
  });

  final OnboardingProfile? profile;
  final AgentConfig config;
  final HomeFeedSnapshot snapshot;
  final String memoryText;
  final TimetableSnapshot? timetable;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenAssistant;
  final VoidCallback onOpenNotes;
  final VoidCallback onOpenMail;
  final VoidCallback onOpenMaps;
  final VoidCallback onOpenCampus;
  final VoidCallback onOpenSchedule;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: StudyOsSpacing.xl, bottom: 96),
        children: <Widget>[
          _HomeHeader(profile: profile),
          const SizedBox(height: StudyOsSpacing.lg),
          ProactiveFeedSection(snapshot: snapshot, onRefresh: onRefresh),
          const SizedBox(height: StudyOsSpacing.xl),
          _StatusGrid(
            items: <_HomeStatusItem>[
              _HomeStatusItem(
                cardKey: const ValueKey<String>('home-status-profile'),
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                value: profile == null ? 'Not connected' : 'Connected',
                onTap: onOpenProfile,
              ),
              _HomeStatusItem(
                cardKey: const ValueKey<String>('home-status-assistant'),
                icon: Icons.auto_awesome_outlined,
                label: 'Assistant',
                value: assistantSetupLabel(config),
                onTap: onOpenAssistant,
              ),
              _HomeStatusItem(
                cardKey: const ValueKey<String>('home-status-notes'),
                icon: Icons.psychology_alt_outlined,
                label: 'Notes',
                value: memoryText.trim().isEmpty ? 'Not yet' : 'Saved',
                onTap: onOpenNotes,
              ),
              _HomeStatusItem(
                cardKey: const ValueKey<String>('home-status-timetable'),
                icon: Icons.calendar_month_outlined,
                label: 'Timetable',
                value: _timetableStatus,
                onTap: onOpenSchedule,
              ),
              _HomeStatusItem(
                cardKey: const ValueKey<String>('home-status-mail'),
                icon: Icons.mark_email_unread_outlined,
                label: 'Mail',
                value: profile == null ? 'Sign in needed' : 'Local tools ready',
                onTap: onOpenMail,
              ),
              _HomeStatusItem(
                cardKey: const ValueKey<String>('home-status-map'),
                icon: Icons.map_outlined,
                label: 'Map',
                value: 'Tübingen',
                onTap: onOpenMaps,
              ),
            ],
          ),
          const SizedBox(height: StudyOsSpacing.lg),
          _HomeCard(
            icon: Icons.event_available_outlined,
            title: 'Next lecture',
            body: _nextLectureLine(),
            trailing: _nextLectureCountdown(),
            onTap: onOpenSchedule,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          _HomeCard(
            icon: Icons.mail_outline_rounded,
            title: 'Inbox',
            body: 'Browse folders or ask the agent to search recent mail.',
            onTap: onOpenMail,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          _HomeCard(
            key: const ValueKey<String>('home-maps-card'),
            icon: Icons.map_outlined,
            title: 'Navigate',
            body: 'Search destinations and ask StudyOS about routes.',
            onTap: onOpenMaps,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          _HomeCard(
            key: const ValueKey<String>('home-campus-card'),
            icon: Icons.restaurant_outlined,
            title: 'Campus',
            body: _campusLine(profile),
            onTap: onOpenCampus,
          ),
        ],
      ),
    );
  }

  String get _timetableStatus {
    final snapshot = timetable;
    if (snapshot == null) return 'Not synced yet';
    return snapshot.isStale ? 'Refresh due' : 'Synced';
  }

  String _nextLectureLine() {
    final next = timetable?.nextLectureAt(DateTime.now());
    if (next == null) return 'Refresh your timetable to see upcoming lectures.';
    final location = next.location == null ? '' : ' · ${next.location}';
    return '${next.dayLabel} · ${next.timeRangeText}$location';
  }

  Widget? _nextLectureCountdown() {
    final now = DateTime.now();
    final next = timetable?.nextLectureAt(now);
    if (next == null) return null;
    return _TimeLeftPill(label: next.relativeTimeLabel(now));
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.profile});

  final OnboardingProfile? profile;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
      ],
    );
  }

  String _profileLine(OnboardingProfile profile) {
    final parts = <String>[
      profile.degreeProgram,
      if (profile.semester != null) 'Semester ${profile.semester}',
    ];
    return parts.join(' · ');
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
          _HomeCard(
            key: item.cardKey,
            icon: item.icon,
            title: item.label,
            body: item.value,
            onTap: item.onTap,
          ),
      ],
    );
  }
}

class _HomeStatusItem {
  const _HomeStatusItem({
    required this.cardKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final Key cardKey;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.icon,
    required this.title,
    required this.body,
    this.trailing,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveTrailing =
        trailing ??
        (onTap == null
            ? null
            : const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: StudyOsColors.textMuted,
              ));
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(icon, size: 32, color: StudyOsColors.accent),
                  const Spacer(),
                  ?effectiveTrailing,
                ],
              ),
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

class _TimeLeftPill extends StatelessWidget {
  const _TimeLeftPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudyOsColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudyOsSpacing.sm,
          vertical: StudyOsSpacing.xs,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: StudyOsColors.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
