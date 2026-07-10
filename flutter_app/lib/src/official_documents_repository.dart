import 'dart:typed_data';

import 'alma_documents_client.dart';
import 'alma_web_session.dart';
import 'official_document_models.dart';
import 'profile_store.dart';
import 'student_profile.dart';

class OfficialDocumentsRepository {
  OfficialDocumentsRepository({ProfileStore? profileStore})
    : _profileStore = profileStore ?? ProfileStore();

  final ProfileStore _profileStore;

  Future<List<OfficialDocument>> list(OnboardingProfile profile) async {
    final password = await _password();
    final client = AlmaDocumentsClient();
    try {
      return await client.list(username: profile.username, password: password);
    } finally {
      client.close();
    }
  }

  Future<Uint8List> download(
    OnboardingProfile profile,
    OfficialDocument document,
  ) async {
    final password = await _password();
    final client = AlmaDocumentsClient();
    try {
      return await client.download(
        username: profile.username,
        password: password,
        document: document,
      );
    } finally {
      client.close();
    }
  }

  Future<String> _password() async {
    final password = await _profileStore.readPassword();
    if (password == null || password.isEmpty) {
      throw const AlmaWebException(
        'Sign in again to access official documents.',
      );
    }
    return password;
  }
}
