import 'package:flutter/material.dart';

import 'models.dart';
import 'onboarding_scaffold.dart';
import 'studyos_theme.dart';
import 'widgets/onboarding_choice_section.dart';
import 'widgets/study_input_field.dart';

export 'login_page.dart';

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
  final TextEditingController _degreeController = TextEditingController();
  final TextEditingController _semesterController = TextEditingController();
  Set<StudyInterest> _interests = <StudyInterest>{
    StudyInterest.schedule,
    StudyInterest.deadlines,
  };
  FoodPreference _foodPreference = FoodPreference.noPreference;
  Set<NotificationPreference> _notificationPreferences =
      <NotificationPreference>{};
  bool _livesInTuebingen = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.session.suggestedDisplayName,
    );
    _degreeController.text = widget.session.degreeProgram ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _degreeController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  void _submit() {
    final displayName = _nameController.text.trim();
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
        email: widget.session.displayEmail,
        degreeProgram: degreeProgram,
        semester: semester,
        livesInTuebingen: _livesInTuebingen,
        interests: _interests,
        foodPreference: _interests.contains(StudyInterest.mensa)
            ? _foodPreference
            : FoodPreference.noPreference,
        notificationPreferences:
            _interests.contains(StudyInterest.notifications)
            ? _notificationPreferences
            : <NotificationPreference>{},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Confirm profile',
      subtitle: 'Personalize StudyOS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudyInputField(
            controller: _nameController,
            label: 'Name',
            icon: Icons.badge_outlined,
            textInputAction: TextInputAction.next,
          ),
          if (widget.session.displayEmail != null) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.sm),
            _ReadOnlyProfileValue(
              icon: Icons.alternate_email_rounded,
              label: 'Email',
              value: widget.session.displayEmail!,
            ),
          ],
          const SizedBox(height: StudyOsSpacing.md),
          StudyInputField(
            controller: _degreeController,
            label: 'Degree program',
            icon: Icons.school_outlined,
            textInputAction: TextInputAction.next,
          ),
          if (widget.session.profileWarning != null) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.sm),
            Text(
              widget.session.profileWarning!,
              style: const TextStyle(color: StudyOsColors.warning),
            ),
          ],
          const SizedBox(height: StudyOsSpacing.md),
          StudyInputField(
            controller: _semesterController,
            label: 'Semester',
            icon: Icons.format_list_numbered_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          InterestChoiceSection(
            selected: _interests,
            onChanged: (value) => setState(() {
              _interests = value;
              if (!_interests.contains(StudyInterest.mensa)) {
                _foodPreference = FoodPreference.noPreference;
              }
              if (!_interests.contains(StudyInterest.notifications)) {
                _notificationPreferences = <NotificationPreference>{};
              }
            }),
          ),
          if (_interests.contains(StudyInterest.mensa)) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.md),
            FoodPreferenceSection(
              selected: _foodPreference,
              onChanged: (value) => setState(() => _foodPreference = value),
            ),
          ],
          if (_interests.contains(StudyInterest.notifications)) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.md),
            NotificationChoiceSection(
              selected: _notificationPreferences,
              onChanged: (value) =>
                  setState(() => _notificationPreferences = value),
            ),
          ],
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

class _ReadOnlyProfileValue extends StatelessWidget {
  const _ReadOnlyProfileValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(StudyOsSpacing.md),
      decoration: BoxDecoration(
        color: StudyOsColors.surfaceRaised,
        border: Border.all(color: StudyOsColors.border),
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: StudyOsColors.textMuted),
          const SizedBox(width: StudyOsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
