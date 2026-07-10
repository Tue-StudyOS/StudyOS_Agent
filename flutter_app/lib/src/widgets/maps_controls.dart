import 'package:flutter/material.dart';

import '../map_location_models.dart';
import '../studyos_theme.dart';

class MapSearchBar extends StatelessWidget {
  const MapSearchBar({
    required this.controller,
    required this.isSearching,
    required this.onSearch,
    super.key,
  });

  final TextEditingController controller;
  final bool isSearching;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSearch(),
      decoration: InputDecoration(
        filled: true,
        fillColor: StudyOsColors.surface.withValues(alpha: 0.96),
        hintText: 'Where to?',
        prefixIcon: const Icon(Icons.search_rounded),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: StudyOsSpacing.lg,
          vertical: StudyOsSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: StudyOsColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: StudyOsColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: StudyOsColors.accent),
        ),
        suffixIcon: IconButton(
          tooltip: 'Search destination',
          onPressed: isSearching ? null : onSearch,
          icon: isSearching
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_rounded),
        ),
      ),
    );
  }
}

class MapOverlay extends StatelessWidget {
  const MapOverlay({
    required this.controller,
    required this.results,
    required this.selectedLocation,
    required this.isSearching,
    required this.searchError,
    required this.hasSearched,
    required this.onSearch,
    required this.onSelect,
    super.key,
  });

  final TextEditingController controller;
  final List<MapLocation> results;
  final MapLocation? selectedLocation;
  final bool isSearching;
  final String? searchError;
  final bool hasSearched;
  final VoidCallback onSearch;
  final ValueChanged<MapLocation> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MapSearchBar(
          controller: controller,
          isSearching: isSearching,
          onSearch: onSearch,
        ),
        const SizedBox(height: StudyOsSpacing.sm),
        _MapResultStrip(
          results: results,
          selectedLocation: selectedLocation,
          isSearching: isSearching,
          searchError: searchError,
          hasSearched: hasSearched,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

class _MapResultStrip extends StatelessWidget {
  const _MapResultStrip({
    required this.results,
    required this.selectedLocation,
    required this.isSearching,
    required this.searchError,
    required this.hasSearched,
    required this.onSelect,
  });

  final List<MapLocation> results;
  final MapLocation? selectedLocation;
  final bool isSearching;
  final String? searchError;
  final bool hasSearched;
  final ValueChanged<MapLocation> onSelect;

  @override
  Widget build(BuildContext context) {
    if (!isSearching &&
        searchError == null &&
        !(results.isEmpty && hasSearched) &&
        results.isEmpty) {
      return const SizedBox.shrink();
    }

    final message =
        searchError ??
        (results.isEmpty && hasSearched ? 'No destination found.' : null);

    if (isSearching || message != null) {
      return _FloatingMapPanel(
        child: isSearching
            ? const LinearProgressIndicator()
            : Text(message!, style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    final visibleResults = results.take(4).toList(growable: false);
    return _FloatingMapPanel(
      child: Row(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final result in visibleResults)
                    Padding(
                      padding: const EdgeInsets.only(right: StudyOsSpacing.sm),
                      child: _MapResultButton(
                        result: result,
                        selected: result == selectedLocation,
                        onTap: () => onSelect(result),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapResultButton extends StatelessWidget {
  const _MapResultButton({
    required this.result,
    required this.selected,
    required this.onTap,
  });

  final MapLocation result;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? StudyOsColors.accent : StudyOsColors.background,
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudyOsSpacing.md,
          vertical: StudyOsSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.place_outlined,
              size: 17,
              color: selected ? Colors.white : StudyOsColors.accent,
            ),
            const SizedBox(width: StudyOsSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                result.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : StudyOsColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FloatingMapPanel extends StatelessWidget {
  const _FloatingMapPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudyOsColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
        border: Border.all(color: StudyOsColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.sm),
        child: child,
      ),
    );
  }
}
