import 'dart:convert';

import 'alma_study_capability.dart';
import 'private_study_tools.dart';

const getStudyPlannerToolName = 'get_study_planner';

/// Serves the read-only ALMA study planner through the shared private-study
/// tool interface so it routes exactly like `get_tasks`/`get_deadlines`.
class LiveAlmaStudyToolRunner implements PrivateStudyToolRunner {
  LiveAlmaStudyToolRunner(this._capability);

  final AlmaStudyCapability _capability;

  @override
  Future<String> execute(String toolName, String arguments) async {
    if (toolName != getStudyPlannerToolName) {
      return jsonEncode(<String, Object?>{
        'error': 'ALMA study tool is not available: $toolName',
      });
    }
    final result = await _capability.studyPlanner();
    return jsonEncode(result.toJson((page) => page.toJson()));
  }

  @override
  void invalidate() => _capability.invalidate();
}

/// Routes private study tools to the portal (ILIAS/Moodle) runner and the ALMA
/// study planner to its own runner behind one [PrivateStudyToolRunner].
class CombinedPrivateStudyToolRunner implements PrivateStudyToolRunner {
  const CombinedPrivateStudyToolRunner({
    required this.portal,
    required this.alma,
  });

  final PrivateStudyToolRunner portal;
  final PrivateStudyToolRunner alma;

  @override
  Future<String> execute(String toolName, String arguments) {
    if (toolName == getStudyPlannerToolName) {
      return alma.execute(toolName, arguments);
    }
    return portal.execute(toolName, arguments);
  }

  @override
  void invalidate() {
    portal.invalidate();
    alma.invalidate();
  }
}
