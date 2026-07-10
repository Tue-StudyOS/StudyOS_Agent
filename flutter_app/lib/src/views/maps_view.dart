import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../map_location_models.dart';
import '../map_search_client.dart';
import '../studyos_theme.dart';
import '../widgets/maps_controls.dart';

class MapsView extends StatefulWidget {
  const MapsView({required this.onAskAssistant, this.searchClient, super.key});

  final ValueChanged<String> onAskAssistant;
  final MapSearchClient? searchClient;

  @override
  State<MapsView> createState() => _MapsViewState();
}

class _MapsViewState extends State<MapsView> {
  static const _tuebingen = LatLng(48.5216, 9.0576);

  late final TextEditingController _searchController;
  late final MapController _mapController;
  late final MapSearchClient _searchClient;
  List<MapLocation> _results = const <MapLocation>[];
  MapLocation? _selectedLocation;
  bool _isSearching = false;
  String? _searchError;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _mapController = MapController();
    _searchClient = widget.searchClient ?? MapSearchClient();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(StudyOsRadii.lg),
      child: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _tuebingen,
              initialZoom: 13.5,
              onTap: (_, _) => _clearSelection(),
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.studyos.studyos_agent',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),
          Positioned(
            left: StudyOsSpacing.sm,
            bottom: StudyOsSpacing.sm,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: StudyOsColors.background.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(StudyOsRadii.sm),
                border: Border.all(color: StudyOsColors.border),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: StudyOsSpacing.sm,
                  vertical: StudyOsSpacing.xs,
                ),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(
                    color: StudyOsColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: StudyOsSpacing.md,
            right: StudyOsSpacing.md,
            top: StudyOsSpacing.md,
            child: MapOverlay(
              controller: _searchController,
              results: _results,
              selectedLocation: _selectedLocation,
              isSearching: _isSearching,
              searchError: _searchError,
              hasSearched: _hasSearched,
              onSearch: _search,
              onSelect: _selectLocation,
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> get _markers {
    final selected = _selectedLocation;
    if (selected == null) return const <Marker>[];
    return <Marker>[
      Marker(
        point: LatLng(selected.latitude, selected.longitude),
        width: 236,
        height: 212,
        alignment: Alignment.bottomCenter,
        child: _SelectedLocationMarker(
          location: selected,
          onAskAssistant: _askAssistant,
          onOpenExternalMaps: _openExternalMaps,
          onDismiss: _clearSelection,
        ),
      ),
    ];
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchError = null;
      _hasSearched = true;
    });
    try {
      final results = await _searchClient.search(query);
      if (!mounted) return;
      final selected = results.isEmpty ? null : results.first;
      setState(() {
        _results = results;
        _selectedLocation = selected;
      });
      if (selected != null) _moveTo(selected);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _results = const <MapLocation>[];
        _selectedLocation = null;
        _searchError = error.toString();
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectLocation(MapLocation location) {
    setState(() => _selectedLocation = location);
    _moveTo(location);
  }

  void _clearSelection() {
    if (_selectedLocation == null) return;
    setState(() => _selectedLocation = null);
  }

  void _moveTo(MapLocation location) {
    _mapController.move(LatLng(location.latitude, location.longitude), 16);
  }

  void _askAssistant() {
    final location = _selectedLocation;
    if (location == null) return;
    widget.onAskAssistant(location.assistantPrompt());
  }

  Future<void> _openExternalMaps() async {
    final location = _selectedLocation;
    if (location == null) return;
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${location.latitude},${location.longitude}',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open maps.');
    }
  }
}

class _SelectedLocationMarker extends StatelessWidget {
  const _SelectedLocationMarker({
    required this.location,
    required this.onAskAssistant,
    required this.onOpenExternalMaps,
    required this.onDismiss,
  });

  final MapLocation location;
  final VoidCallback onAskAssistant;
  final VoidCallback onOpenExternalMaps;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Material(
          color: StudyOsColors.surface.withValues(alpha: 0.96),
          elevation: 5,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
            side: const BorderSide(color: StudyOsColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(StudyOsSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        location.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: StudyOsSpacing.xs),
                    IconButton(
                      tooltip: 'Dismiss location',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: StudyOsSpacing.xs),
                Column(
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onAskAssistant,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                        label: const Text('Ask StudyOS'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: StudyOsSpacing.sm,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: StudyOsSpacing.xs),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onOpenExternalMaps,
                        icon: const Icon(Icons.near_me_outlined, size: 17),
                        label: const Text('Open in maps'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: StudyOsSpacing.sm,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Icon(
          Icons.location_on_rounded,
          color: StudyOsColors.accent,
          size: 42,
        ),
      ],
    );
  }
}
