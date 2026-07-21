import 'private_study_models.dart' show safePortalTarget;

class AlmaStudyPlannerSemester {
  const AlmaStudyPlannerSemester({
    required this.index,
    required this.label,
    this.termLabel,
  });

  final int index;
  final String label;
  final String? termLabel;

  Map<String, Object?> toJson() => <String, Object?>{
    'index': index,
    'label': label,
    if (termLabel != null) 'termLabel': termLabel,
  };
}

class AlmaStudyPlannerModule {
  const AlmaStudyPlannerModule({
    required this.rowIndex,
    required this.columnStart,
    required this.columnSpan,
    required this.title,
    this.number,
    this.creditsSummary,
    this.creditsEarned,
    this.creditsRequired,
    this.progressPercent,
    this.detailUrl,
    this.isExpandable = false,
  });

  final int rowIndex;
  final int columnStart;
  final int columnSpan;
  final String title;
  final String? number;
  final String? creditsSummary;
  final double? creditsEarned;
  final double? creditsRequired;
  final double? progressPercent;
  final String? detailUrl;
  final bool isExpandable;

  Map<String, Object?> toJson() => <String, Object?>{
    'rowIndex': rowIndex,
    'columnStart': columnStart,
    'columnSpan': columnSpan,
    'title': title,
    if (number != null) 'number': number,
    if (creditsSummary != null) 'creditsSummary': creditsSummary,
    if (creditsEarned != null) 'creditsEarned': creditsEarned,
    if (creditsRequired != null) 'creditsRequired': creditsRequired,
    if (progressPercent != null) 'progressPercent': progressPercent,
    if (detailUrl != null) 'detailUrl': safePortalTarget(detailUrl!),
    'isExpandable': isExpandable,
  };
}

class AlmaStudyPlannerViewState {
  const AlmaStudyPlannerViewState({
    required this.showRecommendedPlan,
    required this.showMyModules,
    required this.showAlternativeSemesters,
  });

  final bool showRecommendedPlan;
  final bool showMyModules;
  final bool showAlternativeSemesters;

  Map<String, Object?> toJson() => <String, Object?>{
    'showRecommendedPlan': showRecommendedPlan,
    'showMyModules': showMyModules,
    'showAlternativeSemesters': showAlternativeSemesters,
  };
}

class AlmaStudyPlannerPage {
  const AlmaStudyPlannerPage({
    required this.title,
    required this.pageUrl,
    required this.semesters,
    required this.modules,
    required this.viewState,
  });

  final String title;
  final String pageUrl;
  final List<AlmaStudyPlannerSemester> semesters;
  final List<AlmaStudyPlannerModule> modules;
  final AlmaStudyPlannerViewState viewState;

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'pageUrl': safePortalTarget(pageUrl),
    'semesters': semesters.map((semester) => semester.toJson()).toList(),
    'modules': modules.map((module) => module.toJson()).toList(),
    'viewState': viewState.toJson(),
  };
}
