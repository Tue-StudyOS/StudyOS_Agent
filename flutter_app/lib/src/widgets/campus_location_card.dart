import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

/// Renders a `campus_locations` generative-UI component: geocoded places with
/// address and category. "Open in Maps" launches the device maps app for the
/// coordinates; "Ask" sends a follow-up prompt about the place. Both flow
/// through the single [GeneratedComponentAction] callback.
class CampusLocationCard extends StatelessWidget {
  const CampusLocationCard({
    required this.component,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final GeneratedUiComponent component;
  final ValueChanged<GeneratedComponentAction>? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final locations = _locations(component.arguments['locations']);
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: EdgeInsets.symmetric(vertical: compact ? 5 : 8),
        child: Material(
          color: StudyOsColors.surface,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: StudyOsColors.border),
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(StudyOsSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: StudyOsColors.accent,
                    ),
                    const SizedBox(width: StudyOsSpacing.sm),
                    Expanded(
                      child: Text(
                        component.title,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: StudyOsSpacing.sm),
                for (var i = 0; i < locations.length; i++) ...<Widget>[
                  if (i > 0)
                    const Divider(height: 1, color: StudyOsColors.border),
                  _LocationRow(location: locations[i], onAction: onAction),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<Map<String, Object?>> _locations(Object? raw) {
    if (raw is! List) return const <Map<String, Object?>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.location, required this.onAction});

  final Map<String, Object?> location;
  final ValueChanged<GeneratedComponentAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = location['name']?.toString() ?? 'Location';
    final address = location['address']?.toString().trim() ?? '';
    final category = location['category']?.toString().trim() ?? '';
    final latitude = _double(location['latitude']);
    final longitude = _double(location['longitude']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: StudyOsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: StudyOsColors.text,
                  ),
                ),
              ),
              if (category.isNotEmpty) ...<Widget>[
                const SizedBox(width: StudyOsSpacing.sm),
                _CategoryChip(label: category),
              ],
            ],
          ),
          if (address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: StudyOsColors.textMuted,
                ),
              ),
            ),
          if (onAction != null && latitude != null && longitude != null)
            Padding(
              padding: const EdgeInsets.only(top: StudyOsSpacing.xs),
              child: Wrap(
                spacing: StudyOsSpacing.sm,
                children: <Widget>[
                  _LocationAction(
                    icon: Icons.near_me_outlined,
                    label: 'Open in Maps',
                    onPressed: () => onAction!(
                      MapComponentAction(
                        name: name,
                        latitude: latitude,
                        longitude: longitude,
                      ),
                    ),
                  ),
                  _LocationAction(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Ask',
                    onPressed: () =>
                        onAction!(PromptComponentAction(_askPrompt(name, address))),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _askPrompt(String name, String address) {
    final where = address.isEmpty ? '' : ' ($address)';
    return 'Tell me about $name$where — what it is and how to get there from '
        'campus.';
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: StudyOsColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(StudyOsRadii.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: StudyOsColors.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LocationAction extends StatelessWidget {
  const _LocationAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: StudyOsColors.accent,
        padding: const EdgeInsets.symmetric(
          horizontal: StudyOsSpacing.sm,
          vertical: 2,
        ),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
