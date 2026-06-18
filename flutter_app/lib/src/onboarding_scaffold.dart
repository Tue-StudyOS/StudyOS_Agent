import 'dart:ui';

import 'package:flutter/material.dart';

import 'studyos_theme.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.backgroundImageAsset,
    this.backgroundBlurSigma = 0,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? backgroundImageAsset;
  final double backgroundBlurSigma;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (backgroundImageAsset != null) ...<Widget>[
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: backgroundBlurSigma,
                sigmaY: backgroundBlurSigma,
              ),
              child: Transform.scale(
                scale: 1.03,
                child: Image.asset(backgroundImageAsset!, fit: BoxFit.cover),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(color: Color(0x99070A0F)),
            ),
          ],
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(StudyOsSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Material(
                    color: StudyOsColors.surface.withAlpha(240),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: StudyOsColors.border),
                      borderRadius: BorderRadius.circular(StudyOsRadii.lg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(StudyOsSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: StudyOsSpacing.xs),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: StudyOsSpacing.xl),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
