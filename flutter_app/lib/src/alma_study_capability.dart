import 'alma_study_planner_client.dart';
import 'alma_study_planner_models.dart';
import 'alma_web_session.dart';
import 'capability_result.dart';
import 'private_study_capabilities.dart' show PortalCredentials;
import 'profile_store.dart';
import 'student_profile.dart';

typedef StudyPlannerFetcher =
    Future<AlmaStudyPlannerPage> Function(String username, String password);
typedef AlmaCredentialsProvider = Future<PortalCredentials?> Function();

class AlmaStudyCapability {
  AlmaStudyCapability({
    required this.profileProvider,
    this.profileStore,
    this.credentialsProvider,
    StudyPlannerFetcher? plannerFetcher,
    DateTime Function()? clock,
    this.ttl = const Duration(minutes: 30),
    this.timeout = const Duration(seconds: 45),
  }) : _plannerFetcher = plannerFetcher ?? _defaultPlannerFetcher,
       _clock = clock ?? DateTime.now;

  static final source = CapabilitySource(
    id: 'local_alma_session',
    label: 'Local ALMA study planner',
    url: 'https://alma.uni-tuebingen.de/',
    reliability: 'authenticated_live',
  );

  final OnboardingProfile? Function() profileProvider;
  final ProfileStore? profileStore;
  final AlmaCredentialsProvider? credentialsProvider;
  final StudyPlannerFetcher _plannerFetcher;
  final DateTime Function() _clock;
  final Duration ttl;
  final Duration timeout;
  CapabilityResult<AlmaStudyPlannerPage>? _cache;

  Future<CapabilityResult<AlmaStudyPlannerPage>> studyPlanner() async {
    final cached = _cache;
    if (cached != null &&
        cached.expiresAt != null &&
        _clock().isBefore(cached.expiresAt!)) {
      return cached;
    }
    final credentials = await _credentials();
    if (credentials == null) return _authenticationRequired();
    try {
      final page = await _plannerFetcher(
        credentials.username,
        credentials.password,
      ).timeout(timeout);
      return _store(_fresh(page));
    } on Object catch (error) {
      if (_looksLikeAuthFailure(error)) {
        return _authenticationRequired(
          message: boundedCapabilityMessage(error),
        );
      }
      final stale = _staleIfPossible(error);
      if (stale != null) return _store(stale);
      return _failed(error);
    }
  }

  void invalidate() => _cache = null;

  CapabilityResult<AlmaStudyPlannerPage> _fresh(AlmaStudyPlannerPage page) {
    final now = _clock();
    return CapabilityResult<AlmaStudyPlannerPage>(
      state: page.modules.isEmpty && page.semesters.isEmpty
          ? CapabilityState.empty
          : CapabilityState.fresh,
      policy: CapabilityPolicy.privateRead,
      source: source,
      fetchedAt: now,
      expiresAt: now.add(ttl),
      data: page,
    );
  }

  CapabilityResult<AlmaStudyPlannerPage> _store(
    CapabilityResult<AlmaStudyPlannerPage> result,
  ) {
    _cache = result;
    return result;
  }

  CapabilityResult<AlmaStudyPlannerPage>? _staleIfPossible(Object error) {
    final previous = _cache;
    if (previous == null || previous.data == null) return null;
    return CapabilityResult<AlmaStudyPlannerPage>(
      state: CapabilityState.stale,
      policy: CapabilityPolicy.privateRead,
      source: source,
      fetchedAt: previous.fetchedAt,
      expiresAt: previous.expiresAt,
      data: previous.data,
      message: 'Live refresh failed; returning the cached study planner.',
      failures: <CapabilityFailure>[
        CapabilityFailure(
          source: source.id,
          message: boundedCapabilityMessage(error),
        ),
      ],
    );
  }

  CapabilityResult<AlmaStudyPlannerPage> _failed(Object error) =>
      CapabilityResult<AlmaStudyPlannerPage>(
        state: CapabilityState.failed,
        policy: CapabilityPolicy.privateRead,
        source: source,
        fetchedAt: _clock(),
        message: boundedCapabilityMessage(error),
        failures: <CapabilityFailure>[
          CapabilityFailure(
            source: source.id,
            message: boundedCapabilityMessage(error),
          ),
        ],
      );

  CapabilityResult<AlmaStudyPlannerPage> _authenticationRequired({
    String? message,
  }) => CapabilityResult<AlmaStudyPlannerPage>(
    state: CapabilityState.authenticationRequired,
    policy: CapabilityPolicy.privateRead,
    source: source,
    fetchedAt: _clock(),
    message: message ?? 'Sign in locally to access your ALMA study planner.',
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

bool _looksLikeAuthFailure(Object error) {
  if (error is! AlmaWebException) return false;
  final message = error.message.toLowerCase();
  return message.contains('login') ||
      message.contains('session expired') ||
      message.contains('authenticat');
}

Future<AlmaStudyPlannerPage> _defaultPlannerFetcher(
  String username,
  String password,
) async {
  final client = AlmaStudyPlannerClient();
  try {
    return await client.fetch(username: username, password: password);
  } finally {
    client.close();
  }
}
