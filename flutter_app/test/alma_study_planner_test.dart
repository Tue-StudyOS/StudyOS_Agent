import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/alma_study_capability.dart';
import 'package:studyos_agent/src/alma_study_planner_client.dart';
import 'package:studyos_agent/src/alma_study_planner_models.dart';
import 'package:studyos_agent/src/alma_study_tools.dart';
import 'package:studyos_agent/src/capability_result.dart';
import 'package:studyos_agent/src/private_study_capabilities.dart';

const _plannerHtml = '''
<html><head><title>Studienplaner Master Informatik</title></head><body>
<table id="enrollTree:modulAnchors:modulAnchorsTable">
  <thead>
    <tr><th><div title="Studiensemester">1. Semester<br />WiSe 2025/26</div></th></tr>
  </thead>
  <tbody>
    <tr>
      <td>
        <div class="headerModulePlan">
          <div class="popupDismissable"><span title="INFO-FOKUS - Studienbereich Info Fokus">Info Fokus</span></div>
          <span title="CP erworben/soll">6/18</span>
        </div>
        <a href="/alma/pages/startFlow.xhtml?_flowId=detailView-flow&amp;moduleId=7">Details</a>
        <button name="enrollTree:modul:explodeModule">+</button>
      </td>
    </tr>
  </tbody>
</table>
<button name="planForm:switchMusterplan" class="submit_checkbox submit_checkbox_tick">Musterplan</button>
<button name="planForm:switchMeineModule" class="submit_checkbox">Meine Module</button>
</body></html>
''';

void main() {
  test('parseStudyPlannerPage extracts semesters, modules, and progress', () {
    final page = parseStudyPlannerPage(
      _plannerHtml,
      'https://alma.example/planner',
    );

    expect(page.title, 'Studienplaner Master Informatik');
    expect(page.semesters, hasLength(1));
    expect(page.semesters[0].label, '1. Semester');
    expect(page.semesters[0].termLabel, 'WiSe 2025/26');

    final module = page.modules.single;
    expect(module.number, 'INFO-FOKUS');
    expect(module.title, 'Studienbereich Info Fokus');
    expect(module.creditsEarned, 6.0);
    expect(module.creditsRequired, 18.0);
    expect(module.progressPercent, 33.3);
    expect(module.columnStart, 1);
    expect(module.columnSpan, 1);
    expect(module.isExpandable, isTrue);
    expect(module.detailUrl, endsWith('moduleId=7'));

    expect(page.viewState.showRecommendedPlan, isTrue);
    expect(page.viewState.showMyModules, isFalse);
    expect(page.viewState.showAlternativeSemesters, isFalse);
  });

  test('planner serialization sanitizes URLs and omits nothing sensitive', () {
    final page = parseStudyPlannerPage(
      _plannerHtml,
      'https://alma.example/planner',
    );
    final json = jsonEncode(page.toJson());

    expect(json, contains('"progressPercent":33.3'));
    expect(json, isNot(contains('password')));
    expect(json, isNot(contains('Cookie')));
  });

  test(
    'AlmaStudyCapability returns authenticationRequired without login',
    () async {
      final capability = AlmaStudyCapability(
        profileProvider: () => null,
        credentialsProvider: () async => null,
      );

      final result = await capability.studyPlanner();

      expect(result.state, CapabilityState.authenticationRequired);
      expect(result.data, isNull);
    },
  );

  test(
    'AlmaStudyCapability serves a fresh planner from injected credentials',
    () async {
      final capability = AlmaStudyCapability(
        profileProvider: () => null,
        credentialsProvider: () async =>
            const PortalCredentials('zxy123', 'secret'),
        plannerFetcher: (username, password) async =>
            parseStudyPlannerPage(_plannerHtml, 'https://alma.example/planner'),
      );

      final result = await capability.studyPlanner();

      expect(result.state, CapabilityState.fresh);
      expect(result.policy.privacy, CapabilityPrivacy.privateLocal);
      expect(result.data, isA<AlmaStudyPlannerPage>());
      expect(result.data!.modules.single.number, 'INFO-FOKUS');
    },
  );

  test('LiveAlmaStudyToolRunner rejects foreign tool names', () async {
    final runner = LiveAlmaStudyToolRunner(
      AlmaStudyCapability(profileProvider: () => null),
    );

    final response = await runner.execute('get_tasks', '{}');

    expect(response, contains('not available'));
  });
}
