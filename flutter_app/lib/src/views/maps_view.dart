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
            options: const MapOptions(
              initialCenter: _tuebingen,
              initialZoom: 13.5,
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
            top: StudyOsSpacing.sm,
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
            bottom: StudyOsSpacing.md,
            child: MapOverlay(
              controller: _searchController,
              results: _results,
              selectedLocation: _selectedLocation,
              isSearching: _isSearching,
              searchError: _searchError,
              hasSearched: _hasSearched,
              onSearch: _search,
              onSelect: _selectLocation,
              onAskAssistant: _askAssistant,
              onOpenExternalMaps: _openExternalMaps,
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
        width: 44,
        height: 44,
        child: const Icon(
          Icons.location_on_rounded,
          color: StudyOsColors.accent,
          size: 42,
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
