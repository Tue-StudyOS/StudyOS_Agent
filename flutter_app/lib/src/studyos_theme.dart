import 'package:flutter/material.dart';

abstract final class StudyOsColors {
  static const Color background = Color(0xFF070A0F);
  static const Color surface = Color(0xFF111821);
  static const Color surfaceRaised = Color(0xFF17212D);
  static const Color border = Color(0xFF253142);
  static const Color text = Color(0xFFF3F6FA);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color accent = Color(0xFF5EA8FF);
  static const Color accentStrong = Color(0xFF2F80ED);
  static const Color success = Color(0xFF3DDC97);
  static const Color warning = Color(0xFFF4B860);
}

abstract final class StudyOsSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

abstract final class StudyOsRadii {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 18;
}

ThemeData buildStudyOsTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: StudyOsColors.accent,
    brightness: Brightness.dark,
    surface: StudyOsColors.surface,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: StudyOsColors.background,
    fontFamily: 'SF Pro Text',
    useMaterial3: true,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: StudyOsColors.text,
        fontSize: 24,
        height: 1.15,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: StudyOsColors.text,
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        color: StudyOsColors.text,
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        color: StudyOsColors.textMuted,
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: TextStyle(
        color: StudyOsColors.text,
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
