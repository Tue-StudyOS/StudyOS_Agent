import 'package:flutter/material.dart';

import '../student_profile.dart';
import '../studyos_theme.dart';

class InterestChoiceSection extends StatelessWidget {
  const InterestChoiceSection({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final Set<StudyInterest> selected;
  final ValueChanged<Set<StudyInterest>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ChoiceSection<StudyInterest>(
      title: 'What should StudyOS help with?',
      options: StudyInterest.values,
      selected: selected,
      labelFor: (value) => value.label,
      onChanged: onChanged,
    );
  }
}

class FoodPreferenceSection extends StatelessWidget {
  const FoodPreferenceSection({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final FoodPreference selected;
  final ValueChanged<FoodPreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SingleChoiceSection<FoodPreference>(
      title: 'Mensa preference',
      options: FoodPreference.values,
      selected: selected,
      labelFor: (value) => value.label,
      onChanged: onChanged,
    );
  }
}

class NotificationChoiceSection extends StatelessWidget {
  const NotificationChoiceSection({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final Set<NotificationPreference> selected;
  final ValueChanged<Set<NotificationPreference>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ChoiceSection<NotificationPreference>(
      title: 'Notifications',
      options: NotificationPreference.values,
      selected: selected,
      labelFor: (value) => value.label,
      onChanged: onChanged,
    );
  }
}

class _ChoiceSection<T> extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
  });

  final String title;
  final List<T> options;
  final Set<T> selected;
  final String Function(T value) labelFor;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      child: Wrap(
        spacing: StudyOsSpacing.sm,
        runSpacing: StudyOsSpacing.sm,
        children: <Widget>[
          for (final option in options)
            FilterChip(
              label: Text(labelFor(option)),
              selected: selected.contains(option),
              onSelected: (isSelected) {
                final next = <T>{...selected};
                isSelected ? next.add(option) : next.remove(option);
                onChanged(next);
              },
            ),
        ],
      ),
    );
  }
}

class _SingleChoiceSection<T> extends StatelessWidget {
  const _SingleChoiceSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
  });

  final String title;
  final List<T> options;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      child: Wrap(
        spacing: StudyOsSpacing.sm,
        runSpacing: StudyOsSpacing.sm,
        children: <Widget>[
          for (final option in options)
            ChoiceChip(
              label: Text(labelFor(option)),
              selected: selected == option,
              onSelected: (_) => onChanged(option),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: StudyOsSpacing.sm),
        child,
      ],
    );
  }
}
