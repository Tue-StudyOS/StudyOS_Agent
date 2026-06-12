import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class ProfileStore {
  ProfileStore({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _profileKey = 'studyos.profile.v1';
  static const String _passwordKey = 'studyos.credentials.password.v1';

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secureStorage;

  Future<OnboardingProfile?> loadProfile() async {
    final encoded = await _preferences.getString(_profileKey);
    if (encoded == null || encoded.isEmpty) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) return null;
    return OnboardingProfile.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<void> saveProfile(OnboardingProfile profile) async {
    await _preferences.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<void> saveLogin({
    required UserSession session,
    required String password,
  }) async {
    if (password.isNotEmpty) {
      await _secureStorage.write(key: _passwordKey, value: password);
    }
  }

  Future<String?> readPassword() {
    return _secureStorage.read(key: _passwordKey);
  }

  Future<void> clear() async {
    await _preferences.remove(_profileKey);
    await _secureStorage.delete(key: _passwordKey);
  }
}
