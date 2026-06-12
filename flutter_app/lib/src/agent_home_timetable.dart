part of 'agent_home_page.dart';

mixin _AgentHomeTimetable on State<AgentHomePage> {
  TimetableRepository get _timetableRepository;
  NativeBridge get _bridge;
  TimetableSnapshot? get _timetable;
  set _timetable(TimetableSnapshot? value);
  set _timetableError(String? value);
  set _worldState(Map<String, Object?> value);
  bool get _isRefreshingTimetable;
  set _isRefreshingTimetable(bool value);

  Future<void> _loadTimetable() async {
    final snapshot = await _timetableRepository.load();
    if (!mounted) return;
    setState(() => _timetable = snapshot);
    unawaited(_publishIntentSnapshot());
    if (snapshot == null || snapshot.isStale) {
      await _refreshTimetable();
    }
  }

  Future<void> _refreshTimetable() async {
    if (_isRefreshingTimetable) return;
    final profile = widget.profile;
    if (profile == null) {
      setState(
        () => _timetableError = 'Sign in again to refresh your timetable.',
      );
      return;
    }
    setState(() {
      _isRefreshingTimetable = true;
      _timetableError = null;
    });
    try {
      final snapshot = await _timetableRepository.refresh(profile);
      if (!mounted) return;
      final worldState = await _bridge.getWorldState();
      if (!mounted) return;
      setState(() {
        _timetable = snapshot;
        _worldState = withProfileContext(
          worldState,
          widget.profile,
          timetable: snapshot,
        );
      });
      unawaited(_publishIntentSnapshot());
    } on Object catch (error) {
      if (mounted) setState(() => _timetableError = error.toString());
    } finally {
      if (mounted) setState(() => _isRefreshingTimetable = false);
    }
  }

  Future<String> _readScheduleForAgent() async {
    var snapshot = _timetable;
    if (snapshot == null || snapshot.isStale) {
      await _refreshTimetable();
      snapshot = _timetable;
    }
    return snapshot?.compactSummary(limit: 12) ??
        'No timetable has been synced yet.';
  }

  Future<void> _publishIntentSnapshot();
}
