import 'portal_http_session.dart';
import 'private_study_models.dart';
import 'private_study_parsers.dart';

abstract interface class IliasStudySource {
  Future<List<PortalTask>> fetchTasks({required int limit});
  Future<List<PortalDeadline>> fetchDeadlines({required int scanLimit});
  void close();
}

abstract interface class MoodleStudySource {
  Future<List<PortalTask>> fetchEvents({required int days, required int limit});
  void close();
}

class IliasPortalClient implements IliasStudySource {
  IliasPortalClient({
    required this.username,
    required this.password,
    PortalHttpSession? session,
  }) : _session = session ?? PortalHttpSession();

  static final loginUri = Uri.parse(
    'https://ovidius.uni-tuebingen.de/login.php?cmd=force_login',
  );
  static final tasksUri = Uri.parse(
    'https://ovidius.uni-tuebingen.de/ilias.php?baseClass=ilderivedtasksgui',
  );

  final String username;
  final String password;
  final PortalHttpSession _session;
  bool _authenticated = false;

  @override
  Future<List<PortalTask>> fetchTasks({required int limit}) async {
    await _authenticate();
    final response = await _session.get(tasksUri);
    return parseIliasTasks(
      response.body,
      response.url,
    ).take(limit).toList(growable: false);
  }

  @override
  Future<List<PortalDeadline>> fetchDeadlines({required int scanLimit}) async {
    final tasks = await fetchTasks(limit: scanLimit);
    final deadlines = <PortalDeadline>[];
    final targets = tasks.map((task) => task.url).toSet().take(12);
    for (final target in targets) {
      final response = await _session.get(Uri.parse(target));
      deadlines.addAll(parseIliasAssignments(response.body, response.url));
    }
    return deadlines;
  }

  Future<void> _authenticate() async {
    if (_authenticated) return;
    final login = await _session.get(loginUri);
    final shibboleth = portalLink(login.body, login.url, 'shib_login.php');
    final idp = await _session.get(shibboleth);
    final form = portalForm(
      idp.body,
      idp.url,
      requiredFields: const <String>{'j_username', 'j_password'},
    );
    final submitted = await _session.postForm(
      PortalForm(
        action: form.action,
        payload: Map<String, String>.from(form.payload)
          ..['j_username'] = username
          ..['j_password'] = password
          ..putIfAbsent('_eventId_proceed', () => ''),
      ),
    );
    await completeSaml(
      submitted,
      _session,
      isAuthenticated: isAuthenticatedIliasPage,
    );
    _authenticated = true;
  }

  @override
  void close() => _session.close();
}

bool isAuthenticatedIliasPage(PortalResponse response) {
  if (response.url.host != 'ovidius.uni-tuebingen.de') return false;
  const loginOrHandoffMarkers = <String>[
    'SAMLResponse',
    'j_username',
    'j_password',
    'Login mit zentraler Universitäts-Kennung',
  ];
  if (loginOrHandoffMarkers.any(response.body.contains)) return false;
  const authenticatedMarkers = <String>[
    'ILIAS Universität Tübingen',
    'logout.php',
    'il-mainbar-entries',
    'il-maincontrols-metabar',
    'baseClass=ilDashboardGUI',
    'baseClass=ilmembershipoverviewgui',
    'baseClass=ilderivedtasksgui',
  ];
  return authenticatedMarkers.any(response.body.contains);
}

class MoodlePortalClient implements MoodleStudySource {
  MoodlePortalClient({
    required this.username,
    required this.password,
    PortalHttpSession? session,
    DateTime Function()? clock,
  }) : _session = session ?? PortalHttpSession(),
       _clock = clock ?? DateTime.now;

  static final baseUri = Uri.parse('https://moodle.zdv.uni-tuebingen.de/');

  final String username;
  final String password;
  final PortalHttpSession _session;
  final DateTime Function() _clock;
  bool _authenticated = false;

  @override
  Future<List<PortalTask>> fetchEvents({
    required int days,
    required int limit,
  }) async {
    await _authenticate();
    final dashboard = await _session.get(baseUri.resolve('my/'));
    if (dashboard.url.path.contains('/login/')) {
      throw const PortalAuthenticationException();
    }
    final sesskey = parseMoodleSesskey(dashboard.body);
    final now = _clock().toUtc();
    final payload = <Object?>[
      <String, Object?>{
        'index': 0,
        'methodname': 'core_calendar_get_action_events_by_timesort',
        'args': <String, Object?>{
          'limitnum': limit,
          'timesortfrom': now.millisecondsSinceEpoch ~/ 1000,
          'timesortto':
              now.add(Duration(days: days)).millisecondsSinceEpoch ~/ 1000,
          'limittononsuspendedevents': true,
        },
      },
    ];
    final response = await _session.postJson(
      baseUri.resolve(
        'lib/ajax/service.php?sesskey=${Uri.encodeQueryComponent(sesskey)}&info=core_calendar_get_action_events_by_timesort',
      ),
      payload,
      referer: dashboard.url,
    );
    return parseMoodleEvents(
      response.body,
      baseUri,
    ).take(limit).toList(growable: false);
  }

  Future<void> _authenticate() async {
    if (_authenticated) return;
    final login = await _session.get(baseUri.resolve('login/index.php'));
    final shibboleth = portalLink(
      login.body,
      login.url,
      '/auth/shibboleth/index.php',
    );
    final idp = await _session.get(shibboleth);
    final form = portalForm(
      idp.body,
      idp.url,
      requiredFields: const <String>{'j_username', 'j_password'},
    );
    final submitted = await _session.postForm(
      PortalForm(
        action: form.action,
        payload: Map<String, String>.from(form.payload)
          ..['j_username'] = username
          ..['j_password'] = password
          ..putIfAbsent('_eventId_proceed', () => ''),
      ),
    );
    await completeSaml(
      submitted,
      _session,
      isAuthenticated: (response) =>
          response.url.host == baseUri.host &&
          !response.url.path.contains('/login/') &&
          !response.url.path.contains('/auth/shibboleth/'),
    );
    _authenticated = true;
  }

  @override
  void close() => _session.close();
}
