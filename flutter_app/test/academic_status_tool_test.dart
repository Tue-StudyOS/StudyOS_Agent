import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:studyos_agent/src/academic_models.dart';
import 'package:studyos_agent/src/academic_repository.dart';
import 'package:studyos_agent/src/alma_academic_client.dart';
import 'package:studyos_agent/src/app_shell_controller.dart';
import 'package:studyos_agent/src/student_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const profile = OnboardingProfile(
    displayName: 'Ada',
    username: 'ada42',
    email: null,
    degreeProgram: 'M.Sc. AI',
    semester: 2,
    livesInTuebingen: true,
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  AppShellController controllerWith(AcademicRepository repository, {
    OnboardingProfile? initialProfile = profile,
  }) {
    final controller = AppShellController(
      initialProfile: initialProfile,
      initialOnLogout: null,
      initialOnSaveProfile: null,
      academicRepository: repository,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('surfaces the real error instead of the generic unavailable string', () async {
    final controller = controllerWith(
      _FakeAcademicRepository.throwing(
        const AlmaAcademicException('Sign in again to refresh your academic status.'),
      ),
    );

    final result = await controller.readAcademicStatusForAgent();

    expect(result, 'Sign in again to refresh your academic status.');
    expect(result, isNot(contains('not available')));
  });

  test('a concurrent background refresh no longer masks a fetch as unavailable', () async {
    // Reproduces the race: a refresh is already in flight (as initialize()
    // starts one) when the tool reader runs. It must await that fetch and
    // return the data, not a stale null snapshot.
    final repository = _FakeAcademicRepository.snapshot(
      _snapshotWith('Machine Learning'),
      delay: const Duration(milliseconds: 40),
    );
    final controller = controllerWith(repository);

    final inFlight = controller.refreshAcademicStatus(); // background refresh
    final result = await controller.readAcademicStatusForAgent();
    await inFlight;

    final decoded = jsonDecode(result) as Map<String, Object?>;
    final entries = decoded['entries'] as List<Object?>;
    expect(entries, hasLength(1));
    // Both callers shared one fetch rather than racing separate ones.
    expect(repository.refreshCalls, 1);
  });

  test('reports a clear message when no profile is signed in', () async {
    final controller = controllerWith(
      _FakeAcademicRepository.snapshot(_snapshotWith('X')),
      initialProfile: null,
    );

    final result = await controller.readAcademicStatusForAgent();

    expect(result, contains('no student profile'));
  });
}

AcademicStatusSnapshot _snapshotWith(String title) {
  return AcademicStatusSnapshot(
    term: 'WS 2026/27',
    refreshedAt: DateTime(2026, 7, 22),
    entries: <AcademicEntry>[
      AcademicEntry(category: 'Exams', title: title, status: 'Registered'),
    ],
  );
}

class _FakeAcademicRepository extends AcademicRepository {
  _FakeAcademicRepository.snapshot(this._snapshot, {this.delay = Duration.zero})
    : _error = null;
  _FakeAcademicRepository.throwing(this._error)
    : _snapshot = null,
      delay = Duration.zero;

  final AcademicStatusSnapshot? _snapshot;
  final Object? _error;
  final Duration delay;
  int refreshCalls = 0;

  @override
  Future<AcademicStatusSnapshot> refresh(
    OnboardingProfile profile, {
    PdfTextExtractor? extractPdfText,
  }) async {
    refreshCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (_error != null) throw _error;
    return _snapshot!;
  }
}
