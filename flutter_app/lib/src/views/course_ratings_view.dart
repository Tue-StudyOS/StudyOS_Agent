import 'dart:async';

import 'package:flutter/material.dart';

import '../academic_models.dart';
import '../course_catalog_client.dart';
import '../course_catalog_models.dart';
import '../studyos_theme.dart';
import '../widgets/feedback_settings_card.dart';

class CourseRatingsView extends StatefulWidget {
  const CourseRatingsView({
    required this.academicStatus,
    this.catalogClient,
    super.key,
  });

  final AcademicStatusSnapshot? academicStatus;
  final CourseCatalogClient? catalogClient;

  @override
  State<CourseRatingsView> createState() => _CourseRatingsViewState();
}

class _CourseRatingsViewState extends State<CourseRatingsView> {
  late final TextEditingController _searchController;
  late final CourseCatalogClient _catalogClient;
  Timer? _debounce;
  List<CourseCatalogEntry> _courses = const <CourseCatalogEntry>[];
  CourseCatalogEntry? _selected;
  String? _error;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _catalogClient = widget.catalogClient ?? CourseCatalogClient();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _queueSearch(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (mounted) {
        setState(() {
          _courses = const <CourseCatalogEntry>[];
          _error = null;
          _isSearching = false;
          _selected = null;
        });
      }
      return;
    }
    setState(() {
      _isSearching = true;
      _error = null;
      _selected = null;
    });
    try {
      final courses = await _catalogClient.search(trimmed);
      if (!mounted || _searchController.text.trim() != trimmed) return;
      setState(() => _courses = courses);
    } on CourseCatalogException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted && _searchController.text.trim() == trimmed) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _searchFor(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    _search(query);
  }

  List<String> get _myCourseQueries {
    final seen = <String>{};
    return (widget.academicStatus?.entries ?? const <AcademicEntry>[])
        .map((entry) => entry.title.trim())
        .where((title) => title.length >= 2 && seen.add(title.toLowerCase()))
        .take(6)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final myCourses = _myCourseQueries;
    return ListView(
      padding: const EdgeInsets.only(
        top: StudyOsSpacing.xl,
        bottom: StudyOsSpacing.xxl,
      ),
      children: <Widget>[
        Text(
          'Course ratings',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: StudyOsSpacing.xs),
        Text(
          'Find a course in the shared StudyPlanner catalog, then read or add a community rating.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (myCourses.isNotEmpty) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.lg),
          Text('MY COURSES', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: StudyOsSpacing.sm),
          Wrap(
            spacing: StudyOsSpacing.sm,
            runSpacing: StudyOsSpacing.sm,
            children: myCourses
                .map(
                  (title) => ActionChip(
                    avatar: const Icon(Icons.school_outlined, size: 18),
                    label: Text(title, overflow: TextOverflow.ellipsis),
                    onPressed: () => _searchFor(title),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        const SizedBox(height: StudyOsSpacing.lg),
        TextField(
          controller: _searchController,
          onChanged: _queueSearch,
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Search the course catalog',
            hintText: 'Course title or number',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.sm),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (!_isSearching &&
            _error == null &&
            _searchController.text.trim().length >= 2 &&
            _courses.isEmpty) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.lg),
          const Text('No matching courses found.'),
        ],
        if (_courses.isNotEmpty) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.lg),
          ..._courses.map(
            (course) => Card(
              child: ListTile(
                title: Text(course.title),
                subtitle: Text(
                  <String>[
                    course.courseNumber,
                    if (course.periodLabel.isNotEmpty) course.periodLabel,
                    if (course.ects != null)
                      '${course.ects!.toStringAsCompact()} ECTS',
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => setState(() => _selected = course),
              ),
            ),
          ),
        ],
        if (_selected != null) ...<Widget>[
          const Divider(height: StudyOsSpacing.xxl),
          CourseFeedbackCard(
            key: ValueKey<String>(_selected!.ratingCourseId),
            course: _selected!,
          ),
        ],
        const SizedBox(height: StudyOsSpacing.lg),
        Text(
          'Your enrollment list stays on this device. Choosing a shortcut sends that course title to this service and the public StudyPlanner catalog as a search. Ratings are pseudonymous community feedback, not verified enrollment reviews.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

extension on double {
  String toStringAsCompact() =>
      this == roundToDouble() ? toInt().toString() : toStringAsFixed(1);
}
