class UserSession {
  const UserSession({
    required this.username,
    this.displayName,
    this.email,
    this.degreeProgram,
    this.profileWarning,
  });

  final String username;
  final String? displayName;
  final String? email;
  final String? degreeProgram;
  final String? profileWarning;

  String get suggestedDisplayName {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    final cleaned = username
        .split('@')
        .first
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(RegExp(r'\s+'))
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String? get displayEmail {
    if (email != null && email!.contains('@')) return email;
    return username.contains('@') ? username : null;
  }
}

enum StudyInterest {
  schedule,
  deadlines,
  mensa,
  studyPlanning,
  campusInfo,
  notifications,
}

enum FoodPreference { noPreference, vegetarian, vegan }

enum NotificationPreference { deadlineReminders, nextLecture, mensaUpdates }

class OnboardingProfile {
  const OnboardingProfile({
    required this.displayName,
    required this.username,
    required this.email,
    required this.degreeProgram,
    required this.semester,
    required this.livesInTuebingen,
    this.interests = const <StudyInterest>{},
    this.foodPreference = FoodPreference.noPreference,
    this.notificationPreferences = const <NotificationPreference>{},
  });

  final String displayName;
  final String username;
  final String? email;
  final String degreeProgram;
  final int? semester;
  final bool livesInTuebingen;
  final Set<StudyInterest> interests;
  final FoodPreference foodPreference;
  final Set<NotificationPreference> notificationPreferences;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'displayName': displayName,
      'username': username,
      'email': email,
      'degreeProgram': degreeProgram,
      'semester': semester,
      'livesInTuebingen': livesInTuebingen,
      'interests': interests.map((interest) => interest.name).toList(),
      'foodPreference': foodPreference.name,
      'notificationPreferences': notificationPreferences
          .map((preference) => preference.name)
          .toList(),
    };
  }

  static OnboardingProfile? fromJson(Map<String, Object?> json) {
    final displayName = json['displayName']?.toString().trim();
    final username = json['username']?.toString().trim();
    final degreeProgram = json['degreeProgram']?.toString().trim();
    if (displayName == null ||
        displayName.isEmpty ||
        username == null ||
        username.isEmpty ||
        degreeProgram == null ||
        degreeProgram.isEmpty) {
      return null;
    }

    final semesterValue = json['semester'];
    return OnboardingProfile(
      displayName: displayName,
      username: username,
      email: json['email']?.toString(),
      degreeProgram: degreeProgram,
      semester: semesterValue is int
          ? semesterValue
          : int.tryParse(semesterValue?.toString() ?? ''),
      livesInTuebingen: json['livesInTuebingen'] == true,
      interests: _decodeSet(json['interests'], StudyInterest.values),
      foodPreference: _decodeOne(
        json['foodPreference'],
        FoodPreference.values,
        FoodPreference.noPreference,
      ),
      notificationPreferences: _decodeSet(
        json['notificationPreferences'],
        NotificationPreference.values,
      ),
    );
  }
}

Set<T> _decodeSet<T extends Enum>(Object? value, List<T> values) {
  if (value is! List) return <T>{};
  return value
      .map((item) => _decodeNullable<T>(item, values))
      .whereType<T>()
      .toSet();
}

T _decodeOne<T extends Enum>(Object? value, List<T> values, T? fallback) {
  final decoded = _decodeNullable<T>(value, values);
  if (decoded != null) return decoded;
  return fallback ?? values.first;
}

T? _decodeNullable<T extends Enum>(Object? value, List<T> values) {
  final name = value?.toString();
  for (final item in values) {
    if (item.name == name) return item;
  }
  return null;
}

extension StudyInterestLabel on StudyInterest {
  String get label => switch (this) {
    StudyInterest.schedule => 'Schedule',
    StudyInterest.deadlines => 'Deadlines',
    StudyInterest.mensa => 'Mensa',
    StudyInterest.studyPlanning => 'Study planning',
    StudyInterest.campusInfo => 'Campus info',
    StudyInterest.notifications => 'Notifications',
  };
}

extension FoodPreferenceLabel on FoodPreference {
  String get label => switch (this) {
    FoodPreference.noPreference => 'No preference',
    FoodPreference.vegetarian => 'Vegetarian',
    FoodPreference.vegan => 'Vegan',
  };
}

extension NotificationPreferenceLabel on NotificationPreference {
  String get label => switch (this) {
    NotificationPreference.deadlineReminders => 'Deadline reminders',
    NotificationPreference.nextLecture => 'Next lecture',
    NotificationPreference.mensaUpdates => 'Mensa updates',
  };
}
