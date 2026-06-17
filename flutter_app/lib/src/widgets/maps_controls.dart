import 'package:flutter/material.dart';

import '../map_location_models.dart';
import '../studyos_theme.dart';

class MapSearchBar extends StatelessWidget {
  const MapSearchBar({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.showAssistantAction,
    required this.onSearch,
    required this.onAskAssistant,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final bool showAssistantAction;
  final VoidCallback onSearch;
  final VoidCallback onAskAssistant;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
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
        suffixIconConstraints: const BoxConstraints(minHeight: 48),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: StudyOsSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showAssistantAction) ...<Widget>[
                _RoundSearchIconButton(
                  tooltip: 'Ask AI',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: onAskAssistant,
                ),
                const SizedBox(width: StudyOsSpacing.xs),
              ],
              IconButton(
                tooltip: 'Search destination',
                onPressed: isSearching ? null : onSearch,
                icon: isSearching
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MapOverlay extends StatelessWidget {
  const MapOverlay({
    required this.controller,
    required this.focusNode,
    required this.results,
    required this.selectedLocation,
    required this.isSearching,
    required this.searchError,
    required this.hasSearched,
    required this.showAssistantAction,
    required this.onSearch,
    required this.onSelect,
    required this.onAskAssistant,
    required this.onOpenExternalMaps,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<MapLocation> results;
  final MapLocation? selectedLocation;
  final bool isSearching;
  final String? searchError;
  final bool hasSearched;
  final bool showAssistantAction;
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
          onOpenExternalMaps: onOpenExternalMaps,
        ),
        const SizedBox(height: StudyOsSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: MapSearchBar(
                controller: controller,
                focusNode: focusNode,
                isSearching: isSearching,
                showAssistantAction: showAssistantAction,
                onSearch: onSearch,
                onAskAssistant: onAskAssistant,
              ),
            ),
          ],
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
    required this.onOpenExternalMaps,
  });

  final List<MapLocation> results;
  final MapLocation? selectedLocation;
  final bool isSearching;
  final String? searchError;
  final bool hasSearched;
  final ValueChanged<MapLocation> onSelect;
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

class _RoundSearchIconButton extends StatelessWidget {
  const _RoundSearchIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(40),
        fixedSize: const Size.square(40),
        shape: const CircleBorder(),
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
