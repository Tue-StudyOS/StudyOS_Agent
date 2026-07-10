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
    final next = timetable?.nextLectureAt(DateTime.now());
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: StudyOsSpacing.xl, bottom: 100),
        children: <Widget>[
          _Greeting(profile: profile),
          const SizedBox(height: StudyOsSpacing.xxl),
          _TodayFocus(next: next, onTap: onOpenSchedule),
          const SizedBox(height: StudyOsSpacing.xxl),
          _SectionLabel(label: 'For you'),
          const SizedBox(height: StudyOsSpacing.sm),
          ProactiveFeedSection(snapshot: snapshot, onRefresh: onRefresh),
          const SizedBox(height: StudyOsSpacing.xxl),
          _SectionLabel(label: 'StudyOS'),
          const SizedBox(height: StudyOsSpacing.sm),
          _GroupedList(
            children: <Widget>[
              _ToolRow(
                itemKey: const ValueKey<String>('home-status-profile'),
                icon: Icons.person_outline_rounded,
                title: 'Profile',
                detail: profile == null
                    ? 'Complete your student profile'
                    : 'Your study details',
                onTap: onOpenProfile,
              ),
              _ToolRow(
                itemKey: const ValueKey<String>('home-status-assistant'),
                icon: Icons.auto_awesome_outlined,
                title: 'Assistant',
                detail: assistantSetupLabel(config),
                onTap: onOpenAssistant,
              ),
              _ToolRow(
                itemKey: const ValueKey<String>('home-status-notes'),
                icon: Icons.note_alt_outlined,
                title: 'Notes',
                detail: memoryText.trim().isEmpty
                    ? 'Nothing saved yet'
                    : 'Personal context saved',
                onTap: onOpenNotes,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});

  final OnboardingProfile? profile;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final name = profile?.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$greeting${name == null ? '' : ', $name'}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: StudyOsSpacing.xs),
        Text(_dateLabel(), style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  String _dateLabel() {
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

class _TodayFocus extends StatelessWidget {
  const _TodayFocus({required this.next, required this.onTap});

  final LectureEvent? next;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final lecture = next;
    return Material(
      color: StudyOsColors.text,
      borderRadius: BorderRadius.circular(StudyOsRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StudyOsRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(StudyOsSpacing.xl),
          child: lecture == null
              ? const _FocusContent(
                  eyebrow: 'TODAY',
                  title: 'Your day is clear.',
                  detail: 'Sync your timetable to see what is next.',
                  trailing: Icons.calendar_today_outlined,
                )
              : _FocusContent(
                  eyebrow: lecture.relativeTimeLabel(now).toUpperCase(),
                  title: lecture.title,
                  detail:
                      '${lecture.timeRangeText}${lecture.location == null ? '' : ' · ${lecture.location}'}',
                  trailing: Icons.arrow_forward_rounded,
                ),
        ),
      ),
    );
  }
}

class _FocusContent extends StatelessWidget {
  const _FocusContent({
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.trailing,
  });

  final String eyebrow;
  final String title;
  final String detail;
  final IconData trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              eyebrow,
              style: const TextStyle(
                color: Color(0xFFAEAEB2),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: StudyOsSpacing.sm),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1.12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: StudyOsSpacing.sm),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFD1D1D6), fontSize: 15),
            ),
          ],
        ),
      ),
      const SizedBox(width: StudyOsSpacing.md),
      Icon(trailing, color: Colors.white, size: 23),
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 19),
  );
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(StudyOsRadii.md),
    child: Material(
      color: StudyOsColors.surface,
      child: Column(children: children),
    ),
  );
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.itemKey,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final Key itemKey;
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: itemKey,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: StudyOsSpacing.md,
        vertical: StudyOsSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          _ToolIcon(icon: icon),
          const SizedBox(width: StudyOsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: StudyOsColors.separator,
          ),
        ],
      ),
    ),
  );
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: StudyOsColors.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: StudyOsColors.accent, size: 19),
  );
}
