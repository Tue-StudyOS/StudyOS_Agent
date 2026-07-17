import 'capability_result.dart';
import 'private_study_clients.dart';
import 'private_study_models.dart';
import 'profile_store.dart';
import 'student_profile.dart';

typedef IliasSourceFactory =
    IliasStudySource Function(String username, String password);
typedef MoodleSourceFactory =
    MoodleStudySource Function(String username, String password);
typedef PortalCredentialsProvider = Future<PortalCredentials?> Function();

class PortalCredentials {
  const PortalCredentials(this.username, this.password);
  final String username;
  final String password;
}

class PrivateStudyCapability {
  PrivateStudyCapability({
    required this.profileProvider,
    this.profileStore,
    IliasSourceFactory? iliasFactory,
    MoodleSourceFactory? moodleFactory,
    this.credentialsProvider,
    DateTime Function()? clock,
    this.ttl = const Duration(minutes: 10),
    this.sourceTimeout = const Duration(seconds: 45),
  }) : _iliasFactory =
           iliasFactory ??
           ((username, password) =>
               IliasPortalClient(username: username, password: password)),
       _moodleFactory =
           moodleFactory ??
           ((username, password) =>
               MoodlePortalClient(username: username, password: password)),
       _clock = clock ?? DateTime.now;

  static final source = CapabilitySource(
    id: 'local_university_portals',
    label: 'Local ILIAS and Moodle sessions',
    url: 'https://uni-tuebingen.de/',
    reliability: 'authenticated_live',
  );

  final OnboardingProfile? Function() profileProvider;
  final ProfileStore? profileStore;
  final IliasSourceFactory _iliasFactory;
  final MoodleSourceFactory _moodleFactory;
  final PortalCredentialsProvider? credentialsProvider;
  final DateTime Function() _clock;
  final Duration ttl;
  final Duration sourceTimeout;
  final Map<String, _PrivateCacheEntry<Object>> _cache = {};

  Future<CapabilityResult<List<PortalTask>>> tasks({
    required Set<StudyPortalSource> sources,
    required int limit,
  }) async {
    final key = 'tasks:${_sourceKey(sources)}:$limit';
    final cached = _cached<List<PortalTask>>(key);
    if (cached != null) return cached;
    final credentials = await _credentials();
    if (credentials == null) return _authenticationRequired<List<PortalTask>>();

    final data = <PortalTask>[];
    final failures = <CapabilityFailure>[];
    if (sources.contains(StudyPortalSource.ilias)) {
      final client = _iliasFactory(credentials.username, credentials.password);
      try {
        data.addAll(await client.fetchTasks(limit: 50).timeout(sourceTimeout));
      } on Object catch (error) {
        failures.add(_failure(StudyPortalSource.ilias, error));
      } finally {
        client.close();
      }
    }
    if (sources.contains(StudyPortalSource.moodle)) {
      final client = _moodleFactory(credentials.username, credentials.password);
      try {
        data.addAll(
          await client.fetchEvents(days: 180, limit: 50).timeout(sourceTimeout),
        );
      } on Object catch (error) {
        failures.add(_failure(StudyPortalSource.moodle, error));
      } finally {
        client.close();
      }
    }
    data.sort(_compareTasks);
    final result = _result(data.take(limit).toList(growable: false), failures);
    return _store(key, _staleIfFailed(key, result) ?? result);
  }

  Future<CapabilityResult<List<PortalDeadline>>> deadlines({
    required Set<StudyPortalSource> sources,
    required int days,
    required int limit,
  }) async {
    final key = 'deadlines:${_sourceKey(sources)}:$days:$limit';
    final cached = _cached<List<PortalDeadline>>(key);
    if (cached != null) return cached;
    final credentials = await _credentials();
    if (credentials == null) {
      return _authenticationRequired<List<PortalDeadline>>();
    }
    final now = _clock();
    final end = now.add(Duration(days: days));
    final data = <PortalDeadline>[];
    final failures = <CapabilityFailure>[];
    if (sources.contains(StudyPortalSource.ilias)) {
      final client = _iliasFactory(credentials.username, credentials.password);
      try {
        data.addAll(
          await client.fetchDeadlines(scanLimit: 50).timeout(sourceTimeout),
        );
      } on Object catch (error) {
        failures.add(_failure(StudyPortalSource.ilias, error));
      } finally {
        client.close();
      }
    }
    if (sources.contains(StudyPortalSource.moodle)) {
      final client = _moodleFactory(credentials.username, credentials.password);
      try {
        final events = await client
            .fetchEvents(days: days, limit: limit)
            .timeout(sourceTimeout);
        data.addAll(
          events
              .where((event) => event.dueAt != null)
              .map(
                (event) => PortalDeadline(
                  source: event.source,
                  id: event.id,
                  title: event.title,
                  dueAt: event.dueAt!,
                  url: event.url,
                  courseTitle: event.courseTitle,
                  dueHint: event.rawDueHint,
                  status: event.status,
                ),
              ),
        );
      } on Object catch (error) {
        failures.add(_failure(StudyPortalSource.moodle, error));
      } finally {
        client.close();
      }
    }
    final deduplicated = <String, PortalDeadline>{};
    for (final item in data) {
      if (item.dueAt.isBefore(now) || item.dueAt.isAfter(end)) continue;
      deduplicated[item.deduplicationKey] = item;
    }
    final bounded = deduplicated.values.toList()
      ..sort((first, second) => first.dueAt.compareTo(second.dueAt));
    final result = _result(
      bounded.take(limit).toList(growable: false),
      failures,
    );
    return _store(key, _staleIfFailed(key, result) ?? result);
  }

