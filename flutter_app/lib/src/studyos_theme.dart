import 'package:flutter/material.dart';

abstract final class StudyOsColors {
  static const Color background = Color(0xFFF5F5F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceRaised = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E5EA);
  static const Color separator = Color(0xFFC6C6C8);
  static const Color text = Color(0xFF1D1D1F);
  static const Color textMuted = Color(0xFF6E6E73);
  static const Color accent = Color(0xFF007AFF);
  static const Color accentStrong = Color(0xFF0066D6);
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color destructive = Color(0xFFFF3B30);
}

abstract final class StudyOsSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class StudyOsRadii {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
}

ThemeData buildStudyOsTheme() {
  const scheme = ColorScheme.light(
    primary: StudyOsColors.accent,
    onPrimary: Colors.white,
    surface: StudyOsColors.surface,
    onSurface: StudyOsColors.text,
    error: StudyOsColors.destructive,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: StudyOsColors.background,
    fontFamily: 'SF Pro Text',
    useMaterial3: true,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: StudyOsColors.text,
        fontSize: 34,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      titleMedium: TextStyle(
        color: StudyOsColors.text,
        fontSize: 17,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      bodyLarge: TextStyle(
        color: StudyOsColors.text,
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        color: StudyOsColors.textMuted,
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: TextStyle(
        color: StudyOsColors.text,
        fontSize: 15,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: StudyOsColors.border,
      thickness: 0.5,
      space: 1,
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: StudyOsColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: StudyOsSpacing.md,
        vertical: StudyOsSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StudyOsRadii.sm),
        borderSide: const BorderSide(color: StudyOsColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StudyOsRadii.sm),
        borderSide: const BorderSide(color: StudyOsColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StudyOsRadii.sm),
        borderSide: const BorderSide(color: StudyOsColors.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: StudyOsColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StudyOsRadii.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: StudyOsColors.text,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
      ),
    ),
  );
}
