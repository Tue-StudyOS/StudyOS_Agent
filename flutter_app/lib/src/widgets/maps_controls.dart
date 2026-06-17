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
        labelText: 'Destination',
        hintText: 'Library, lecture hall, mensa...',
        prefixIcon: const Icon(Icons.search_rounded),
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
    required this.results,
    required this.selectedLocation,
    required this.isSearching,
    required this.searchError,
    required this.hasSearched,
    required this.onSelect,
    required this.onAskAssistant,
    required this.onOpenExternalMaps,
    super.key,
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
    final selected = selectedLocation;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudyOsColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
        border: Border.all(color: StudyOsColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (searchError != null)
                  Text(
                    searchError!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else if (isSearching)
                  const LinearProgressIndicator()
                else if (results.isEmpty && hasSearched)
                  Text(
                    'No destination found.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else if (results.isNotEmpty)
                  _ResultList(
                    results: results,
                    selectedLocation: selected,
                    onSelect: onSelect,
                  ),
                if (selected != null) ...<Widget>[
                  const Divider(height: StudyOsSpacing.lg),
                  Text(
                    selected.name,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: StudyOsSpacing.xs),
                  Text(
                    selected.address ?? selected.coordinateText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: StudyOsSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onAskAssistant,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Ask StudyOS'),
                        ),
                      ),
                      const SizedBox(width: StudyOsSpacing.sm),
                      IconButton.filledTonal(
                        tooltip: 'Open in maps',
                        onPressed: onOpenExternalMaps,
                        icon: const Icon(Icons.near_me_outlined),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.results,
    required this.selectedLocation,
    required this.onSelect,
  });

  final List<MapLocation> results;
  final MapLocation? selectedLocation;
  final ValueChanged<MapLocation> onSelect;

  @override
  Widget build(BuildContext context) {
    final visibleResults = results.take(4).toList(growable: false);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final result in visibleResults)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            selected: result == selectedLocation,
            leading: const Icon(Icons.place_outlined),
            title: Text(
              result.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              result.address ?? result.coordinateText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelect(result),
          ),
      ],
    );
  }
}