  void invalidate() => _cache.clear();

  CapabilityResult<T>? _cached<T>(String key) {
    final entry = _cache[key];
    if (entry == null || !_clock().isBefore(entry.expiresAt)) return null;
    return entry.result as CapabilityResult<T>;
  }

  CapabilityResult<T> _store<T>(String key, CapabilityResult<T> result) {
    _cache[key] = _PrivateCacheEntry<Object>(
      result as CapabilityResult<Object>,
      expiresAt: result.expiresAt ?? _clock().add(ttl),
    );
    return result;
  }

  CapabilityResult<T>? _staleIfFailed<T>(
    String key,
    CapabilityResult<T> result,
  ) {
    if (result.state != CapabilityState.failed) return null;
    final previous = _cache[key]?.result;
    if (previous == null) return null;
    final cached = previous as CapabilityResult<T>;
    return CapabilityResult<T>(
      state: CapabilityState.stale,
      policy: cached.policy,
      source: cached.source,
      fetchedAt: cached.fetchedAt,
      expiresAt: cached.expiresAt,
      data: cached.data,
      message: 'Live refresh failed; returning locally cached portal data.',
      failures: result.failures,
    );
  }

  CapabilityResult<List<T>> _result<T>(
    List<T> data,
    List<CapabilityFailure> failures,
  ) {
    final now = _clock();
    final allFailed = failures.isNotEmpty && data.isEmpty;
    final authenticationFailed =
        failures.isNotEmpty &&
        failures.every((failure) => failure.message.contains('authentication'));
    return CapabilityResult<List<T>>(
      state: authenticationFailed
          ? CapabilityState.authenticationRequired
          : allFailed
          ? CapabilityState.failed
          : data.isEmpty
          ? CapabilityState.empty
          : CapabilityState.fresh,
      policy: CapabilityPolicy.privateRead,
      source: source,
      fetchedAt: now,
      expiresAt: now.add(ttl),
      data: data,
      failures: failures,
      message: failures.isEmpty ? null : _failureSummary(failures),
    );
  }

  CapabilityResult<T> _authenticationRequired<T>() => CapabilityResult<T>(
    state: CapabilityState.authenticationRequired,
    policy: CapabilityPolicy.privateRead,
    source: source,
    fetchedAt: _clock(),
    message: 'Sign in locally to access university portal data.',
  );

  Future<PortalCredentials?> _credentials() async {
    final injected = credentialsProvider;
    if (injected != null) return injected();
    final profile = profileProvider();
    if (profile == null || profile.username.trim().isEmpty) return null;
    final password = await (profileStore ?? ProfileStore()).readPassword();
    if (password == null || password.isEmpty) return null;
    return PortalCredentials(profile.username, password);
  }
}

class _PrivateCacheEntry<T> {
  const _PrivateCacheEntry(this.result, {required this.expiresAt});
  final CapabilityResult<T> result;
  final DateTime expiresAt;
}

CapabilityFailure _failure(
  StudyPortalSource source,
  Object error,
) => CapabilityFailure(
  source: source.name,
  message: error is PortalAuthenticationException
      ? 'authentication required: ${boundedCapabilityMessage(error.message)}'
      : boundedCapabilityMessage(error),
);

String _failureSummary(List<CapabilityFailure> failures) {
  final details = failures
      .map((failure) => '${failure.source}: ${failure.message}')
      .join('; ');
  return boundedCapabilityMessage(
    'Some requested portal sources failed: $details',
    maxLength: 520,
  );
}

String _sourceKey(Set<StudyPortalSource> sources) =>
    (sources.toList()..sort((a, b) => a.index.compareTo(b.index)))
        .map((source) => source.name)
        .join(',');

int _compareTasks(PortalTask first, PortalTask second) {
  if (first.dueAt == null && second.dueAt != null) return 1;
  if (first.dueAt != null && second.dueAt == null) return -1;
  return (first.dueAt ?? DateTime(9999)).compareTo(
    second.dueAt ?? DateTime(9999),
  );
}
