import 'package:flutter/material.dart';

import 'models.dart';
import 'onboarding_scaffold.dart';
import 'widgets/profile_form.dart';

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
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Confirm profile',
      subtitle: 'Personalize StudyOS',
      child: ProfileForm(
        session: widget.session,
        submitLabel: 'Start StudyOS',
        onSubmit: widget.onComplete,
      ),
    );
  }
}
