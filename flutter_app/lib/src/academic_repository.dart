import 'dart:typed_data';

import 'academic_models.dart';
import 'alma_academic_client.dart';
import 'profile_store.dart';
import 'student_profile.dart';

class AcademicRepository {
  AcademicRepository({ProfileStore? profileStore})
    : _profileStore = profileStore ?? ProfileStore();

  final ProfileStore _profileStore;

  Future<AcademicStatusSnapshot> refresh(
    OnboardingProfile profile, {
    PdfTextExtractor? extractPdfText,
  }) async {
    final password = await _profileStore.readPassword();
    if (password == null || password.isEmpty) {
      throw const AlmaAcademicException(
        'Sign in again to refresh your academic status.',
      );
    }
    final client = AlmaAcademicClient(pdfTextExtractor: extractPdfText);
    try {
      return await client.fetch(username: profile.username, password: password);
    } finally {
      client.close();
    }
  }

  Future<Uint8List> downloadRegistrationReport(
    OnboardingProfile profile,
  ) async {
    final password = await _profileStore.readPassword();
    if (password == null || password.isEmpty) {
      throw const AlmaAcademicException(
        'Sign in again to open your registration report.',
      );
    }
    final client = AlmaAcademicClient();
    try {
      return await client.downloadRegistrationReport(
        username: profile.username,
        password: password,
      );
    } finally {
      client.close();
    }
  }
}
