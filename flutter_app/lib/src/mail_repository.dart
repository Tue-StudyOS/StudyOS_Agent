import 'mail_client.dart';
import 'models.dart';
import 'profile_store.dart';

class MailRepository {
  factory MailRepository({
    ProfileStore? profileStore,
    MailClient Function()? clientFactory,
  }) {
    return MailRepository._(profileStore, clientFactory ?? MailClient.new);
  }

  MailRepository.test({MailClient Function()? clientFactory})
    : this._(null, clientFactory ?? MailClient.new);

  MailRepository._(this._profileStore, this._clientFactory);

  final ProfileStore? _profileStore;
  final MailClient Function() _clientFactory;

  Future<List<MailboxSummary>> listMailboxes(OnboardingProfile? profile) async {
    final client = await _authenticatedClient(profile);
    try {
      return await client.listMailboxes();
    } finally {
      client.close();
    }
  }

  Future<MailInboxSummary> fetchMailboxSummary(
    OnboardingProfile? profile, {
    String mailbox = 'INBOX',
    int limit = 12,
    bool unreadOnly = false,
    String query = '',
    String sender = '',
    String since = '',
    int scanLimit = 200,
  }) async {
    final client = await _authenticatedClient(profile);
    try {
      return await client.fetchMailboxSummary(
        mailbox: mailbox,
        limit: limit,
        unreadOnly: unreadOnly,
        query: query,
        sender: sender,
        since: since,
        scanLimit: scanLimit,
      );
    } finally {
      client.close();
    }
  }

  Future<MailMessageDetail> fetchMessageDetail(
    OnboardingProfile? profile, {
    required String uid,
    String mailbox = 'INBOX',
  }) async {
    final client = await _authenticatedClient(profile);
    try {
      return await client.fetchMessageDetail(uid, mailbox: mailbox);
    } finally {
      client.close();
    }
  }

  Future<MailClient> _authenticatedClient(OnboardingProfile? profile) async {
    if (profile == null) {
      throw const MailException('Sign in again to access university mail.');
    }
    final password = await (_profileStore ?? ProfileStore()).readPassword();
    if (password == null || password.isEmpty) {
      throw const MailException('Sign in again to access university mail.');
    }
    final client = _clientFactory();
    await client.login(profile.username, password);
    return client;
  }
}
