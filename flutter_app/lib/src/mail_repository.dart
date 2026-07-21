import 'mail_client.dart';
import 'models.dart';
import 'profile_store.dart';

class MailRepository {
  factory MailRepository({
    ProfileStore? profileStore,
    MailClient Function()? clientFactory,
    Duration cacheTtl = const Duration(minutes: 2),
  }) {
    return MailRepository._(
      profileStore,
      clientFactory ?? MailClient.new,
      cacheTtl,
    );
  }

  MailRepository.test({
    ProfileStore? profileStore,
    MailClient Function()? clientFactory,
    Duration cacheTtl = const Duration(minutes: 2),
  }) : this._(profileStore, clientFactory ?? MailClient.new, cacheTtl);

  MailRepository._(this._profileStore, this._clientFactory, this.cacheTtl);

  final ProfileStore? _profileStore;
  final MailClient Function() _clientFactory;
  final Duration cacheTtl;
  final Map<String, _MailCacheEntry<Object>> _cache =
      <String, _MailCacheEntry<Object>>{};

  Future<List<MailboxSummary>> listMailboxes(
    OnboardingProfile? profile, {
    bool forceRefresh = false,
  }) async {
    await _ensureMailAccessAllowed(profile);
    final account = _accountKey(profile);
    return _cached<List<MailboxSummary>>(
      'mailboxes|$account',
      forceRefresh: forceRefresh,
      loader: () async {
        final client = await _authenticatedClient(profile);
        try {
          return await client.listMailboxes();
        } finally {
          client.close();
        }
      },
    );
  }

  Future<List<MailboxSummary>> _fetchMailboxesWithoutCache(
    MailClient client,
    String account,
  ) async {
    final mailboxes = await client.listMailboxes();
    _cache['mailboxes|$account'] = _MailCacheEntry<Object>(mailboxes);
    return mailboxes;
  }

  Future<MailInboxSummary> _fetchSummaryWithoutCache(
    MailClient client,
    String account, {
    required String mailbox,
    required int limit,
    required bool unreadOnly,
    required String query,
    required String sender,
    required String since,
    required int scanLimit,
  }) async {
    final summary = await client.fetchMailboxSummary(
      mailbox: mailbox,
      limit: limit,
      unreadOnly: unreadOnly,
      query: query,
      sender: sender,
      since: since,
      scanLimit: scanLimit,
    );
    _cache[_summaryKey(
      account: account,
      mailbox: mailbox,
      limit: limit,
      unreadOnly: unreadOnly,
      query: query,
      sender: sender,
      since: since,
      scanLimit: scanLimit,
    )] = _MailCacheEntry<Object>(
      summary,
    );
    return summary;
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
    bool forceRefresh = false,
  }) async {
    await _ensureMailAccessAllowed(profile);
    final account = _accountKey(profile);
    final key = _summaryKey(
      account: account,
      mailbox: mailbox,
      limit: limit,
      unreadOnly: unreadOnly,
      query: query,
      sender: sender,
      since: since,
      scanLimit: scanLimit,
    );
    return _cached<MailInboxSummary>(
      key,
      forceRefresh: forceRefresh,
      loader: () async {
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
      },
    );
  }

  Future<MailMailboxSnapshot> fetchMailboxSnapshot(
    OnboardingProfile? profile, {
    String mailbox = 'INBOX',
    int limit = 12,
    bool unreadOnly = false,
    String query = '',
    String sender = '',
    String since = '',
    int scanLimit = 200,
    bool forceRefresh = false,
  }) async {
    await _ensureMailAccessAllowed(profile);
    final account = _accountKey(profile);
    final key =
        'snapshot|${_summaryKey(account: account, mailbox: mailbox, limit: limit, unreadOnly: unreadOnly, query: query, sender: sender, since: since, scanLimit: scanLimit)}';
    return _cached<MailMailboxSnapshot>(
      key,
      forceRefresh: forceRefresh,
      loader: () async {
        final client = await _authenticatedClient(profile);
        try {
          final mailboxes = await _fetchMailboxesWithoutCache(client, account);
          final inbox = await _fetchSummaryWithoutCache(
            client,
            account,
            mailbox: mailbox,
            limit: limit,
            unreadOnly: unreadOnly,
            query: query,
            sender: sender,
            since: since,
            scanLimit: scanLimit,
          );
          return MailMailboxSnapshot(mailboxes: mailboxes, inbox: inbox);
        } finally {
          client.close();
        }
      },
    );
  }

  Future<MailMessageDetail> fetchMessageDetail(
    OnboardingProfile? profile, {
    required String uid,
    String mailbox = 'INBOX',
    bool forceRefresh = false,
  }) async {
    await _ensureMailAccessAllowed(profile);
    final account = _accountKey(profile);
    return _cached<MailMessageDetail>(
      'detail|$account|$mailbox|$uid',
      forceRefresh: forceRefresh,
      loader: () async {
        final client = await _authenticatedClient(profile);
        try {
          return await client.fetchMessageDetail(uid, mailbox: mailbox);
        } finally {
          client.close();
        }
      },
    );
  }

  void clearCache() {
    _cache.clear();
  }

  Future<MailClient> _authenticatedClient(OnboardingProfile? profile) async {
    await _ensureMailAccessAllowed(profile);
    final password = await (_profileStore ?? ProfileStore()).readPassword();
    final client = _clientFactory();
    await client.login(profile!.username, password!);
    return client;
  }

  Future<void> _ensureMailAccessAllowed(OnboardingProfile? profile) async {
    if (profile == null) {
      throw const MailException('Sign in again to access university mail.');
    }
    final password = await (_profileStore ?? ProfileStore()).readPassword();
    if (password == null || password.isEmpty) {
      throw const MailException('Sign in again to access university mail.');
    }
  }

  String _accountKey(OnboardingProfile? profile) {
    return profile?.username.trim().toLowerCase() ?? 'anonymous';
  }

  String _summaryKey({
    required String account,
    required String mailbox,
    required int limit,
    required bool unreadOnly,
    required String query,
    required String sender,
    required String since,
    required int scanLimit,
  }) {
    return <Object>[
      'summary',
      account,
      mailbox,
      limit,
      unreadOnly,
      query.trim().toLowerCase(),
      sender.trim().toLowerCase(),
      since.trim(),
      scanLimit,
    ].join('|');
  }

  Future<T> _cached<T extends Object>(
    String key, {
    required bool forceRefresh,
    required Future<T> Function() loader,
  }) async {
    if (!forceRefresh) {
      final cached = _cache[key];
      if (cached != null && !cached.isExpired(cacheTtl)) {
        return cached.value as T;
      }
    }
    final value = await loader();
    _cache[key] = _MailCacheEntry<Object>(value);
    return value;
  }
}

class _MailCacheEntry<T extends Object> {
  _MailCacheEntry(this.value) : createdAt = DateTime.now();

  final T value;
  final DateTime createdAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(createdAt) > ttl;
}
