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
    required this.onAskAssistant,
    required this.onOpenExternalMaps,
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
  final VoidCallback onAskAssistant;
  final VoidCallback onOpenExternalMaps;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _MapResultStrip(
          results: results,
          selectedLocation: selectedLocation,
          isSearching: isSearching,
          searchError: searchError,
          hasSearched: hasSearched,
          onSelect: onSelect,
          onAskAssistant: onAskAssistant,
          onOpenExternalMaps: onOpenExternalMaps,
        ),
        const SizedBox(height: StudyOsSpacing.sm),
        MapSearchBar(
          controller: controller,
          isSearching: isSearching,
          onSearch: onSearch,
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
    required this.onAskAssistant,
    required this.onOpenExternalMaps,
  });

  final List<MapLocation> results;
  final MapLocation? selectedLocation;
  final bool isSearching;
  final String? searchError;
  final bool hasSearched;
  final ValueChanged<MapLocation> onSelect;
  final VoidCallback onAskAssistant;
  final VoidCallback onOpenExternalMaps;

  @override
  Widget build(BuildContext context) {
    if (!isSearching &&
        searchError == null &&
        !(results.isEmpty && hasSearched) &&
        results.isEmpty) {
      return const SizedBox.shrink();
    }

    final selected = selectedLocation;
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
                      child: ChoiceChip(
                        selected: result == selected,
                        label: Text(
                          result.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        avatar: const Icon(Icons.place_outlined, size: 18),
                        onSelected: (_) => onSelect(result),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (selected != null) ...<Widget>[
            const SizedBox(width: StudyOsSpacing.xs),
            _AskAssistantButton(onPressed: onAskAssistant),
            const SizedBox(width: StudyOsSpacing.xs),
            IconButton.filledTonal(
              tooltip: 'Open in maps',
              onPressed: onOpenExternalMaps,
              icon: const Icon(Icons.near_me_outlined),
            ),
          ],
        ],
      ),
    );
  }
}

class _AskAssistantButton extends StatelessWidget {
  const _AskAssistantButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
      label: const Text('Ask AI'),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: StudyOsSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    );
  }
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
